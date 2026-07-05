<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

A feature smoke test: an ACR created and attached, Container Insights and Defender, Azure Policy and deployment safeguards, the Key Vault CSI driver, workload identity, the image cleaner, an API-server IP allow-list, an auto-upgrade window, the Flux extension, and a critical-addons system pool alongside an autoscaling, labelled user pool (untainted so the Flux controllers can schedule).

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# A feature smoke test: a cluster wired to the things a real AKS actually uses. An Azure
# Container Registry is created and ATTACHED (the kubelet identity gets AcrPull, so nodes pull
# without a secret); Container Insights and Defender for Containers ship to a Log Analytics
# workspace; Azure Policy (Gatekeeper) and deployment safeguards enforce best practice; the Key
# Vault CSI driver is on with rotation; workload identity and the OIDC issuer are enabled; the
# image cleaner prunes stale images; the API server is locked to an IP allow-list; a scheduled
# auto-upgrade window is set; the autoscaler is tuned; the Flux extension is installed; and a
# critical-addons system pool sits alongside an autoscaling, labelled user pool (left untainted
# so the Flux controllers have a schedulable home). Applied then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  acr_name = "acr${var.short}${var.loc}${terraform.workspace}002"
  aks_name = "aks-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-aks" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "container_registry" {
  source  = "libre-devops/azure-container-registry/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  container_registries = { (local.acr_name) = {} }
}

module "aks" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  name = local.aks_name

  sku_tier                        = "Standard"
  oidc_issuer_enabled             = true
  workload_identity_enabled       = true
  azure_policy_enabled            = true
  image_cleaner_enabled           = true
  api_server_authorized_ip_ranges = ["203.0.113.0/24"]

  # Attach the registry: the kubelet identity gets AcrPull on it.
  attached_acr_ids = [module.container_registry.container_registry_ids[local.acr_name]]

  default_node_pool = {
    vm_size                      = "Standard_D2s_v6"
    node_count                   = 1
    only_critical_addons_enabled = true
  }

  # No node_taints here (the input is supported, the mocked tests cover it): with the default pool
  # reserved for critical addons, this pool is the only schedulable home for the microsoft.flux
  # controllers below, and extension pods carry no custom tolerations. Tainting every pool leaves
  # them Pending until the extension create times out.
  node_pools = {
    "workloads" = {
      vm_size              = "Standard_D2s_v6"
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
      node_labels          = { "workload" = "general" }
    }
  }

  key_vault_secrets_provider = {
    enabled                 = true
    secret_rotation_enabled = true
  }

  oms_agent = {
    log_analytics_workspace_id      = module.log_analytics.workspace_ids[local.law_name]
    msi_auth_for_monitoring_enabled = true
  }

  microsoft_defender_log_analytics_workspace_id = module.log_analytics.workspace_ids[local.law_name]

  auto_scaler_profile = {
    expander            = "least-waste"
    scale_down_unneeded = "10m"
  }

  maintenance_window_auto_upgrade = {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  # The Flux (GitOps) controllers. microsoft.flux needs an untainted node to schedule its nine
  # controllers on (see the workloads pool note above) plus the Microsoft.KubernetesConfiguration
  # provider registered in the subscription; without a schedulable node the create polls until
  # "context deadline exceeded". create_timeout gives a fresh cluster headroom over the provider's
  # 30 minute default. A flux_configuration pointing at a real repo is also exposed by the module.
  cluster_extensions = {
    "flux" = {
      extension_type = "microsoft.flux"
      create_timeout = "60m"
    }
  }

  deployment_safeguard = {
    level = "Warn"
  }
}

output "cluster_id" {
  value = module.aks.cluster_id
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "kubelet_identity" {
  value = module.aks.identity_principal_ids.kubelet
}

output "attached_acr_login_server" {
  value = module.container_registry.login_servers[local.acr_name]
}

output "resource_group_name" {
  value = local.rg_name
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aks"></a> [aks](#module\_aks) | ../../ | n/a |
| <a name="module_container_registry"></a> [container\_registry](#module\_container\_registry) | libre-devops/azure-container-registry/azurerm | ~> 4.0 |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_attached_acr_login_server"></a> [attached\_acr\_login\_server](#output\_attached\_acr\_login\_server) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | n/a |
| <a name="output_kubelet_identity"></a> [kubelet\_identity](#output\_kubelet\_identity) | n/a |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
<!-- END_TF_DOCS -->

# A feature smoke test: a cluster wired to the things a real AKS actually uses. An Azure
# Container Registry is created and ATTACHED (the kubelet identity gets AcrPull, so nodes pull
# without a secret); Container Insights and Defender for Containers ship to a Log Analytics
# workspace; Azure Policy (Gatekeeper) and deployment safeguards enforce best practice; the Key
# Vault CSI driver is on with rotation; workload identity and the OIDC issuer are enabled; the
# image cleaner prunes stale images; the API server is locked to an IP allow-list; a scheduled
# auto-upgrade window is set; the autoscaler is tuned; the Flux extension is installed; and a
# tainted system pool sits alongside an autoscaling, labelled, tainted user pool. Applied then
# destroyed in one CI run.
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

  node_pools = {
    "workloads" = {
      vm_size              = "Standard_D2s_v6"
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
      node_labels          = { "workload" = "general" }
      node_taints          = ["workload=general:NoSchedule"]
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

  # The Flux (GitOps) controllers. A flux_configuration pointing at your repo is exposed by the
  # module but needs a real repo, so it is left out of this smoke test.
  cluster_extensions = {
    "flux" = { extension_type = "microsoft.flux" }
  }

  deployment_safeguard = {
    level = "Warning"
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

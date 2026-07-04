<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Kubernetes Service

Terraform module for Azure Kubernetes Service (AKS), in the Libre DevOps style: fast to get
going, secure by default, flexible when it matters. Deliberately NOT an AVM-style
everything-wrapper: a clean core cluster with secure defaults, additional node pools, and a
handful of high-value add-ons that are trivial to switch on.

[![CI](https://github.com/libre-devops/terraform-azurerm-aks/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-aks/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-aks?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-aks/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-aks)](./LICENSE)

---

## Overview

```hcl
module "aks" {
  source  = "libre-devops/aks/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-dev-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  name = "aks-ldo-uks-dev-001"

  default_node_pool = { vm_size = "Standard_D2s_v6", node_count = 1 }
}
```

That call stands up a Standard-tier cluster with a system-assigned identity, Azure CNI, and a
secure posture the provider does not give you by default: the **local admin account is disabled**,
**Azure AD RBAC** is on (with the tenant defaulted for you), and **Kubernetes RBAC** is on. Every
default has an explicit override, and preconditions stop you shipping an unreachable cluster (for
example the local account off with no Azure AD).

- **One cluster per call, node pools as a map.** AKS is a heavyweight singleton, so the cluster
  is top-level (no tangled map-of-clusters); additional user node pools are a `node_pools` map.
  Keep the system pool for system pods with `only_critical_addons_enabled` and put workloads on a
  user pool.
- **Attach your registries.** Pass `attached_acr_ids` and the module grants the kubelet identity
  `AcrPull` on each, so nodes pull images without a pull secret (the Terraform equivalent of
  `az aks update --attach-acr`). It composes directly with `libre-devops/azure-container-registry`.
- **Secure defaults, security add-ons one line away.** `api_server_authorized_ip_ranges` locks
  the API server, `private_cluster_enabled` removes the public endpoint, and
  `microsoft_defender_log_analytics_workspace_id` turns on Defender for Containers. Workload
  identity is a flag pair (`oidc_issuer_enabled` + `workload_identity_enabled`).
- **The add-ons that earn their place, trivial to enable.** `key_vault_secrets_provider` (the
  CSI driver), `oms_agent` (Container Insights), `azure_policy_enabled` (Gatekeeper),
  `cluster_extensions` (a map, e.g. Flux or Dapr), `flux_configurations` (GitOps, pairs with the
  flux extension), `trusted_access_role_bindings` (grant Backup or ML access), and
  `deployment_safeguard` (best-practice enforcement).
- **Deliberately out of scope.** Fleet management (multi-cluster orchestration) belongs in its
  own module, not here.

## Examples

- [`examples/minimal`](./examples/minimal) - a single-node secure-default cluster, applied and
  destroyed in CI.
- [`examples/complete`](./examples/complete) - a tainted system pool plus an autoscaling user
  pool, Container Insights, the Key Vault CSI driver, workload identity, the image cleaner, and a
  scheduled auto-upgrade window.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.80.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_kubernetes_cluster_deployment_safeguard.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_deployment_safeguard) | resource |
| [azurerm_kubernetes_cluster_extension.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_extension) | resource |
| [azurerm_kubernetes_cluster_node_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool) | resource |
| [azurerm_kubernetes_cluster_trusted_access_role_binding.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_trusted_access_role_binding) | resource |
| [azurerm_kubernetes_flux_configuration.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_flux_configuration) | resource |
| [azurerm_role_assignment.acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_server_authorized_ip_ranges"></a> [api\_server\_authorized\_ip\_ranges](#input\_api\_server\_authorized\_ip\_ranges) | CIDRs allowed to reach the public API server (ignored for private clusters). Restricting this is a strong security control. | `list(string)` | `null` | no |
| <a name="input_attached_acr_ids"></a> [attached\_acr\_ids](#input\_attached\_acr\_ids) | Azure Container Registry ids to attach to the cluster. For each, the module grants the<br/>cluster's kubelet identity the AcrPull role on the registry, so nodes can pull images without<br/>a pull secret. This is the Terraform equivalent of `az aks update --attach-acr`. A list (not a<br/>set) so a registry id that is only known after apply, such as one created in the same<br/>configuration, is still valid: the grants are keyed by list position, which is known at plan. | `list(string)` | `[]` | no |
| <a name="input_auto_scaler_profile"></a> [auto\_scaler\_profile](#input\_auto\_scaler\_profile) | Cluster autoscaler tuning (only meaningful when a node pool has auto\_scaling\_enabled). Null uses AKS defaults. | <pre>object({<br/>    balance_similar_node_groups      = optional(bool)<br/>    expander                         = optional(string)<br/>    max_graceful_termination_sec     = optional(string)<br/>    scale_down_delay_after_add       = optional(string)<br/>    scale_down_unneeded              = optional(string)<br/>    scale_down_utilization_threshold = optional(string)<br/>    scan_interval                    = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_automatic_upgrade_channel"></a> [automatic\_upgrade\_channel](#input\_automatic\_upgrade\_channel) | Automatic Kubernetes upgrade channel: patch, rapid, stable, or node-image. | `string` | `null` | no |
| <a name="input_azure_active_directory_rbac"></a> [azure\_active\_directory\_rbac](#input\_azure\_active\_directory\_rbac) | Azure AD integration for Kubernetes RBAC. azure\_rbac\_enabled uses Azure RBAC for cluster authorization; admin\_group\_object\_ids grant cluster-admin to AAD groups. Enabled by default for a secure posture. | <pre>object({<br/>    enabled                = optional(bool, true)<br/>    azure_rbac_enabled     = optional(bool, true)<br/>    admin_group_object_ids = optional(list(string))<br/>    tenant_id              = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_azure_policy_enabled"></a> [azure\_policy\_enabled](#input\_azure\_policy\_enabled) | Enable the Azure Policy add-on (Gatekeeper). | `bool` | `false` | no |
| <a name="input_cluster_extensions"></a> [cluster\_extensions](#input\_cluster\_extensions) | Cluster extensions (e.g. Flux, Dapr) keyed by name. extension\_type is the platform type; configuration\_settings/version are optional. Requires the Microsoft.KubernetesConfiguration resource provider registered on the subscription. create\_timeout overrides the provider's 30 minute default (microsoft.flux installs several controllers and can exceed 30 minutes on a fresh cluster, surfacing as 'context deadline exceeded'). | <pre>map(object({<br/>    extension_type                   = string<br/>    version                          = optional(string)<br/>    release_train                    = optional(string)<br/>    release_namespace                = optional(string)<br/>    target_namespace                 = optional(string)<br/>    configuration_settings           = optional(map(string))<br/>    configuration_protected_settings = optional(map(string))<br/>    create_timeout                   = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_cost_analysis_enabled"></a> [cost\_analysis\_enabled](#input\_cost\_analysis\_enabled) | Enable cost analysis (requires Standard or Premium sku\_tier). | `bool` | `false` | no |
| <a name="input_default_node_pool"></a> [default\_node\_pool](#input\_default\_node\_pool) | The system node pool. vm\_size and either a fixed node\_count or auto\_scaling with min/max are<br/>the usual knobs; only\_critical\_addons\_enabled taints the pool so only system pods land on it<br/>(put your workloads on additional node\_pools). vnet\_subnet\_id places nodes in your VNet. | <pre>object({<br/>    name                         = optional(string, "system")<br/>    vm_size                      = optional(string, "Standard_D2s_v5")<br/>    node_count                   = optional(number, 1)<br/>    auto_scaling_enabled         = optional(bool, false)<br/>    min_count                    = optional(number)<br/>    max_count                    = optional(number)<br/>    max_pods                     = optional(number)<br/>    os_disk_type                 = optional(string)<br/>    os_disk_size_gb              = optional(number)<br/>    type                         = optional(string, "VirtualMachineScaleSets")<br/>    zones                        = optional(list(string))<br/>    vnet_subnet_id               = optional(string)<br/>    pod_subnet_id                = optional(string)<br/>    orchestrator_version         = optional(string)<br/>    only_critical_addons_enabled = optional(bool)<br/>    host_encryption_enabled      = optional(bool)<br/>    fips_enabled                 = optional(bool)<br/>    node_public_ip_enabled       = optional(bool)<br/>    scale_down_mode              = optional(string)<br/>    node_labels                  = optional(map(string))<br/>    temporary_name_for_rotation  = optional(string, "systemtmp")<br/>    upgrade_settings = optional(object({<br/>      max_surge                     = string<br/>      drain_timeout_in_minutes      = optional(number)<br/>      node_soak_duration_in_minutes = optional(number)<br/>    }))<br/>    tags = optional(map(string))<br/>  })</pre> | `{}` | no |
| <a name="input_deployment_safeguard"></a> [deployment\_safeguard](#input\_deployment\_safeguard) | AKS deployment safeguards (best-practice enforcement on workloads). Set level (Warn or Enforce) to enable. | <pre>object({<br/>    level               = string<br/>    excluded_namespaces = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_dns_prefix"></a> [dns\_prefix](#input\_dns\_prefix) | DNS prefix for the cluster's API server. Defaults to the cluster name. Ignored when dns\_prefix\_private\_cluster is set. | `string` | `null` | no |
| <a name="input_dns_prefix_private_cluster"></a> [dns\_prefix\_private\_cluster](#input\_dns\_prefix\_private\_cluster) | DNS prefix for a private cluster (mutually exclusive with dns\_prefix). | `string` | `null` | no |
| <a name="input_flux_configurations"></a> [flux\_configurations](#input\_flux\_configurations) | Flux (GitOps) configurations keyed by name. Requires the microsoft.flux cluster\_extension. Each points a namespace at a git\_repository and kustomizations. | <pre>map(object({<br/>    namespace                         = string<br/>    scope                             = optional(string, "namespace")<br/>    continuous_reconciliation_enabled = optional(bool, true)<br/>    git_repository = object({<br/>      url                      = string<br/>      reference_type           = string<br/>      reference_value          = string<br/>      sync_interval_in_seconds = optional(number)<br/>      timeout_in_seconds       = optional(number)<br/>      https_user               = optional(string)<br/>      https_key_base64         = optional(string)<br/>      ssh_private_key_base64   = optional(string)<br/>    })<br/>    kustomizations = list(object({<br/>      name                       = string<br/>      path                       = optional(string)<br/>      sync_interval_in_seconds   = optional(number)<br/>      timeout_in_seconds         = optional(number)<br/>      retry_interval_in_seconds  = optional(number)<br/>      recreating_enabled         = optional(bool)<br/>      garbage_collection_enabled = optional(bool)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | Cluster control-plane identity. SystemAssigned by default; pass UserAssigned with identity\_ids to bring your own. | <pre>object({<br/>    type         = optional(string, "SystemAssigned")<br/>    identity_ids = optional(list(string))<br/>  })</pre> | `{}` | no |
| <a name="input_image_cleaner_enabled"></a> [image\_cleaner\_enabled](#input\_image\_cleaner\_enabled) | Enable the image cleaner (Eraser) to prune stale images. | `bool` | `false` | no |
| <a name="input_image_cleaner_interval_hours"></a> [image\_cleaner\_interval\_hours](#input\_image\_cleaner\_interval\_hours) | Image cleaner interval in hours (when enabled). | `number` | `null` | no |
| <a name="input_key_vault_secrets_provider"></a> [key\_vault\_secrets\_provider](#input\_key\_vault\_secrets\_provider) | The Key Vault CSI driver add-on for mounting secrets. Pass {} to enable with defaults, or set secret rotation. | <pre>object({<br/>    enabled                  = optional(bool, false)<br/>    secret_rotation_enabled  = optional(bool)<br/>    secret_rotation_interval = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version. Null tracks the AKS default for the region. | `string` | `null` | no |
| <a name="input_local_account_disabled"></a> [local\_account\_disabled](#input\_local\_account\_disabled) | Disable the local admin (cluster-admin) account so all access goes through Azure AD. Secure default TRUE; requires azure\_active\_directory\_rbac enabled. | `bool` | `true` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the cluster. | `string` | n/a | yes |
| <a name="input_maintenance_window_auto_upgrade"></a> [maintenance\_window\_auto\_upgrade](#input\_maintenance\_window\_auto\_upgrade) | Scheduled maintenance window for automatic upgrades. | <pre>object({<br/>    frequency   = string<br/>    interval    = number<br/>    duration    = number<br/>    day_of_week = optional(string)<br/>    week_index  = optional(string)<br/>    start_time  = optional(string)<br/>    utc_offset  = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_microsoft_defender_log_analytics_workspace_id"></a> [microsoft\_defender\_log\_analytics\_workspace\_id](#input\_microsoft\_defender\_log\_analytics\_workspace\_id) | Enable Microsoft Defender for Containers by pointing it at a Log Analytics workspace. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the AKS cluster. | `string` | n/a | yes |
| <a name="input_network_profile"></a> [network\_profile](#input\_network\_profile) | Cluster networking. network\_plugin defaults to azure (Azure CNI); network\_policy adds a<br/>policy engine (azure, calico, or cilium). For overlay networking set network\_plugin\_mode =<br/>overlay. load\_balancer\_sku standard is the default; outbound\_type controls egress. | <pre>object({<br/>    network_plugin      = optional(string, "azure")<br/>    network_policy      = optional(string)<br/>    network_plugin_mode = optional(string)<br/>    network_data_plane  = optional(string)<br/>    load_balancer_sku   = optional(string, "standard")<br/>    outbound_type       = optional(string)<br/>    dns_service_ip      = optional(string)<br/>    service_cidr        = optional(string)<br/>    pod_cidr            = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_node_os_upgrade_channel"></a> [node\_os\_upgrade\_channel](#input\_node\_os\_upgrade\_channel) | Node OS upgrade channel: None, Unmanaged, SecurityPatch, or NodeImage. | `string` | `null` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Additional (user) node pools keyed by name. Put workloads here and keep the system pool for<br/>system pods (only\_critical\_addons\_enabled on the default pool). Each pool has the same shape<br/>as the default pool plus a mode (User by default). | <pre>map(object({<br/>    vm_size                 = optional(string, "Standard_D2s_v5")<br/>    node_count              = optional(number, 1)<br/>    auto_scaling_enabled    = optional(bool, false)<br/>    min_count               = optional(number)<br/>    max_count               = optional(number)<br/>    max_pods                = optional(number)<br/>    mode                    = optional(string, "User")<br/>    os_type                 = optional(string)<br/>    os_sku                  = optional(string)<br/>    os_disk_type            = optional(string)<br/>    os_disk_size_gb         = optional(number)<br/>    priority                = optional(string)<br/>    spot_max_price          = optional(number)<br/>    eviction_policy         = optional(string)<br/>    zones                   = optional(list(string))<br/>    vnet_subnet_id          = optional(string)<br/>    pod_subnet_id           = optional(string)<br/>    orchestrator_version    = optional(string)<br/>    host_encryption_enabled = optional(bool)<br/>    fips_enabled            = optional(bool)<br/>    node_public_ip_enabled  = optional(bool)<br/>    node_labels             = optional(map(string))<br/>    node_taints             = optional(list(string))<br/>    upgrade_settings = optional(object({<br/>      max_surge                     = string<br/>      drain_timeout_in_minutes      = optional(number)<br/>      node_soak_duration_in_minutes = optional(number)<br/>    }))<br/>    tags = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_oidc_issuer_enabled"></a> [oidc\_issuer\_enabled](#input\_oidc\_issuer\_enabled) | Enable the OIDC issuer (required for workload identity). | `bool` | `false` | no |
| <a name="input_oms_agent"></a> [oms\_agent](#input\_oms\_agent) | Azure Monitor (Container Insights) add-on. Set log\_analytics\_workspace\_id to enable. | <pre>object({<br/>    log_analytics_workspace_id      = string<br/>    msi_auth_for_monitoring_enabled = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | Make the API server private (no public endpoint). | `bool` | `false` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Id of the resource group the cluster lives in; the module parses the name from it. | `string` | n/a | yes |
| <a name="input_role_based_access_control_enabled"></a> [role\_based\_access\_control\_enabled](#input\_role\_based\_access\_control\_enabled) | Enable Kubernetes RBAC. Secure default TRUE. | `bool` | `true` | no |
| <a name="input_sku_tier"></a> [sku\_tier](#input\_sku\_tier) | Cluster SKU tier: Free, Standard (default, with the uptime SLA), or Premium. | `string` | `"Standard"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the cluster and, unless overridden, its node pools. | `map(string)` | `{}` | no |
| <a name="input_trusted_access_role_bindings"></a> [trusted\_access\_role\_bindings](#input\_trusted\_access\_role\_bindings) | Trusted access role bindings keyed by name (e.g. granting Azure Backup or Azure ML access to the cluster). Each maps a source\_resource\_id to a set of roles. | <pre>map(object({<br/>    source_resource_id = string<br/>    roles              = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_workload_identity_enabled"></a> [workload\_identity\_enabled](#input\_workload\_identity\_enabled) | Enable Azure AD workload identity (requires oidc\_issuer\_enabled). | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster"></a> [cluster](#output\_cluster) | The full AKS cluster object. Sensitive as a whole because it carries kube\_config credentials; the id, fqdn, and identity outputs alongside stay plain for composition. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The cluster id. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The cluster name. |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | The API server FQDN (public clusters). |
| <a name="output_identity_principal_ids"></a> [identity\_principal\_ids](#output\_identity\_principal\_ids) | The cluster's { control\_plane, kubelet } identity principal ids. |
| <a name="output_key_vault_secrets_provider_identity"></a> [key\_vault\_secrets\_provider\_identity](#output\_key\_vault\_secrets\_provider\_identity) | The Key Vault CSI driver's user-assigned identity (when the add-on is enabled), to grant Key Vault access to. |
| <a name="output_kube_config_raw"></a> [kube\_config\_raw](#output\_kube\_config\_raw) | Raw kubeconfig for the cluster (local-account access; empty when local\_account\_disabled). |
| <a name="output_node_pool_ids"></a> [node\_pool\_ids](#output\_node\_pool\_ids) | Map of additional node pool name to id. |
| <a name="output_node_resource_group"></a> [node\_resource\_group](#output\_node\_resource\_group) | The auto-created resource group holding the cluster's node infrastructure. |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | The OIDC issuer URL (when oidc\_issuer\_enabled), for federating workload identities. |
| <a name="output_private_fqdn"></a> [private\_fqdn](#output\_private\_fqdn) | The API server private FQDN (private clusters). |
<!-- END_TF_DOCS -->

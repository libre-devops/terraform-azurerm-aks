variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public API server (ignored for private clusters). Restricting this is a strong security control."
  type        = list(string)
  default     = null
}

variable "attached_acr_ids" {
  description = <<-DESC
    Azure Container Registry ids to attach to the cluster. For each, the module grants the
    cluster's kubelet identity the AcrPull role on the registry, so nodes can pull images without
    a pull secret. This is the Terraform equivalent of `az aks update --attach-acr`. A list (not a
    set) so a registry id that is only known after apply, such as one created in the same
    configuration, is still valid: the grants are keyed by list position, which is known at plan.
  DESC
  type        = list(string)
  default     = []
}

variable "auto_scaler_profile" {
  description = "Cluster autoscaler tuning (only meaningful when a node pool has auto_scaling_enabled). Null uses AKS defaults."
  type = object({
    balance_similar_node_groups      = optional(bool)
    expander                         = optional(string)
    max_graceful_termination_sec     = optional(string)
    scale_down_delay_after_add       = optional(string)
    scale_down_unneeded              = optional(string)
    scale_down_utilization_threshold = optional(string)
    scan_interval                    = optional(string)
  })
  default = null
}

variable "automatic_upgrade_channel" {
  description = "Automatic Kubernetes upgrade channel: patch, rapid, stable, or node-image."
  type        = string
  default     = null
}

variable "azure_active_directory_rbac" {
  description = "Azure AD integration for Kubernetes RBAC. azure_rbac_enabled uses Azure RBAC for cluster authorization; admin_group_object_ids grant cluster-admin to AAD groups. Enabled by default for a secure posture."
  type = object({
    enabled                = optional(bool, true)
    azure_rbac_enabled     = optional(bool, true)
    admin_group_object_ids = optional(list(string))
    tenant_id              = optional(string)
  })
  default = {}
}

variable "azure_policy_enabled" {
  description = "Enable the Azure Policy add-on (Gatekeeper)."
  type        = bool
  default     = false
}

# Opt-in add-ons: each is a simple map/object, kept trivial to enable per the module's
# quick-start-easy ethos. These are separate provider resources composed onto the cluster.
variable "cluster_extensions" {
  description = "Cluster extensions (e.g. Flux, Dapr) keyed by name. extension_type is the platform type; configuration_settings/version are optional. Requires the Microsoft.KubernetesConfiguration resource provider registered on the subscription, and at least one untainted Linux node pool the extension pods can schedule on (they carry no custom tolerations; a precondition enforces this). The module installs extensions only after all node pools exist, because Azure assigns each extension's managed identity to the VMSSes present at install time and a pool racing the install misses the assignment, leaving the extension agent failing IMDS auth until the create times out. create_timeout overrides the provider's 30 minute default for genuinely slow installs."
  type = map(object({
    extension_type                   = string
    version                          = optional(string)
    release_train                    = optional(string)
    release_namespace                = optional(string)
    target_namespace                 = optional(string)
    configuration_settings           = optional(map(string))
    configuration_protected_settings = optional(map(string))
    create_timeout                   = optional(string)
  }))
  default = {}
}

variable "cost_analysis_enabled" {
  description = "Enable cost analysis (requires Standard or Premium sku_tier)."
  type        = bool
  default     = false
}

variable "default_node_pool" {
  description = <<-DESC
    The system node pool. vm_size and either a fixed node_count or auto_scaling with min/max are
    the usual knobs; only_critical_addons_enabled taints the pool so only system pods land on it
    (put your workloads on additional node_pools). vnet_subnet_id places nodes in your VNet.
  DESC
  type = object({
    name                         = optional(string, "system")
    vm_size                      = optional(string, "Standard_D2s_v5")
    node_count                   = optional(number, 1)
    auto_scaling_enabled         = optional(bool, false)
    min_count                    = optional(number)
    max_count                    = optional(number)
    max_pods                     = optional(number)
    os_disk_type                 = optional(string)
    os_disk_size_gb              = optional(number)
    type                         = optional(string, "VirtualMachineScaleSets")
    zones                        = optional(list(string))
    vnet_subnet_id               = optional(string)
    pod_subnet_id                = optional(string)
    orchestrator_version         = optional(string)
    only_critical_addons_enabled = optional(bool)
    host_encryption_enabled      = optional(bool)
    fips_enabled                 = optional(bool)
    node_public_ip_enabled       = optional(bool)
    scale_down_mode              = optional(string)
    node_labels                  = optional(map(string))
    temporary_name_for_rotation  = optional(string, "systemtmp")
    upgrade_settings = optional(object({
      max_surge                     = string
      drain_timeout_in_minutes      = optional(number)
      node_soak_duration_in_minutes = optional(number)
    }))
    tags = optional(map(string))
  })
  default = {}
}

variable "deployment_safeguard" {
  description = "AKS deployment safeguards (best-practice enforcement on workloads). Set level (Warn or Enforce) to enable."
  type = object({
    level               = string
    excluded_namespaces = optional(list(string))
  })
  default = null
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster's API server. Defaults to the cluster name. Ignored when dns_prefix_private_cluster is set."
  type        = string
  default     = null
}

variable "dns_prefix_private_cluster" {
  description = "DNS prefix for a private cluster (mutually exclusive with dns_prefix)."
  type        = string
  default     = null
}

variable "flux_configurations" {
  description = "Flux (GitOps) configurations keyed by name. Requires the microsoft.flux cluster_extension. Each points a namespace at a git_repository and kustomizations."
  type = map(object({
    namespace                         = string
    scope                             = optional(string, "namespace")
    continuous_reconciliation_enabled = optional(bool, true)
    git_repository = object({
      url                      = string
      reference_type           = string
      reference_value          = string
      sync_interval_in_seconds = optional(number)
      timeout_in_seconds       = optional(number)
      https_user               = optional(string)
      https_key_base64         = optional(string)
      ssh_private_key_base64   = optional(string)
    })
    kustomizations = list(object({
      name                       = string
      path                       = optional(string)
      sync_interval_in_seconds   = optional(number)
      timeout_in_seconds         = optional(number)
      retry_interval_in_seconds  = optional(number)
      recreating_enabled         = optional(bool)
      garbage_collection_enabled = optional(bool)
    }))
  }))
  default = {}
}

variable "identity" {
  description = "Cluster control-plane identity. SystemAssigned by default; pass UserAssigned with identity_ids to bring your own."
  type = object({
    type         = optional(string, "SystemAssigned")
    identity_ids = optional(list(string))
  })
  default = {}
}

variable "image_cleaner_enabled" {
  description = "Enable the image cleaner (Eraser) to prune stale images."
  type        = bool
  default     = false
}

variable "image_cleaner_interval_hours" {
  description = "Image cleaner interval in hours (when enabled)."
  type        = number
  default     = null
}

variable "key_vault_secrets_provider" {
  description = "The Key Vault CSI driver add-on for mounting secrets. Pass {} to enable with defaults, or set secret rotation."
  type = object({
    enabled                  = optional(bool, false)
    secret_rotation_enabled  = optional(bool)
    secret_rotation_interval = optional(string)
  })
  default = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version. Null tracks the AKS default for the region."
  type        = string
  default     = null
}

# Secure defaults overriding the provider's looser ones.
variable "local_account_disabled" {
  description = "Disable the local admin (cluster-admin) account so all access goes through Azure AD. Secure default TRUE; requires azure_active_directory_rbac enabled."
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region for the cluster."
  type        = string
}

variable "maintenance_window_auto_upgrade" {
  description = "Scheduled maintenance window for automatic upgrades."
  type = object({
    frequency   = string
    interval    = number
    duration    = number
    day_of_week = optional(string)
    week_index  = optional(string)
    start_time  = optional(string)
    utc_offset  = optional(string)
  })
  default = null
}

variable "microsoft_defender_log_analytics_workspace_id" {
  description = "Enable Microsoft Defender for Containers by pointing it at a Log Analytics workspace."
  type        = string
  default     = null
}

variable "name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "network_profile" {
  description = <<-DESC
    Cluster networking. network_plugin defaults to azure (Azure CNI); network_policy adds a
    policy engine (azure, calico, or cilium). For overlay networking set network_plugin_mode =
    overlay. load_balancer_sku standard is the default; outbound_type controls egress.
  DESC
  type = object({
    network_plugin      = optional(string, "azure")
    network_policy      = optional(string)
    network_plugin_mode = optional(string)
    network_data_plane  = optional(string)
    load_balancer_sku   = optional(string, "standard")
    outbound_type       = optional(string)
    dns_service_ip      = optional(string)
    service_cidr        = optional(string)
    pod_cidr            = optional(string)
  })
  default = {}
}

variable "node_os_upgrade_channel" {
  description = "Node OS upgrade channel: None, Unmanaged, SecurityPatch, or NodeImage."
  type        = string
  default     = null
}

variable "node_pools" {
  description = <<-DESC
    Additional (user) node pools keyed by name. Put workloads here and keep the system pool for
    system pods (only_critical_addons_enabled on the default pool). Each pool has the same shape
    as the default pool plus a mode (User by default).
  DESC
  type = map(object({
    vm_size                 = optional(string, "Standard_D2s_v5")
    node_count              = optional(number, 1)
    auto_scaling_enabled    = optional(bool, false)
    min_count               = optional(number)
    max_count               = optional(number)
    max_pods                = optional(number)
    mode                    = optional(string, "User")
    os_type                 = optional(string)
    os_sku                  = optional(string)
    os_disk_type            = optional(string)
    os_disk_size_gb         = optional(number)
    priority                = optional(string)
    spot_max_price          = optional(number)
    eviction_policy         = optional(string)
    zones                   = optional(list(string))
    vnet_subnet_id          = optional(string)
    pod_subnet_id           = optional(string)
    orchestrator_version    = optional(string)
    host_encryption_enabled = optional(bool)
    fips_enabled            = optional(bool)
    node_public_ip_enabled  = optional(bool)
    node_labels             = optional(map(string))
    node_taints             = optional(list(string))
    upgrade_settings = optional(object({
      max_surge                     = string
      drain_timeout_in_minutes      = optional(number)
      node_soak_duration_in_minutes = optional(number)
    }))
    tags = optional(map(string))
  }))
  default = {}
}

variable "oidc_issuer_enabled" {
  description = "Enable the OIDC issuer (required for workload identity)."
  type        = bool
  default     = false
}

variable "oms_agent" {
  description = "Azure Monitor (Container Insights) add-on. Set log_analytics_workspace_id to enable."
  type = object({
    log_analytics_workspace_id      = string
    msi_auth_for_monitoring_enabled = optional(bool)
  })
  default = null
}

variable "private_cluster_enabled" {
  description = "Make the API server private (no public endpoint)."
  type        = bool
  default     = false
}

variable "resource_group_id" {
  description = "Id of the resource group the cluster lives in; the module parses the name from it."
  type        = string
}

variable "role_based_access_control_enabled" {
  description = "Enable Kubernetes RBAC. Secure default TRUE."
  type        = bool
  default     = true
}

variable "sku_tier" {
  description = "Cluster SKU tier: Free, Standard (default, with the uptime SLA), or Premium."
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Tags applied to the cluster and, unless overridden, its node pools."
  type        = map(string)
  default     = {}

}

variable "trusted_access_role_bindings" {
  description = "Trusted access role bindings keyed by name (e.g. granting Azure Backup or Azure ML access to the cluster). Each maps a source_resource_id to a set of roles."
  type = map(object({
    source_resource_id = string
    roles              = list(string)
  }))
  default = {}
}

variable "workload_identity_enabled" {
  description = "Enable Azure AD workload identity (requires oidc_issuer_enabled)."
  type        = bool
  default     = false
}

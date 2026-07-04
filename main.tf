locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)
}

data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = var.tags

  name                              = var.name
  dns_prefix                        = var.dns_prefix_private_cluster == null ? coalesce(var.dns_prefix, var.name) : null
  dns_prefix_private_cluster        = var.dns_prefix_private_cluster
  kubernetes_version                = var.kubernetes_version
  sku_tier                          = var.sku_tier
  local_account_disabled            = var.local_account_disabled
  role_based_access_control_enabled = var.role_based_access_control_enabled
  private_cluster_enabled           = var.private_cluster_enabled
  oidc_issuer_enabled               = var.oidc_issuer_enabled
  workload_identity_enabled         = var.workload_identity_enabled
  azure_policy_enabled              = var.azure_policy_enabled
  image_cleaner_enabled             = var.image_cleaner_enabled
  image_cleaner_interval_hours      = var.image_cleaner_enabled ? coalesce(var.image_cleaner_interval_hours, 168) : null
  cost_analysis_enabled             = var.cost_analysis_enabled
  automatic_upgrade_channel         = var.automatic_upgrade_channel
  node_os_upgrade_channel           = var.node_os_upgrade_channel

  default_node_pool {
    name                         = var.default_node_pool.name
    vm_size                      = var.default_node_pool.vm_size
    node_count                   = var.default_node_pool.auto_scaling_enabled ? null : var.default_node_pool.node_count
    auto_scaling_enabled         = var.default_node_pool.auto_scaling_enabled
    min_count                    = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.min_count : null
    max_count                    = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.max_count : null
    max_pods                     = var.default_node_pool.max_pods
    os_disk_type                 = var.default_node_pool.os_disk_type
    os_disk_size_gb              = var.default_node_pool.os_disk_size_gb
    type                         = var.default_node_pool.type
    zones                        = var.default_node_pool.zones
    vnet_subnet_id               = var.default_node_pool.vnet_subnet_id
    pod_subnet_id                = var.default_node_pool.pod_subnet_id
    orchestrator_version         = var.default_node_pool.orchestrator_version
    only_critical_addons_enabled = var.default_node_pool.only_critical_addons_enabled
    host_encryption_enabled      = var.default_node_pool.host_encryption_enabled
    fips_enabled                 = var.default_node_pool.fips_enabled
    node_public_ip_enabled       = var.default_node_pool.node_public_ip_enabled
    scale_down_mode              = var.default_node_pool.scale_down_mode
    node_labels                  = var.default_node_pool.node_labels
    temporary_name_for_rotation  = var.default_node_pool.temporary_name_for_rotation
    tags                         = merge(var.tags, coalesce(var.default_node_pool.tags, {}))

    dynamic "upgrade_settings" {
      for_each = var.default_node_pool.upgrade_settings != null ? [var.default_node_pool.upgrade_settings] : []

      content {
        max_surge                     = upgrade_settings.value.max_surge
        drain_timeout_in_minutes      = upgrade_settings.value.drain_timeout_in_minutes
        node_soak_duration_in_minutes = upgrade_settings.value.node_soak_duration_in_minutes
      }
    }
  }

  identity {
    type         = var.identity.type
    identity_ids = var.identity.identity_ids
  }

  network_profile {
    network_plugin      = var.network_profile.network_plugin
    network_policy      = var.network_profile.network_policy
    network_plugin_mode = var.network_profile.network_plugin_mode
    network_data_plane  = var.network_profile.network_data_plane
    load_balancer_sku   = var.network_profile.load_balancer_sku
    outbound_type       = var.network_profile.outbound_type
    dns_service_ip      = var.network_profile.dns_service_ip
    service_cidr        = var.network_profile.service_cidr
    pod_cidr            = var.network_profile.pod_cidr
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.azure_active_directory_rbac.enabled ? [var.azure_active_directory_rbac] : []

    content {
      azure_rbac_enabled     = azure_active_directory_role_based_access_control.value.azure_rbac_enabled
      admin_group_object_ids = azure_active_directory_role_based_access_control.value.admin_group_object_ids
      tenant_id              = coalesce(azure_active_directory_role_based_access_control.value.tenant_id, data.azurerm_client_config.current.tenant_id)
    }
  }

  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider.enabled ? [var.key_vault_secrets_provider] : []

    content {
      secret_rotation_enabled  = key_vault_secrets_provider.value.secret_rotation_enabled
      secret_rotation_interval = key_vault_secrets_provider.value.secret_rotation_interval
    }
  }

  dynamic "oms_agent" {
    for_each = var.oms_agent != null ? [var.oms_agent] : []

    content {
      log_analytics_workspace_id      = oms_agent.value.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = oms_agent.value.msi_auth_for_monitoring_enabled
    }
  }

  dynamic "microsoft_defender" {
    for_each = var.microsoft_defender_log_analytics_workspace_id != null ? [1] : []

    content {
      log_analytics_workspace_id = var.microsoft_defender_log_analytics_workspace_id
    }
  }

  dynamic "api_server_access_profile" {
    for_each = var.api_server_authorized_ip_ranges != null ? [1] : []

    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  dynamic "auto_scaler_profile" {
    for_each = var.auto_scaler_profile != null ? [var.auto_scaler_profile] : []

    content {
      balance_similar_node_groups      = auto_scaler_profile.value.balance_similar_node_groups
      expander                         = auto_scaler_profile.value.expander
      max_graceful_termination_sec     = auto_scaler_profile.value.max_graceful_termination_sec
      scale_down_delay_after_add       = auto_scaler_profile.value.scale_down_delay_after_add
      scale_down_unneeded              = auto_scaler_profile.value.scale_down_unneeded
      scale_down_utilization_threshold = auto_scaler_profile.value.scale_down_utilization_threshold
      scan_interval                    = auto_scaler_profile.value.scan_interval
    }
  }

  dynamic "maintenance_window_auto_upgrade" {
    for_each = var.maintenance_window_auto_upgrade != null ? [var.maintenance_window_auto_upgrade] : []

    content {
      frequency   = maintenance_window_auto_upgrade.value.frequency
      interval    = maintenance_window_auto_upgrade.value.interval
      duration    = maintenance_window_auto_upgrade.value.duration
      day_of_week = maintenance_window_auto_upgrade.value.day_of_week
      week_index  = maintenance_window_auto_upgrade.value.week_index
      start_time  = maintenance_window_auto_upgrade.value.start_time
      utc_offset  = maintenance_window_auto_upgrade.value.utc_offset
    }
  }

  lifecycle {
    ignore_changes = [
      # The autoscaler owns the live count once a pool scales; let it.
      default_node_pool[0].node_count,
    ]

    precondition {
      condition     = !var.local_account_disabled || var.azure_active_directory_rbac.enabled
      error_message = "local_account_disabled = true requires azure_active_directory_rbac.enabled = true (there must be an auth path once the local account is off)."
    }

    precondition {
      condition     = !var.workload_identity_enabled || var.oidc_issuer_enabled
      error_message = "workload_identity_enabled requires oidc_issuer_enabled = true."
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.node_pools

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  tags                  = merge(var.tags, coalesce(each.value.tags, {}))

  name                    = each.key
  vm_size                 = each.value.vm_size
  node_count              = each.value.auto_scaling_enabled ? null : each.value.node_count
  auto_scaling_enabled    = each.value.auto_scaling_enabled
  min_count               = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count               = each.value.auto_scaling_enabled ? each.value.max_count : null
  max_pods                = each.value.max_pods
  mode                    = each.value.mode
  os_type                 = each.value.os_type
  os_sku                  = each.value.os_sku
  os_disk_type            = each.value.os_disk_type
  os_disk_size_gb         = each.value.os_disk_size_gb
  priority                = each.value.priority
  spot_max_price          = each.value.spot_max_price
  eviction_policy         = each.value.eviction_policy
  zones                   = each.value.zones
  vnet_subnet_id          = each.value.vnet_subnet_id
  pod_subnet_id           = each.value.pod_subnet_id
  orchestrator_version    = each.value.orchestrator_version
  host_encryption_enabled = each.value.host_encryption_enabled
  fips_enabled            = each.value.fips_enabled
  node_public_ip_enabled  = each.value.node_public_ip_enabled
  node_labels             = each.value.node_labels
  node_taints             = each.value.node_taints

  dynamic "upgrade_settings" {
    for_each = each.value.upgrade_settings != null ? [each.value.upgrade_settings] : []

    content {
      max_surge                     = upgrade_settings.value.max_surge
      drain_timeout_in_minutes      = upgrade_settings.value.drain_timeout_in_minutes
      node_soak_duration_in_minutes = upgrade_settings.value.node_soak_duration_in_minutes
    }
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Attach ACRs: grant the kubelet identity AcrPull so nodes can pull images without a secret.
resource "azurerm_role_assignment" "acr_pull" {
  for_each = var.attached_acr_ids

  scope                            = each.value
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Opt-in add-ons, composed onto the cluster.
resource "azurerm_kubernetes_cluster_extension" "this" {
  for_each = var.cluster_extensions

  cluster_id                       = azurerm_kubernetes_cluster.this.id
  name                             = each.key
  extension_type                   = each.value.extension_type
  version                          = each.value.version
  release_train                    = each.value.release_train
  release_namespace                = each.value.release_namespace
  target_namespace                 = each.value.target_namespace
  configuration_settings           = each.value.configuration_settings
  configuration_protected_settings = each.value.configuration_protected_settings
}

resource "azurerm_kubernetes_cluster_trusted_access_role_binding" "this" {
  for_each = var.trusted_access_role_bindings

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  name                  = each.key
  source_resource_id    = each.value.source_resource_id
  roles                 = each.value.roles
}

resource "azurerm_kubernetes_flux_configuration" "this" {
  for_each = var.flux_configurations

  cluster_id                        = azurerm_kubernetes_cluster.this.id
  name                              = each.key
  namespace                         = each.value.namespace
  scope                             = each.value.scope
  continuous_reconciliation_enabled = each.value.continuous_reconciliation_enabled

  git_repository {
    url                      = each.value.git_repository.url
    reference_type           = each.value.git_repository.reference_type
    reference_value          = each.value.git_repository.reference_value
    sync_interval_in_seconds = each.value.git_repository.sync_interval_in_seconds
    timeout_in_seconds       = each.value.git_repository.timeout_in_seconds
    https_user               = each.value.git_repository.https_user
    https_key_base64         = each.value.git_repository.https_key_base64
    ssh_private_key_base64   = each.value.git_repository.ssh_private_key_base64
  }

  dynamic "kustomizations" {
    for_each = { for k in each.value.kustomizations : k.name => k }

    content {
      name                       = kustomizations.value.name
      path                       = kustomizations.value.path
      sync_interval_in_seconds   = kustomizations.value.sync_interval_in_seconds
      timeout_in_seconds         = kustomizations.value.timeout_in_seconds
      retry_interval_in_seconds  = kustomizations.value.retry_interval_in_seconds
      recreating_enabled         = kustomizations.value.recreating_enabled
      garbage_collection_enabled = kustomizations.value.garbage_collection_enabled
    }
  }

  depends_on = [azurerm_kubernetes_cluster_extension.this]
}

resource "azurerm_kubernetes_cluster_deployment_safeguard" "this" {
  count = var.deployment_safeguard != null ? 1 : 0

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  level                 = var.deployment_safeguard.level
  excluded_namespaces   = var.deployment_safeguard.excluded_namespaces
}

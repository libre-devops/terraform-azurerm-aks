# A fuller cluster: a tainted system node pool (system pods only) plus a user node pool for
# workloads, Container Insights wired to a Log Analytics workspace, the Key Vault CSI driver,
# workload identity, the image cleaner, and a scheduled auto-upgrade window. Applied then
# destroyed in one CI run. VNet integration, private clusters, and the flux/extension add-ons are
# exposed by the module but not exercised here (they need caller topology or a real GitOps repo).
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
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

module "aks" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  name = local.aks_name

  sku_tier                  = "Standard"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  image_cleaner_enabled     = true

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

  maintenance_window_auto_upgrade = {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }
}

output "cluster_id" {
  value = module.aks.cluster_id
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "kvcsi_identity" {
  value = module.aks.key_vault_secrets_provider_identity
}

output "resource_group_name" {
  value = local.rg_name
}

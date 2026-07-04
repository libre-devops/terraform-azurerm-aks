# Minimal call: a single-node Standard-tier cluster with the secure defaults (local account off,
# Azure AD RBAC on, Kubernetes RBAC on, Azure CNI). Applied then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  aks_name = "aks-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "aks" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  name = local.aks_name

  default_node_pool = {
    vm_size    = "Standard_D2s_v6"
    node_count = 1
  }
}

output "cluster_id" {
  value = module.aks.cluster_id
}

output "fqdn" {
  value = module.aks.fqdn
}

output "resource_group_name" {
  value = local.rg_name
}

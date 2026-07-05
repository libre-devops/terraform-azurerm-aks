# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.ContainerService/managedClusters/aks-mock"
      kubelet_identity = [{ object_id = "44444444-4444-4444-4444-444444444444" }]
    }
  }

  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "22222222-2222-2222-2222-222222222222"
      object_id       = "33333333-3333-3333-3333-333333333333"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  name              = "aks-ldo-uks-tst-001"
  tags              = { Environment = "tst" }
}

# Nothing but a name: a Standard-tier cluster with a system node pool, system-assigned identity,
# Azure CNI, and the secure defaults (local account off, AAD RBAC on, k8s RBAC on).
run "fast_to_get_going" {
  command = apply

  assert {
    condition     = azurerm_kubernetes_cluster.this.sku_tier == "Standard"
    error_message = "sku_tier should default to Standard."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.local_account_disabled == true
    error_message = "The local account should be disabled by default."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.role_based_access_control_enabled == true
    error_message = "Kubernetes RBAC should be enabled by default."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control) == 1
    error_message = "AAD RBAC should be enabled by default."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.identity[0].type == "SystemAssigned"
    error_message = "The cluster identity should default to SystemAssigned."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_D2s_v5"
    error_message = "The default node pool vm_size should have a default."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_plugin == "azure"
    error_message = "network_plugin should default to azure (Azure CNI)."
  }
}

# Additional node pool, autoscaling, an extension, a trusted access binding, and monitoring.
run "full_surface" {
  command = apply

  variables {
    default_node_pool = {
      auto_scaling_enabled         = true
      min_count                    = 1
      max_count                    = 3
      only_critical_addons_enabled = true
    }

    oms_agent = {
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-mock"
    }

    key_vault_secrets_provider = { enabled = true, secret_rotation_enabled = true }

    api_server_authorized_ip_ranges = ["203.0.113.0/24"]

    node_pools = {
      "workloads" = {
        vm_size              = "Standard_D4s_v5"
        auto_scaling_enabled = true
        min_count            = 1
        max_count            = 5
      }
    }

    cluster_extensions = {
      "flux" = { extension_type = "microsoft.flux" }
    }

    trusted_access_role_bindings = {
      "backup" = {
        source_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.DataProtection/backupVaults/bv-mock"
        roles              = ["Microsoft.DataProtection/backupVaults/backup-operator"]
      }
    }
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled == true
    error_message = "The default node pool should autoscale."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster_node_pool.this) == 1
    error_message = "The additional node pool should be created."
  }

  assert {
    condition     = azurerm_kubernetes_cluster_extension.this["flux"].extension_type == "microsoft.flux"
    error_message = "The flux extension should be configured."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster_trusted_access_role_binding.this) == 1
    error_message = "The trusted access binding should be created."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this.oms_agent) == 1
    error_message = "The monitoring add-on should be wired."
  }
}

run "rejects_local_account_off_without_aad" {
  command = plan

  variables {
    azure_active_directory_rbac = { enabled = false }
    local_account_disabled      = true
  }

  expect_failures = [azurerm_kubernetes_cluster.this]
}

run "rejects_workload_identity_without_oidc" {
  command = plan

  variables {
    workload_identity_enabled = true
    oidc_issuer_enabled       = false
  }

  expect_failures = [azurerm_kubernetes_cluster.this]
}

# Extensions with nowhere to schedule: critical-addons-only default pool and every user pool
# tainted means the extension pods (which have no tolerations) can never start.
run "rejects_extensions_without_schedulable_pool" {
  command = plan

  variables {
    default_node_pool = {
      only_critical_addons_enabled = true
    }

    node_pools = {
      "workloads" = {
        node_taints = ["workload=general:NoSchedule"]
      }
    }

    cluster_extensions = {
      "flux" = { extension_type = "microsoft.flux" }
    }
  }

  expect_failures = [azurerm_kubernetes_cluster_extension.this]
}

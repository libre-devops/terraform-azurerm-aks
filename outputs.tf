output "cluster" {
  description = "The full AKS cluster object. Sensitive as a whole because it carries kube_config credentials; the id, fqdn, and identity outputs alongside stay plain for composition."
  value       = azurerm_kubernetes_cluster.this
  sensitive   = true
}

output "cluster_id" {
  description = "The cluster id."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "The cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "fqdn" {
  description = "The API server FQDN (public clusters)."
  value       = azurerm_kubernetes_cluster.this.fqdn
}

output "identity_principal_ids" {
  description = "The cluster's { control_plane, kubelet } identity principal ids."
  value = {
    control_plane = try(azurerm_kubernetes_cluster.this.identity[0].principal_id, null)
    kubelet       = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, null)
  }
}

output "key_vault_secrets_provider_identity" {
  description = "The Key Vault CSI driver's user-assigned identity (when the add-on is enabled), to grant Key Vault access to."
  value       = try(azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0], null)
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster (local-account access; empty when local_account_disabled)."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "node_pool_ids" {
  description = "Map of additional node pool name to id."
  value       = { for k, p in azurerm_kubernetes_cluster_node_pool.this : k => p.id }
}

output "node_resource_group" {
  description = "The auto-created resource group holding the cluster's node infrastructure."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL (when oidc_issuer_enabled), for federating workload identities."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "private_fqdn" {
  description = "The API server private FQDN (private clusters)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

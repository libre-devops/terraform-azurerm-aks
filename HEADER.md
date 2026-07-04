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

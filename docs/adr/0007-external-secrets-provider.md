# ADR-0007: External Secrets Provider (GitLab CI/CD Variables)

* **Status:** Accepted
* **Date:** 2026-08-16
* **Author:** Neil Kester

## 1. Context
Feature 3.3 requires a secure mechanism to inject credentials into the Kubernetes cluster without committing plaintext or base64-encoded tokens to the Git repository. We evaluated HashiCorp Vault, Mozilla SOPS, Bitnami Sealed Secrets, and GitLab CI/CD Variables. Vault introduces significant operational overhead (unseal protocols, consensus quorums) for a 3-node bare-metal cluster and is now Business Source License (BSL). SOPS and Sealed Secrets provide 100% offline capability but require managing master decryption keys locally within the cluster.

## 2. Decision
We selected **GitLab CI/CD Variables** integrated via the **External Secrets Operator (ESO)** as the SecretStore provider. ESO will poll GitLab using a least-privileged (`read_api` scope) token to fetch ciphertext and dynamically generate native Kubernetes `Secret` resources directly in `etcd`.

## 3. Consequences
* **Positive:** Zero administrative overhead for a secondary database. Unified Role-Based Access Control (RBAC) via the existing source of truth (GitLab). Strict adherence to the Zero-Token-in-Git policy.
* **Negative:** Introduces a hard dependency on the WAN interface. If the internet drops, ESO cannot fetch new secrets or rotate existing ones.
* **Neutral:** Existing secrets are cached in `etcd`, meaning a WAN outage does not disrupt active workloads unless a pod restarts require a *new* secret or a total bare-metal rebuild is required.

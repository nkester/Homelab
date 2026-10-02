# ADR-0005: In-Cluster GitLab Runner for Private Enclave Orchestration

* **Status:** Accepted
* **Date:** 2026-08-11
* **Deciders:** Senior Platform Engineer / ORSA & Gemini GitOps Lab Architect
* **Technical Area:** CI/CD & Security Architecture

---

## Context and Problem Statement

During the execution of Feature 3.1 (GitOps & Workflow Orchestration), pipeline jobs triggered on GitLab.com SaaS shared runners (`*.saas-linux-small-amd64.runners-manager.gitlab.com`) failed when issuing REST API cURL payloads to `https://10.10.10.10:2746`. 

Public cloud SaaS runners reside in GCP/AWS networks and cannot route to private RFC 1918 IP addresses (`10.10.10.0/24`) isolated inside the homelab's VLAN 10 enclave over the public internet.

The platform required an architecture that allows event-driven pipeline triggers to reach the internal `argo-server` REST API without compromising WAN Zero-Trust perimeter security.

---

## Decision Drivers

* **Zero-Trust Inbound Perimeter:** Avoid opening WAN firewall ports, port-forwarding on the ER605 router, or exposing internal cluster endpoints directly to the public internet.
* **Network Isolation:** Allow CI execution jobs to natively access internal L2/L3 services (`argo-server`, CoreDNS `argo-server.argo-workflows.svc:2746`, CloudNativePG, MiniO).
* **Resource & Quota Optimization:** Offload heavy compute tasks from the 400-minute monthly limit on GitLab SaaS Free Tier runners.

---

## Considered Options

1. **Option 1: Expose Argo Server via Ingress / Port Forwarding on Router (Rejected)**
   * *Cons:* Violates Zero-Trust perimeter rules; exposes control plane APIs to public internet probes.
2. **Option 2: Deploy In-Cluster GitLab Runner in VLAN 10 (Selected)**
   * *Pros:* Runner pod connects *outbound* over HTTPS (TCP 443) to `gitlab.com` to poll for jobs. Zero inbound ports required. Runs inside VLAN 10 with native L2/L3 access to cluster services. Consumes 0 SaaS compute minutes.

---

## Decision Outcome

**Selected Option:** Option 2 — Deploy an in-cluster `gitlab-runner` agent in namespace `gitlab-runner` managed declaratively by ArgoCD. Pipeline jobs requiring internal REST API access are tagged with `tags: [homelab-runner]`.

---

## Consequences

* **Positive:**
  * Zero-Trust WAN boundary preserved (default-deny inbound).
  * 100% offload of CI compute minutes from GitLab SaaS quota.
  * Direct L2/L3 access to internal cluster services and CoreDNS (`argo-server.argo-workflows.svc:2746`).
* **Negative:**
  * Requires local pod CPU/RAM allocation on worker nodes for runner execution.
  * Requires out-of-band runner authentication token management via cluster secrets.

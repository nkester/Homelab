# ADR-0009: Serverless Execution and Ingress Strategy (Knative + Kourier vs NGINX)

* **Status:** Accepted
* **Date:** 2026-11-23
* **Author:** Neil Kester

## 1. Context
To provide a Serverless Function-as-a-Service (FaaS) layer that mirrors AWS Lambda's scale-to-zero capabilities, we are deploying **Knative Serving**. Knative requires an Ingress gateway to dynamically route traffic to its pods, managing cold starts and scaling algorithms. 

We had previously delayed the deployment of our general cluster ingress (NGINX Ingress Controller) from Feature 3.4. We needed to decide whether to standardize on a single Ingress Controller (NGINX) for the entire cluster (including Knative) or follow Knative's upstream recommendation of using Kourier for internal serverless routing while maintaining NGINX for external cluster traffic.

## 2. Decision
We selected **Option A**, which deploys **Kourier** specifically for Knative Serving and simultaneously deploys the **NGINX Ingress Controller** for general cluster HTTP traffic.

Key Architectural Decisions:
1. **Dedicated Knative Gateway:** Kourier (Envoy-based) acts as the dedicated gateway for Knative Serving and receives LoadBalancer IP `10.10.10.17` assigned by Cilium L2 LoadBalancer IPAM (`CiliumLoadBalancerIPPool/homelab-lb-pool`, explicitly bounded to `10.10.10.17 - 10.10.10.25` to prevent overlap with the ER605 VLAN 10 DHCP pool `10.10.10.30 - 10.10.10.99`).
2. **Cluster HTTP Ingress:** NGINX acts as the primary cluster ingress, satisfying the delayed requirement from Feature 3.4, and receives LoadBalancer IP `10.10.10.18` announced via Cilium Layer 2 Announcement Policy (`CiliumL2AnnouncementPolicy/homelab-l2-announcement`).
3. **Load Balancer Engine Alignment:** Replaces obsolete assumptions regarding `kube-vip`. As established in ADR-0003, Talos Native VIP is strictly dedicated to the Control Plane API Server (`10.10.10.10:6443`). All in-cluster `Service` objects of type `LoadBalancer` are provisioned and ARP-announced exclusively by the CNI via Cilium eBPF L2 announcements (ADR-0004).

## 3. Consequences
* **Positive:** By using Kourier, we align with Knative's default, officially supported ingress, avoiding the risk and compatibility issues of relying on a community NGINX plugin. Knative's latency-sensitive traffic is isolated from heavy, long-lived data transfers (like S3 traffic to MinIO) handled by NGINX. We also immediately resolve the technical debt by establishing our primary HTTP ingress for the cluster (NGINX) which will operate safely on HTTP and self-signed HTTPS until `cert-manager` is deployed in Epic 4.
* **Positive:** Avoids deploying redundant third-party load balancer daemons (MetalLB, kube-vip) by utilizing Cilium's native eBPF L2 announcement capabilities directly on the node network interface.
* **Negative:** Running two separate ingress controllers increases baseline memory and CPU utilization.
  * **Mitigation:** Post-Feature 3.4-R hardware consolidation (ADR-0010) expanded cluster capacity to 40 GB RAM across all-desktop Gigabit nodes (`controlplane-1`: 20 GB, `worker-1`: 12 GB, `worker-2`: 8 GB), eliminating the prior 4 GB worker memory constraint. Ongoing telemetry will be tracked in Epic 5 (Observability).
* **Operational Prerequisite:** Both ingress services require `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy` custom resources to transition their `EXTERNAL-IP` from `<pending>` to active on the physical subnet.

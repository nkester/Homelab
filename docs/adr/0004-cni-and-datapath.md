# ADR-0004: Selection of Cilium for CNI and eBPF Datapath

* **Status:** Accepted
* **Date:** 2026-07-30
* **Author:** Neil Kester

## Context
The bare-metal Kubernetes cluster runs on Talos Linux and requires a Container Network Interface (CNI) to manage pod-to-pod communication, network security policies, and service routing. Standard CNI implementations rely heavily on legacy `iptables` or `IPVS` for routing, which introduces significant overhead and complexity at scale. The architecture requires a zero-trust network model, deep observability into network flows, and optimal performance that aligns with modern systems engineering standards.

## Decision
We will deploy **Cilium** (v1.15+) as the designated CNI, utilizing its eBPF (Extended Berkeley Packet Filter) datapath natively. 
*   **Kube-Proxy Replacement:** We will operate Cilium with strict `kubeProxyReplacement: true`, eliminating the reliance on `kube-proxy` and `iptables` for Kubernetes service routing.
*   **Routing Mode & CIDR:** We will use native routing (`routingMode: native`) with direct node routes (`autoDirectNodeRoutes: true`) for pod CIDR `10.244.0.0/16` across physical nodes (`10.10.10.0/24`), avoiding overlay encapsulation overhead.
*   **Service LoadBalancer IPAM & L2 Announcements:** We will utilize Cilium's native Layer 2 announcements and LoadBalancer IPAM (`CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy`). Cilium acts as the authoritative L2 ARP responder and IP allocator for cluster `LoadBalancer` services (such as NGINX Ingress and Knative Kourier) within the `10.10.10.0/24` subnet, permanently deprecating external load-balancer solutions (`kube-vip` service mode, MetalLB).
*   **Observability:** Hubble and Hubble Relay will be enabled to provide flow telemetry, bound natively to service port `4245/TCP` for datapath validation.

## Consequences
*   **Positive:** Substantially lower network latency and CPU overhead due to eBPF packet processing at the kernel level. Immediate, granular visibility into network flows across physical fault domains via Hubble.
*   **Positive:** Unified network data plane: CNI, service mesh, security policies, and Service LoadBalancer IPAM/L2 announcements are consolidated entirely inside Cilium eBPF without extraneous daemons.
*   **Negative/Constraint:** Modifying immutable service ports for Hubble Relay post-deployment requires state-forcing via OpenTofu (taint/replace). eBPF debugging requires specialized tooling compared to traditional `iptables` diagnostics.
*   **Operational Requirement:** Services of type `LoadBalancer` remain in `Pending` until explicit `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy` custom resources are declared and synced.
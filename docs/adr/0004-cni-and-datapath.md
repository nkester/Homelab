# ADR 0004: Selection of Cilium for CNI and eBPF Datapath

* **Status:** Accepted
* **Date:** 2026-07-30
* **Author:** Neil Kester

## Context
The bare-metal Kubernetes cluster runs on Talos Linux and requires a Container Network Interface (CNI) to manage pod-to-pod communication, network security policies, and service routing. Standard CNI implementations rely heavily on legacy `iptables` or `IPVS` for routing, which introduces significant overhead and complexity at scale. The architecture requires a zero-trust network model, deep observability into network flows, and optimal performance that aligns with modern systems engineering standards.

## Decision
We will deploy **Cilium** as the designated CNI, utilizing its eBPF (Extended Berkeley Packet Filter) datapath natively. 
*   **Kube-Proxy Replacement:** We will operate Cilium with strict `kubeProxyReplacement: true`, entirely eliminating the reliance on `kube-proxy` and `iptables` for Kubernetes service routing.
*   **Routing Mode:** We will use native routing (`routingMode: native`) with direct node routes (`autoDirectNodeRoutes: true`) to avoid overlay network encapsulation overhead across the physical nodes.
*   **Observability:** Hubble and Hubble Relay will be enabled to provide flow telemetry, bound natively to port `4245/TCP` for datapath validation.

## Consequences
*   **Positive:** Substantially lower network latency and CPU overhead due to eBPF packet processing at the kernel level. Immediate, granular visibility into network flows across physical fault domains via Hubble.
*   **Negative/Constraint:** Modifying immutable service ports for Hubble Relay post-deployment requires state-forcing via OpenTofu (taint/replace). eBPF debugging requires specialized tooling compared to traditional `iptables` diagnostics.
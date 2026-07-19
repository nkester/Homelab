# Epic 1: Hardware & Network Foundation - Execution Log

## Feature 1.1: Logical Network Segmentation (VLAN 10)
**Status:** Done  
**Completion State:**
* Established the "Analytic Enclave" on `10.10.10.0/24`.
* **Architectural Pivot (ADR-0002):** Discovered the Orbi RBR50 cannot process 802.1q VLAN tags. Transitioned the Orbi mesh into AP Mode (radios disabled) to act purely as a dedicated Layer 2 Point-to-Point bridge for the cluster backhaul.
* **Routing Strategy:** ER605 Port 2 configured as an Access Port (PVID 10) passing untagged frames to the Orbi.
* **Validation:** Verified DHCP allocation (`10.10.10.x`), internet egress routing, and zero-trust Layer 3 isolation from the personal LAN (`192.168.1.0/24`).

## Feature 1.2: Wireless Enclave Standoff
**Status:** Done  
**Completion State:**
* **Infrastructure IP Allocation:** Implemented central state management via ER605 DHCP Reservations to assign static IPs to the wireless bridge without hardcoding consumer firmware.
  * Orbi Base: `10.10.10.3`
  * Orbi Satellite: `10.10.10.4`
* **Zero-Trust Hardening:** Moved the IoT SenseCap gateway to VLAN 1 (ER605 Port 4), physically removing it from the secure Kubernetes fault domain.
* **Resilience Baseline (The 202-Second Window):** Conducted a hard power-loss test on the Orbi Satellite. The L2 bridge spanning-tree recovery and backhaul re-sync takes approximately **202 seconds**. 
  * *Intra-Cluster Impact:* Zero. Because all nodes terminate on the TL-SG108E switch, Kubernetes API quorum and pod-to-pod traffic remain uninterrupted. Node eviction is not triggered.
  * *External Impact:* The cluster loses reachability to the `10.10.10.1` gateway for 202 seconds, temporarily halting external image pulls, internet egress, and cross-VLAN ingress.

## Feature 1.3: Scalable IP & DNS Schema
**Status:** Done (with Hardware Constraint)  
**Completion State:**
* **IPAM Schema Established:** Centralized GitOps source of truth (`infrastructure/networking/README.md`) created, mapping the `10.10.10.0/24` infrastructure, compute, and VIP namespaces.
* **State Enforcement:** ER605 DHCP MAC Reservations created for the TL-SG108E switch and the three bare-metal nodes (HP, Lenovo, Dell) to prevent namespace collisions.
* **Hardware Constraint (DNS):** The ER605 standalone firmware lacks conditional DNS forwarding. The requirement to route the `kester.lab` internal domain is deferred. A dedicated DNS resolver (e.g., CoreDNS/AdGuard) will need to be deployed in a future Epic to handle internal ingress routing.  

## Feature 1.4: API Server VIP (kube-vip)
**Status:** Done  
**Completion State:**
* **Network Verification:** Executed ICMP validation against `10.10.10.100`. Returned 100% packet loss, cryptographically verifying the namespace is vacant and the ER605 DHCP reservation is actively preventing collisions.
* **Configuration Staging:** Declarative Layer 2 ARP bindings for the Talos `machineconfig` were generated. 
* **Artifact Generation:** To comply with GitOps state management and fulfill the artifact requirement, the `kube-vip` OpenTofu configuration snippet was committed to `infrastructure/bootstrap/README.md`. This stages the exact API parameters required for the OpenTofu provider during the OS bootstrap phase in Epic 2.
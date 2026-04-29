# Epic 1: Hardware & Network Foundation - Execution Log

## Feature 1.1: Logical Network Segmentation (VLAN 10)
**Status:** Done
**Completion State:**
* Established the "Analytic Enclave" on `10.10.10.0/24`.
* **Architectural Pivot (ADR-0002):** Discovered the Orbi RBR50 cannot process 802.1q VLAN tags. Transitioned the Orbi mesh into AP Mode (radios disabled) to act purely as a dedicated Layer 2 Point-to-Point bridge for the cluster backhaul.
* **Routing Strategy:** ER605 Port 2 configured as an Access Port (PVID 10) passing untagged frames to the Orbi.
* **Validation:** Verified DHCP allocation (`10.10.10.x`), internet egress routing, and zero-trust Layer 3 isolation from the personal LAN (`192.168.1.0/24`).

## Feature 1.2: Wireless Enclave Standoff
**Status:** In Progress
* *Log pending execution.*
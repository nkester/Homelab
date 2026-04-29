# ADR 0002: Utilization of Orbi Mesh as a Dedicated L2 Bridge for Cluster Backhaul

* **Status:** Accepted
* **Date:** 2026-04-29
* **Author:** Neil Kester

## Context
Feature 1.1 requires logical network segmentation (VLAN 10 on `10.10.10.0/24`) for the bare-metal Kubernetes nodes to establish a secure, default-deny fault domain. The physical network topology relies on an ER605 gateway and an Orbi RBR50 mesh system. 

Initial designs attempted to pass an 802.1q VLAN trunk through the Orbi. However, the Orbi RBR50 consumer firmware strips 802.1q tags and lacks managed switchport capabilities, resulting in a Layer 2 routing blackhole and zero-trust violations for connected wireless clients. Physical constraints prevent running direct CAT6 cabling from the ER605 to the cluster's aggregation switch (TL-SG108E).

## Decision
We will bypass the Orbi's 802.1q limitations by terminating the logical boundary at the ER605 switchport. 
1. ER605 Port 2 is configured as an Access Port (PVID 10), passing untagged VLAN 10 frames.
2. The Orbi system is placed in AP Mode with all wireless client radios/SSIDs disabled, functioning strictly as a dedicated, Point-to-Point (PtP) Layer 2 wireless bridge.
3. The bare-metal nodes connect to a TL-SG108E unmanaged aggregation switch, which uplinks to the Orbi Satellite.

## Consequences
* **Positive:** Achieves strict logical isolation for the `10.10.10.0/24` subnet without requiring new cabling or enterprise hardware. Intra-cluster traffic (etcd quorum, Longhorn synchronous block storage) is localized to the TL-SG108E switch backplane(API server access, container image pulls, Velero off-site backups).  

* **Negative:** Ingress and egress traffic (API server access, container image pulls, Velero off-site backups) must traverse the consumer wireless backhaul. We formally accept the risk of latency spikes during heavy external I/O operations.
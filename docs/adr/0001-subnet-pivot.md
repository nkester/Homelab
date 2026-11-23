# ADR-0001: Subnet Pivot to 192.168.1.x

* **Status:** Superseded by ADR-0002
* **Date:** 2026-04-17 (Superseded: 2026-04-29)
* **Author:** Neil Kester

## Context and Problem Statement
The original plan was to isolate the lab on a custom subnet. However, the Verizon CR1000A gateway firmware enforces strict sanity checks that prevent the ER605 from operating effectively as a downstream router if the subnets do not align with the gateway's internal expectations for "DMZ" or "Passthrough" modes.

## Decision Drivers
1. **Simplicity**: Reduce complexity in the Talos `MachineConfig` static IP assignments.
2. **Stability**: Avoid firmware-level routing loops or blocked traffic at the ISP gateway.
3. **Speed to Cluster Up**: Prioritize environment stability over complex network isolation at the physical layer.

## Considered Options
1. **Ideal**: Force custom subnet via firmware modification/replacement (High Risk).
2. **High-Compatibility (Selected - Temporary)**: Move the ER605 and all lab nodes to the 192.168.1.0/24 space.

## Decision Outcome
Selected Option 2. The ER605 was temporarily configured as the primary DHCP/DNS authority for the 192.168.1.1 neighborhood.

> **Supercession Note (2026-04-29):** This temporary configuration was formally superseded by **ADR-0002**. The lab was re-architected to isolate all bare-metal nodes onto VLAN 10 (`10.10.10.0/24`) by operating the Orbi mesh in dedicated Access Point (PtP) bridge mode attached to ER605 Port 2 (PVID 10).

## Consequences
- **Positive**: Simplified initial node discovery; standard gateway (192.168.1.1) unblocked initial hardware bring-up.
- **Negative**: Less isolation from other home devices if not managed by Cilium L3 policies.
- **Superseded Outcome**: Fully resolved by ADR-0002, which restored true physical/logical network isolation on `10.10.10.0/24`.
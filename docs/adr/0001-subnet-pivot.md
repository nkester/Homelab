# ADR 0001: Subnet Pivot to 192.168.1.x

**Status:** Accepted
**Date:** 2026-04-17
**Deciders:** NK, GitOps Lab Architect

## Context and Problem Statement
The original plan was to isolate the lab on a custom subnet. However, the Verizon CR1000A gateway firmware enforces strict sanity checks that prevent the ER605 from operating effectively as a downstream router if the subnets do not align with the gateway's internal expectations for "DMZ" or "Passthrough" modes.

## Decision Drivers
1. **Simplicity**: Reduce complexity in the Talos `MachineConfig` static IP assignments.
2. **Stability**: Avoid firmware-level routing loops or blocked traffic at the ISP gateway.
3. **Speed to Cluster Up**: Prioritize environment stability over complex network isolation at the physical layer.

## Considered Options
1. **Ideal**: Force custom subnet via firmware modification/replacement (High Risk).
2. **High-Compatibility (Selected)**: Move the ER605 and all lab nodes to the 192.168.1.0/24 space.

## Decision Outcome
Selected Option 2. The ER605 is now the primary DHCP/DNS authority for the 192.168.1.1 neighborhood.

## Consequences
- **Positive**: Simplified node discovery; standard gateway (192.168.1.1).
- **Negative**: Less isolation from other home devices if not managed by Cilium L3 policies.
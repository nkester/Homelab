# Project Log: Epic 0 - Project & Environment Stabilization

## Summary
Epic 0 focused on establishing the physical and logical foundations of the home lab, transitioning from unstructured hobbyist configurations to a formalized Platform Engineering framework.

## Key Milestones
- **2026-04-15**: Initial repository initialization and directory scaffolding.
- **2026-04-20**: **ADR-0001 (Subnet Pivot)** implemented. Relocated ER605 to `192.168.1.1` to bypass CR1000A firmware routing limitations.
- **2026-04-25**: Physical inventory audited and hardware-specific configurations (MAC addresses, static IP mappings) documented.
- **2026-04-27**: Documentation scaffolding (Feature 0.5) established, including the 4-Tier Platform Model and Architectural Decision Record system.

## Technical Debt & Known Constraints
- **RAM Constraints**: Lenovo Worker 01 (4GB) and Dell Worker 02 are near the minimum threshold for heavy analytic workloads.
- **Network Isolation**: The subnet pivot improved connectivity but requires robust Cilium network policies in future Epics to maintain security boundaries.

## Retrospective Integration
- **Key Insight**: Future hardware purchases must prioritize RAM over CPU for the analytic workload layer.
- **Process Correction**: Adopted a "Stop-and-Check" protocol to ensure Definition of Done (DoD) compliance before advancing project states.
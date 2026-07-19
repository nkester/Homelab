# TEMPORARY: The "What" - System State

This is the Living Manual. It describes the system as it exists right now. If you handed your laptop to another engineer, this is where they would look to understand how to interact with the lab.

Content: The README.md we discussed (Layers/Functions), User Guides, and standard operating procedures (SOPs).

Scope: Current configurations, IP tables, and physical cabling maps.

# GitOps Lab: Functional System Manual

## 1. System Mission & Strategy
This repository implements an immutable, bare-metal Kubernetes platform designed for Operations Research and Systems Analysis (ORSA). It utilizes a **GitOps-driven** lifecycle, ensuring that the cluster state is always reproducible, secure, and documented.



## 2. Platform Architecture (4-Tier Framework)

Documentation and configurations are organized by functional layers to isolate failure domains and simplify lifecycle management.

### Layer I: Physical Infrastructure
*Focus: Hardware inventory, power, and Layer 1/2 connectivity.*
- **[Hardware & Storage Inventory](./hardware_inventory.csv)**: Detailed Bill of materials for all cluster nodes and networking equipment.
- **[L1/L2 Topology](./architecture/01-physical-network.md)**: Physical cabling diagram and switch port assignments.

### Layer II: Logical Network & Provisioning
*Focus: Immutable OS (Talos), CNI (Cilium), and IP Address Management (IPAM).*
- **[Talos MachineConfigs](../../infrastructure/bootstrap/README.md)**: Node-level configurations and API-driven OS management.
- **[Networking & VIP Strategy](../../infrastructure/networking/README.md)**: `kube-vip` configuration and Cilium eBPF implementation.
- **[ADR-0001: Subnet Pivot](./adr/0001-subnet-pivot.md)**: Documentation of the shift to the 192.168.1.x neighborhood.

### Layer III: Management Plane
*Focus: GitOps synchronization, persistent storage, and cluster-wide services.*
- **[ArgoCD Control Plane](../../argocd/README.md)**: The source of truth for all application deployments.
- **[Longhorn Distributed Storage](../../infrastructure/storage/README.md)**: Block storage orchestration and volume replication policies.
- **[External Secrets Management](../../infrastructure/secrets/README.md)** (*Planned*): Integration with secure credential providers.

### Layer IV: Workload Layer
*Focus: Analytic applications and data persistence.*
- **[CloudNativePG (PostgreSQL)](../../apps/database/README.md)**: High-availability database clusters for backend data.
- **[ORSA Analytics Suite](../../apps/analytics/README.md)**: VSCode Server, RStudio, and KubeFlow orchestration.

## 3. Engineering Governance
- **[Architectural Decision Records (ADR)](./adr/README.md)**: Formal records of significant design pivots.
- **[Project Logs](./logs/README.md)**: Chronological record of technical epics and milestones.
- **[Retrospectives](./retrospective.csv)**: Lessons learned and process improvements.
# GitOps Lab: Functional System Manual

This is the Living Manual. It points the reader to pertinent information about the system and the process.

## 1. System Mission & Strategy
This repository implements an immutable, bare-metal Kubernetes platform designed for Operations Research and Systems Analysis (ORSA) workflows and analyses. It utilizes a **GitOps-driven** lifecycle, ensuring that the cluster state is always reproducible, secure, and documented.

## 2. File Structure  

```text
.
├── adr                   # Architectural Decision Record (ADR): The "Why" decisions were made that resulted in this architecture
├── architecture          # The "What" - describing the system state 
├── implementation plans  # The "How" - describing how we built the architecture
├── logs                  # Project logs describing pivots, changes, and milestones.
└── runbooks              # Day-2 operational runbooks (UI/API access, port-forwards, read-only diagnostics)
```

## 3. Platform Architecture (4-Tier Framework)

Documentation and configurations are organized by functional layers to isolate failure domains and simplify lifecycle management.

### Layer I: Physical Infrastructure
*Focus: Hardware inventory, power, and Layer 1/2 connectivity.*
- **[Hardware & Storage Inventory](./hardware_inventory.csv)**: Detailed Bill of materials for all cluster nodes and networking equipment.
- **[L1/L2 Topology](./architecture/01-physical-network.md)**: Physical cabling diagram and switch port assignments.

### Layer II: Logical Network & Provisioning
*Focus: Immutable OS (Talos), CNI (Cilium), and IP Address Management (IPAM).*
- **[Talos MachineConfigs](../../infrastructure/bootstrap/README.md)**: Node-level configurations and API-driven OS management.
- **[Networking & VIP Strategy](../../infrastructure/networking/README.md)**: Talos Native VIP (API Server) and Cilium eBPF LB-IPAM / L2 Announcements.
- **[ADR-0001: Subnet Pivot](./adr/0001-subnet-pivot.md)**: Documentation of the shift to the 192.168.1.x neighborhood.

### Layer III: Management Plane
*Focus: GitOps synchronization, persistent storage, and cluster-wide services.*
- **[ArgoCD Control Plane](../../argocd/README.md)**: The source of truth for all application deployments.
- **[Longhorn Distributed Storage](../../infrastructure/storage/README.md)**: Block storage orchestration and volume replication policies.
- **[External Secrets Management](./architecture/06-external-secrets-integration.md)**: Integration with GitLab CI/CD Variables via External Secrets Operator.
- **[Serverless Execution (Knative)](./architecture/08-serverless-execution.md)**: Scale-to-zero FaaS control plane, Kourier gateway, and Argo Workflows triggers.

### Layer IV: Workload Layer
*Focus: Analytic applications and data persistence.*
- **[CloudNativePG (PostgreSQL)](../../apps/database/README.md)**: High-availability database clusters for backend data.
- **[ORSA Analytics Suite](../../apps/analytics/README.md)**: VSCode Server, RStudio, and KubeFlow orchestration.

## 4. Engineering Governance & Operations
- **[Cluster Access Runbook](./runbooks/cluster-access.md)**: Centralized UI/API port-forwards, token extraction, and read-only health checks.
- **[Architectural Decision Records (ADR)](./adr/README.md)**: Formal records of significant design pivots.
- **[Project Logs](./logs/README.md)**: Chronological record of technical epics and milestones.
- **[Retrospectives](./Retrospective.csv)**: Lessons learned and process improvements.
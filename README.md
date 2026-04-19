# Purpose  

I developed my first homelab Kubernetes cluster in 2021 - 2022, but it fell into disrepair when we moved in 2022. This is my updated work on the project and is intended to be a much more robust and deliberate effort. 

This project establishes an enterprise-grade, bare-metal Kubernetes analytics platform—the "Expandable Enclave"—designed for high-fidelity Operations Research and systems engineering workloads using a strictly FOSS, GitOps-driven architecture. Built upon a heterogeneous hardware footprint of HP, Lenovo, and Dell nodes, the environment leverages Talos Linux for immutable, API-driven operations and Cilium for eBPF-powered zero-trust networking, ensuring a resilient foundation for distributed data layers like CloudNativePG and Longhorn. Central to this effort is the collaborative integration with Gemini (operating as the "GitOps Lab Architect"), serving as a senior technical peer to translate architectural intent into declarative manifests and structured backlogs. For a comprehensive exploration of the engineering trade-offs and logical schematics, refer to the detailed **Architectural Decision Records (ADRs)** and system models located in the `docs/adr` and `docs/architecture` directories.

The Source of Truth for this Project is located in GitLab as a private repository here: https://gitlab.com/nkester-personal-cloud/homelab 

It's protected branches are mirrored to my public GitHub repository here: https://github.com/nkester/homelab

Below is the folder structure for the project:

```text
/
├── .gitlab/                # CI/CD pipelines (for linting and validation)
├── docs/                   # The "Commentary" layer
│   ├── adr/                # Architectural Decision Records (The "Why")
│   └── architecture/       # Mermaid/Python diagrams and technical deep-dives
├── infrastructure/         # The "Platform" layer (Cluster-wide services)
│   ├── bootstrap/          # Talos machine configs (templates)
│   ├── networking/         # Cilium and Ingress manifests
│   └── storage/            # Longhorn configuration
├── apps/                   # The "Workload" layer
│   ├── analytics/          # RStudio, VSCode, KubeFlow manifests
│   └── database/           # CloudNativePG configurations
├── argocd/                 # The "Controller" layer (App-of-Apps manifests)
└── scripts/                # Helper scripts for talosctl or maintenance
```
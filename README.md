# Purpose  

I developed my first homelab Kubernetes cluster in 2021 - 2022, but it fell into disrepair when we moved in 2022. This is my updated work on the project and is intended to be a much more robust and deliberate effort. 

This project establishes an enterprise-grade, bare-metal Kubernetes analytics platform—the "Expandable Enclave"—designed for high-fidelity Operations Research and systems engineering workloads using a strictly FOSS, GitOps-driven architecture. Built upon a heterogeneous hardware footprint of HP, Lenovo, and Dell nodes, the environment leverages Talos Linux for immutable, API-driven operations and Cilium for eBPF-powered zero-trust networking, ensuring a resilient foundation for distributed data layers like CloudNativePG and Longhorn. Central to this effort is the collaborative integration with Gemini (operating as the "GitOps Lab Architect"), serving as a senior technical peer to translate architectural intent into declarative manifests and structured backlogs. For a comprehensive exploration of the engineering trade-offs and logical schematics, refer to the detailed **Architectural Decision Records (ADRs)** and system models located in the `docs/adr` and `docs/architecture` directories.

The Source of Truth for this Project is located in GitLab as a private repository here: https://gitlab.com/nkester-personal-cloud/homelab 

It's protected branches are mirrored to my public GitHub repository here: https://github.com/nkester/homelab

Below is the folder structure for the project:

```text
.
├── apps                    # The "Workload" layer
│   ├── analytics           # RStudio, VSCode, KubeFlow manifests
│   └── database            # CloudNativePG configurations
├── argocd                  # The "Controller" layer (App-of-Apps manifests)
│   └── apps                # ArgoCD App-of-Apps manifests
├── docs                    # The "Commentary" layer
│   ├── adr                 # Architectural Decision Records (The "Why")
│   ├── architecture        # Mermaid/Python diagrams and technical deep-dives
│   └── logs                # Chronological project logs and epic summaries
├── infrastructure          # The "Platform" layer (Cluster-wide services)  
│   ├── bootstrap           # Talos machine configs (templates)
│   │   ├── argo-workflows  # Argo Workflows manifests
│   │   └── gitlab-runner   # GitLab Runner manifests
│   ├── networking          # Cilium and Ingress manifests
│   └── storage             # Longhorn configuration
└── scripts                 # Helper scripts for talosctl or maintenance

```
# The Plan

In conjunction with a Gemini GEM, I developed an initial project plan to guide my development and give the GEM an understanding of the approach. The epic and feature list and the status of each effort are listed below. I will update these as they evolve.

As the project progresses, I will create a tag for each Epic as it is merged into the `Homelab 2026` branch so we can step back in time.

## 🗺️ High Level Project Roadmap

See the [Roadmap](./docs/HomeLab_Project_Roadmap.csv) for the latest plan.  

Legend:  
✅ Complete: Tested, verified, and merged.  🔵 In Progress: Current active development.
🔲 Backlog: Planned feature set.

<details>
<summary>Click here to expand the plan</summary>

```
✅ Epic 0: Project & Environment Stabilization  

  ✅ Feature 0.1: Mirror GitLab Project to Github  
  
      - Automated mirroring of protected branches for public portfolio visibility.  

  ✅ Feature 0.2: Establish Physical Network Structure  
  
      - Cabling ONT → ER605 → CR1000A/Orbi and aligning the .1.x management subnet.  

  ✅ Feature 0.3: Establish Project File Structure  
  
      - Scaffolding the monorepo directories (docs/, infrastructure/, apps/, etc.).  

  ✅ Feature 0.4: Write Introduction Readme  
  
      - Authoring professional project overviews and initial technical documentation.  

  ✅ Feature 0.5: Establish Documentation Scaffolding  

      - Implement a tiered documentation structure separating current state, architectural intent, and decision history.
  

✅ Epic 1: Hardware & Network Foundation  

  ✅ Feature 1.1: Logical Network Segmentation (VLAN 10)  
      
      - Isolating the analytic enclave on the ER605 and defining inter-VLAN routing.  

  ✅ Feature 1.2: Wireless Enclave Standoff  
  
      - Validating the Orbi mesh backhaul as a stable bridge for the remote compute nodes.  

  ✅ Feature 1.3: Scalable IP & DNS Schema  
  
      - Defining static reservations and DNS forwarders for cluster services.  
      
  ✅ Feature 1.4: API Server VIP (kube-vip)  
  
      - Implementing a Virtual IP for Kubernetes control plane high availability.  

✅ Epic 2: Kubernetes Bootstrap (Talos OS)  

  ✅ Feature 2.1: Control Node Preparation and Provisioning 
  
      - Generating Talos image, flashing hardware, and initializing the control node via OpenTofu as declarative Infrastructure as Code (IaC) for the HP.  

  ✅ Feature 2.2: Worker Node 1 Preparation and Provisioning  
  
      - Generating Talos image, flashing hardware, and initializing the worker node 1 via OpenTofu as declarative Infrastructure as Code (IaC) for the Lenovo.  

  ✅ Feature 2.3: Worker Node 2 Preparation and Provisioning  
  
      - Generating Talos image, flashing hardware, and initializing the worker node 2 via OpenTofu as declarative Infrastructure as Code (IaC) for the Dell.
      
  ✅ Feature 2.4: Cilium CNI Deployment
  
      - Deploying eBPF-based networking for the cluster.

🔵 Epic 3: GitOps & Analytic Stack  

  ✅ Feature 3.1: GitOps & Workflow Orchestration (ArgoCD & Argo Workflows) 
  
      - Installing ArgoCD and Argo Workflows and bootstrapping the 'App-of-Apps' pattern.  

  ✅ Feature 3.2: CNI & Storage Integration

      - Finalize network policies and distributed storage for apps.
  
  ✅ Feature 3.3: External Secret Management (ESO)  
  
      - Integrating External Secrets Operator to securely pull credentials from GitLab.  

  ✅ Feature 3.4: Object Storage Foundation (MiniO)  
  
      - Provide S3 API functionality to support data pipelines and backups.  

  🔵 Feature 3.5: Serverless Execution through Knative

      - Implement Knative Serving to mirror AWS Lambda capabilities.

🔲 Epic 4: Core Infrastructure Services

  🔲 Feature 4.1: Longhorn Distributed Storage

      - Implement persistent, replicated block storage.

  🔲 Feature 4.2: Ingress & cert-manager

      - Implement automated SSL/TLS and HTTP routing.

🔲 Epic 5: Observability & Security Posture

  🔲 Feature 5.1: LGTM Stack Deployment

      - Implement the Loki, Grafana, Tempo, and Mimir stack for instrumentation and observability.

  🔲 Feature 5.2: Network Policies

      - Implement network control policies that support realistic best practices.

  🔲 Feature 5.3: Disaster Recovery via Velero

      - Automate backups to an external location.

🔲 Epic 6+: Future Analytic Layers (Summary)  

  🔲 Data Layer: CloudNativePG for highly available Postgres.  

  🔲 IDE Layer: RStudio and VSCode as Kubernetes-native deployments.  

  🔲 MLOps: KubeFlow staging for analytic workflows.  

```

</details>

# Tools

Since my first attempt at a home lab, Generative AI has emerged and become ubiquitous within the software and analytic development space. To that end, I am approaching this project with the help of Google's Gemini and Anthropic's Claude LLMs. Gemini is my main partner, and accounts for 95% of the contribution.

I developed a custom AI expert Senior Platform Engineer that is experienced with Agile DevOps, GitOps, Kubernetes, and Software Systems Engineering as a Gemini Gem. 

During Epics 0 - 2, I interacted with Gemini through the web app. I found this useful until the codebase grew and managing state became more difficult. I have since started using [Google's Antigravity IDE](https://antigravity.google/) to handle Gemini integration, which has been a significant improvement for code understanding and context management. 

The Gemini Agent's instructions are recorded in the file [.agents/rules/gitops-lab-architect.md](.agents/rules/gitops-lab-architect.md)  

I've also developed specific prompts to assist with Agile Project Management processes like feature planning and retrospectives. These are located in the [.agents/workflows](/.agents/workflows) directory. 

# What is Next

The markdowns and supporting documents in the `./docs` directory document the actual development effort of this project and the architecture I decided on.

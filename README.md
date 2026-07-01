# Purpose  

I developed my first homelab Kubernetes cluster in 2021 - 2022, but it fell into disrepair when we moved in 2022. This is my updated work on the project and is intended to be a much more robust and deliberate effort. 

This project establishes an enterprise-grade, bare-metal Kubernetes analytics platform—the "Expandable Enclave"—designed for high-fidelity Operations Research and systems engineering workloads using a strictly FOSS, GitOps-driven architecture. Built upon a heterogeneous hardware footprint of HP, Lenovo, and Dell nodes, the environment leverages Talos Linux for immutable, API-driven operations and Cilium for eBPF-powered zero-trust networking, ensuring a resilient foundation for distributed data layers like CloudNativePG and Longhorn. Central to this effort is the collaborative integration with Gemini (operating as the "GitOps Lab Architect"), serving as a senior technical peer to translate architectural intent into declarative manifests and structured backlogs. For a comprehensive exploration of the engineering trade-offs and logical schematics, refer to the detailed **Architectural Decision Records (ADRs)** and system models located in the `docs/adr` and `docs/architecture` directories.

The Source of Truth for this Project is located in GitLab as a private repository here: https://gitlab.com/nkester-personal-cloud/homelab 

It's protected branches are mirrored to my public GitHub repository here: https://github.com/nkester/homelab

Below is the folder structure for the project:

```text
/
├── apps/                   # The "Workload" layer
│   ├── analytics/          # RStudio, VSCode, KubeFlow manifests
│   └── database/           # CloudNativePG configurations
├── argocd/                 # The "Controller" layer (App-of-Apps manifests)
├── docs/                   # The "Commentary" layer
│   ├── adr/                # Architectural Decision Records (The "Why")
│   ├── architecture/       # Mermaid/Python diagrams and technical deep-dives
│   └── logs/               # Chronological project logs and epic summaries
├── .gitlab/                # CI/CD pipelines (for linting and validation)
├── infrastructure/         # The "Platform" layer (Cluster-wide services)
│   ├── bootstrap/          # Talos machine configs (templates)
│   ├── networking/         # Cilium and Ingress manifests
│   └── storage/            # Longhorn configuration
└── scripts/                # Helper scripts for talosctl or maintenance
```

# Tools

Since my first attempt at a home lab, Generative AI has emerged and become ubiquitous within the software and analytic development space. To that end, I am approaching this project with the help of Google's Gemini and Anthropic's Claude LLMs. Gemini is my main partner, and account for 95% of the contribution.

I developed a custom AI expert Senior Platform Engineer that is experienced with Agile DevOps, GitOps, Kubernetes, and Software Systems Engineering as a Gemini Gem. 

Below are the instructions I used to seed this GEM:  

```markdown
**Role & Persona**

You are a Senior Platform Engineer, Kubernetes Architect, and Agile DevOps Coach. Your sole purpose is to assist the user in designing, deploying, and managing a highly resilient, secure, and scalable bare-metal Kubernetes home lab.



**Target User Persona**

The user is a highly experienced Operations Research Systems Analyst (ORSA) with a strong background in Systems Engineering. They already possess a good understanding of Kubernetes, Helm, databases, and GitLab. They prefer deeply structured, robust, and enterprise-grade solutions over "quick-and-dirty" hobbyist hacks. Treat them as a senior technical peer.



**Project Context & Architecture**

The user is building an operations research analytics platform on bare-metal hardware. The cluster is designed for future scalability but currently consists of three physical computers (1 Control Node, 2 Worker Nodes).



**The Tech Stack (Strictly FOSS):**

* **Source of Truth:** GitLab
* **Operating System:** Talos Linux (Immutable)
* **Control Plane HA:** kube-vip
* **CNI & Security:** Cilium (eBPF, default-deny Zero-Trust)
* **GitOps Engine:** ArgoCD
* **Secret Management:** External Secrets Operator (or Sealed Secrets)
* **Distributed Storage:** Longhorn
* **Ingress & TLS:** NGINX Ingress Controller & cert-manager
* **Observability:** Prometheus, Grafana, Promtail, Loki
* **Disaster Recovery:** Velero
* **Data Layer:** CloudNativePG (PostgreSQL)
* **Analytic Workloads:** VSCode server, RStudio, KubeFlow



**Core Operating Principles**

* **FOSS Only:** Never recommend paid, enterprise-licensed, or proprietary software.

* **GitOps & Declarative First:** Never recommend manual `kubectl apply` commands for persistent state. All configurations, deployments, and infrastructure must be managed declaratively via YAML/Helm/Kustomize, stored in GitLab, and synced via ArgoCD.

* **Immutability:** Acknowledge that the OS (Talos) is immutable and API-driven. Do not provide instructions involving SSH, `apt-get`, or traditional package managers for the host nodes.

* **Resilience & Security:** Always design for hardware failure. Ensure storage has replication, the API server utilizes a VIP, and network policies isolate namespaces.

* **Agile Methodology:** When tackling a new component, break the work down into logical Epics and Features. Guide the user through testing and verifying one component before moving to the next.  

* **Sequential Execution:** You are prohibited from providing technical implementation steps for a new Feature or Epic until the user has explicitly confirmed the preceding item meets its DoD and is marked "Done" in the Roadmap.



**Interaction Style**

* **Omit Affirmations:** Do not use conversational filler, pleasantries, or affirmations. Deliver direct, precise, and objective technical responses.

* **State of the Art & Best Practices:** Always baseline recommendations against current industry state-of-the-art standards.

* **Direct Pushback:** If the user suggests an approach that deviates from GitOps principles or systems engineering best practices, identify the flaw, push back directly, and provide the optimal alternative.  

* **Two-Option Rule:** Path of Least Resistance: For high-risk infrastructure or networking changes (e.g., VLAN tagging, subnet shifts), always provide two options: Option A (Ideal) for enterprise-standard implementation, and Option B (High-Compatibility) as a fallback for hardware/firmware constraints.

* **Actionable Code:** Provide clear, heavily commented YAML manifests and Helm `values.yaml` snippets.

* **Anticipate Dependencies:** Identify prerequisites before providing next steps.

* **Professional Terminology:** Use strict systems engineering terminology (e.g., fault domains, quorum, lifecycle management).



**Grounding & State Management**

* **Authoritative Source of Truth:** Always prioritize the "HomeLab Project Roadmap" Google Sheet for project status, numbering, priority, and "Definition of Done" (DoD).

* **Mandatory Status Verification:** Before starting any technical task, you MUST check the roadmap to verify that the parent Epic and the specific Feature are marked as "In Progress."

* **Audit-Before-Write (ABW):** Before generating new manifests, ADRs, or documentation, you must explicitly state which existing files in the /docs or /infrastructure directories you have reviewed to ensure consistency and prevent configuration drift.

* **Discrepancy Reporting:** If the user asks for a task that contradicts the roadmap's current state, highlight the discrepancy and ask for reconciliation before providing technical steps.

* **Contextual Awareness:** Use the "Description" field in the roadmap to ensure technical advice aligns with pre-defined architectural goals.



**Deliberate Execution & Gatekeeping**

* **Stop-and-Check Protocol:** Never assume a task is complete. After providing technical steps, you must stop and ask the user to verify output against the DoD.

* **Conditional Completion:** A feature/epic is only "Done" once the user explicitly confirms all DoD criteria are met.

* **Mandatory "Ready for Next" Prompt:** At the end of a successful task, ask: "Do these results meet the DoD? Are we ready to move to the next item on the roadmap, or do we need to refine this configuration?"

* **Mandatory Validation block:** Every technical solution must conclude with a "Validation" section providing exact commands (e.g., `kubectl`, `ping`, `curl`, `talosctl`) required to verify the output against the Definition of Done (DoD). 

* **Feature Conclusion:** Once validated as complete, prompt for documentation efforts and a retrospective. Reference the "Home Lab Retrospective" table before starting new features.

* **Feature Planning:** Upon moving to a new feature, prompt the user to plan tasks so both are in alignment before execution.  

* **Hardware/Firmware Audit:** For any task involving the physical network (ER605, Orbi) or node configuration, you must proactively request hardware/firmware versions to identify vendor-specific "guardrails" before proposing changes.



**Educational Modalities**

* **Training Module:** Deliver a highly structured technical briefing on architectural necessity, failure domains, and implementation strategy.

* **Podcast Script / Voice Primer:** Format for auditory consumption via voice mode. Adopt a senior architect persona explaining engineering trade-offs and operational realities.



**Knowledge Access:**

- HomeLab Project Roadmap (Google Sheet)
- Hardware and Storage Inventory (Google Sheet)
- Home Lab Retrospective (Google Sheet)
- Repository: https://github.com/nkester/homelab (Focus: Homelab and Epic branches)

```

Additionally, I gave the GEM knowledge of a Google Doc with the hardware specifications I am using, a Google Sheet with the Project Roadmap and status, and a Google Sheet Retrospective. Finally, I gave it the skill to look at my public GitHub repository for this project. 

# The Plan

In conjunction with the Gemini GEM described above, I developed an initial project plan to guide my development and give the GEM an understanding of the approach. The epic and feature list and the status of each effort are listed below. I will update these as they evolve.

As the project progresses, I will create a tag for each Epic as it is merged into the `Homelab 2026` branch so we can step back in time.

## 🗺️ High Level Project Roadmap

Legend:  
✅ Complete: Tested, verified, and merged.  🔵 In Progress: Current active development.
🔲 Backlog: Planned feature set.

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
  

🔵 Epic 1: Hardware & Network Foundation  

  ✅ Feature 1.1: Logical Network Segmentation (VLAN 10)  
      
      - Isolating the analytic enclave on the ER605 and defining inter-VLAN routing.  

  ✅ Feature 1.2: Wireless Enclave Standoff  
  
      - Validating the Orbi mesh backhaul as a stable bridge for the remote compute nodes.  

  🔵 Feature 1.3: Scalable IP & DNS Schema  
  
      - Defining static reservations and DNS forwarders for cluster services.  
      
  🔲 Feature 1.4: API Server VIP (kube-vip)  
  
      - Implementing a Virtual IP for Kubernetes control plane high availability.  

🔲 Epic 2: Kubernetes Bootstrap (Talos OS)  

  🔲 Feature 2.1: Node Preparation  
  
      - Generating declarative Talos OS images for the mixed-hardware nodes.  

  🔲 Feature 2.2: Cluster Provisioning  
  
      - Initializing the control plane and joining worker nodes via OpenTofu as declarative GitOps.  

  🔲 Feature 2.3: Cilium CNI Deployment  
  
      - Implementing eBPF-based networking for performance and security.  

🔲 Epic 3: GitOps & Shared Services  

  🔲 Feature 3.1: ArgoCD and Argo Workflows Deployment  
  
      - Bootstrapping the "App-of-Apps" pattern to automate all deployments through Directed Acyclic Graphs and GitLab CI.  

  🔲 Feature 3.2: CNI & Storage Integration

      - Finalize network policies and distributed storage for apps.
  
  🔲 Feature 3.3: External Secret Management (ESO)  
  
      - Integrating External Secrets Operator to securely pull credentials from GitLab.  

  🔲 Feature 3.4: Object Storage Foundation (MiniO)  
  
      - Provide S3 API functionality to support data pipelines and backups.  

  🔲 Feature 3.5: Serverless Execution through Knative

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



# What is Next

The markdowns and supporting documents in the `./docs` directory document the actual development effort of this project and the architecture I decided on.
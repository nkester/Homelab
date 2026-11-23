# Blueprint: Talos Linux Provisioning & Immutable OS Architecture

## 1. Abstract
This document defines the Layer II provisioning standard and operating system architecture for the GitOps Lab. It establishes Talos Linux as an immutable, API-driven control plane and worker plane runtime, stripping away traditional shell access in favor of declarative machine configurations enforced via OpenTofu and managed through `talosctl`.

## 2. Logical Design
Talos Linux runs entirely from an ephemeral initramfs with root filesystem integrity maintained cryptographically. Configuration state is expressed declaratively via YAML manifests and applied over mTLS. 

### Architecture Model

```mermaid
graph TD
    subgraph GitOps Pipeline
        GitLab[GitLab Source of Truth] -->|OpenTofu Apply| Tofu[OpenTofu Engine]
    end

    subgraph Cluster Provisioning
        Tofu -->|mTLS API :50000| CP[Control Plane: HP 6300 SFF]
        Tofu -->|mTLS API :50000| W1[Worker 1: HP Pavilion 590]
        Tofu -->|mTLS API :50000| W2[Worker 2: Lenovo 310S]
    end

    subgraph Immutable OS Runtime
        CP & W1 & W2 -->|Kernel Extensions| Ext[iscsi-tools / util-linux-tools / realtek-firmware]
		CP & W1 & W2 -->|eBPF Datapath| Cilium[Cilium CNI / kube-proxy replacement]
    end
```

## 3. Implementation & System Extensions

To support heterogeneous bare-metal hardware and satisfy downstream storage primitives (Longhorn), custom image schematics are compiled via the Sidero Image Factory (`factory.talos.dev`).

### Image Schematic Mapping
* **Control Plane (`controlplane-1` — HP Compaq Pro 6300 SFF, 20GB RAM, 256GB SSD + 931.5GB HDD):**
  * Image Hash: `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245`
  * Extensions: `siderolabs/iscsi-tools`, `siderolabs/util-linux-tools`
* **Worker Nodes (`worker-1` — HP Pavilion 590-p0xxx [12GB RAM, Dual 931.5GB HDDs] & `worker-2` — Lenovo ideacenter 310S [8GB RAM, 465.8GB HDD]):**
  * Image Hash: `71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09`
  * Extensions: `siderolabs/realtek-firmware`, `siderolabs/iscsi-tools`, `siderolabs/util-linux-tools`

## 4. Failure Domains & Resilience

* **API Server & Control Plane SPOF:** The cluster relies on a single control plane node (HP Compaq Pro 6300 at `10.10.10.51`) backed by Talos Native L2 VIP (`10.10.10.10`). Loss of this node halts the Kubernetes API (`6443`), though local container runtimes on workers may continue running temporarily.
* **Storage Isolation:** Persistent workloads leverage dedicated SATA drives across the nodes (`256GB SSD + 931.5GB HDD` on `controlplane-1`, `Dual 931.5GB HDDs` on `worker-1`, and `465.8GB HDD` on `worker-2`) backed by the injected `iscsi-tools` extension.

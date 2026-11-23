# Infrastructure & IP Address Management (IPAM)

## 1. Local DNS Schema
* **Internal Kubernetes Traffic:** `cluster.local` 
* **Ingress / External Access:** `kester.lab`
* **Upstream Forwarders:** `1.1.1.1` (Cloudflare) / `8.8.8.8` (Google)

## 2. IP Allocation: Analytic Enclave (VLAN 10)
**Subnet:** `10.10.10.0/24` | **Gateway:** `10.10.10.1`

### 2.1 Infrastructure Block
| Hostname | Role | IP Address | MAC Address | Allocation |
| :--- | :--- | :--- | :--- | :--- |
| **ER605** | Gateway | `10.10.10.1` | N/A | Static |
| **RBR50** | Orbi Base | `10.10.10.3` | [Logged in Router] | Static |
| **RBS50** | Orbi Satellite| `10.10.10.4` | [Logged in Router] | Static |
| **TL-SG108E** | Switch | `10.10.10.5` | [Logged in Router] | Static |

### 2.2 Kubernetes Bare-Metal Compute Block
| Hostname | Role | Hardware Model | IP Address | MAC Address | Allocation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **controlplane-1** | Talos Control Plane | HP Compaq Pro 6300 SFF (20GB RAM, 256GB SSD + 931.5GB HDD) | `10.10.10.51` | `A0-48-1C-98-4E-E3` | Static (OS) / DHCP Reservation |
| **worker-1** | Talos Worker 01 | HP Pavilion 590-p0xxx (12GB RAM, Dual 931.5GB HDDs) | `10.10.10.52` | `F4-39-09-33-DC-F9` | Static (OS) / DHCP Reservation |
| **worker-2** | Talos Worker 02 | Lenovo ideacenter 310S-08IAP (8GB RAM, 465.8GB HDD) | `10.10.10.53` | `6C-4B-90-45-42-16` | Static (OS) / DHCP Reservation |

### 2.3 Kubernetes Virtual IP (VIP) & Routing Blocks
| Service | Purpose | IP / Range | Manager |
| :--- | :--- | :--- | :--- |
| **API Server VIP** | HA Control Plane | `10.10.10.10` | Talos Native L2 VIP |
| **Kourier Gateway** | Knative Serverless Ingress | `10.10.10.17` | Cilium LB IPAM + L2 |
| **NGINX Ingress** | Primary North-South Ingress | `10.10.10.18` | Cilium LB IPAM + L2 |
| **LB Pool** | Shared LoadBalancer Pool | `10.10.10.17 - 10.10.10.25` | Cilium LB IPAM |

### 2.4 CNI & Pod Networking Block
| Service | Purpose | IP / Range | Manager |
| :--- | :--- | :--- | :--- |
| **Pod CIDR** | eBPF Native Routing Range | `10.244.0.0/16` | Cilium IPAM |
| **Hubble Relay** | Flow Telemetry Service | Port `4245/TCP` | Helm / OpenTofu |
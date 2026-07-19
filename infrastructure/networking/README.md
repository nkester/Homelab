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
| Hostname | Role | IP Address | MAC Address | Allocation |
| :--- | :--- | :--- | :--- | :--- |
| **HP-Control** | Talos Control Plane | `10.10.10.51` | `A0-48-1C-98-4E-E3` | Static (OS) / Dummy DHCP |
| **W01-Lenovo** | Talos Worker 01 | `10.10.10.52` | `6C-4B-90-45-42-16` | Static (OS) / Dummy DHCP |
| **W02-Dell** | Talos Worker 02 | `10.10.10.53` | `EC-F4-BB-7A-E1-0E` | Static (OS) / Dummy DHCP |

### 2.3 Kubernetes Virtual IP (VIP) & Routing Blocks
| Service | Purpose | IP / Range | Manager |
| :--- | :--- | :--- | :--- |
| **API Server VIP** | HA Control Plane | `10.10.10.100` | `kube-vip` |
| **DNS / Ingress** | Primary `kester.lab` entry | `10.10.10.101` | Cilium L2 |
| **LB Pool** | Additional Ingress Services | `10.10.10.102 - .120` | Cilium IPAM |
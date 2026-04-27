# Blueprint: Physical Network & L1 Topology

## 1. Abstract
This document defines the physical cabling and Layer 2 connectivity for the GitOps Lab. It establishes the "Analytic Enclave" and the management zone, ensuring that the ER605 remains the authoritative gateway for the 192.168.1.x subnet.

## 2. Logical Design
The network is structured to bypass ISP firmware limitations by placing the Verizon CR1000A in a bridge/passthrough capacity, allowing the ER605 to handle primary routing and DHCP for the cluster.

### Topology Diagram
```mermaid
graph TD
    subgraph "Public Internet"
        ONT[Verizon ONT]
    end

    subgraph "Management & Personal Zone (VLAN 1)"
        ER605[ER605 Gateway <br/> 192.168.1.1]
        CR1000A[CR1000A Bridge <br/> 192.168.1.2]
        PersonalWiFi[Personal Devices <br/> DHCP: .1.5 - .254]
    end

    subgraph "Analytic Enclave (VLAN 10 - Pending)"
        RBR50[Orbi RBR50 Base <br/> 192.168.1.3]
        Satellite[Orbi Satellite <br/> 192.168.1.4]
        Nodes[Analytic Nodes <br/> HP/Lenovo/Dell]
    end

    ONT -->|Ethernet - Port 1| ER605
    ER605 -->|Ethernet - Port 2| CR1000A
    ER605 -->|Ethernet - Port 3| RBR50
    CR1000A -->|MoCA / Coax| TV[Set Top Boxes]
    RBR50 -.->|Wireless Backhaul| Satellite
    Satellite -->|Ethernet| Nodes

    ```

## 3. Implementation Details  

  * Primary Gateway: ER605 (192.168.1.1)  
  * IPAM Strategy:  
    * Static assignments for infrastructure (.1 through .4).  
    * DHCP pool for transient personal devices (.5 through .254).  
  * Subnet Pivot: Documented in ADR-0001.

## 4. Resilience & Failure Domains  

  * Single Point of Failure: The ER605 is the primary SPOF for external connectivity.  
  * Recovery: Cold spare ER605 or temporary fallback to CR1000A (requires DHCP reconfiguration).
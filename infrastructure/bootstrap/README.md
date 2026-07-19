# Purpose: Talos machine configs (templates)

## Talos OS Bootstrap Requirements

### 1. Control Plane High Availability (kube-vip)
To ensure the Kubernetes API remains accessible during node maintenance or failure, `kube-vip` will be bound to the control plane node via Layer 2 ARP.

* **Target IP:** `10.10.10.100` (Reserved in ER605)
* **Protocol:** Layer 2 ARP
* **OpenTofu MachineConfig Snippet Requirement:**
  ```yaml
  machine:
    network:
      interfaces:
        - interface: eth0 # Must verify actual interface name (e.g., eno1) during TF plan
          vip:
            ip: 10.10.10.100
  ```
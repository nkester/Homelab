# Purpose: Talos machine configs (templates)

## Talos OS Bootstrap Requirements

### Architecture & State Management
This module utilizes OpenTofu to generate deterministic cryptographic material, machine secrets, and YAML configuration patches for the immutable Talos Linux nodes. 
* **Provider:** `siderolabs/talos` locked to `v0.12.0-alpha.5`.
* **State:** Local `terraform.tfstate`. **CRITICAL:** State files contain plaintext cryptographic root-of-trust material and are strictly excluded from version control via `.gitignore`.

### Hardware Configuration Exceptions
Talos implicit network configurations are overridden via `config_patches` to ensure high-availability routing and stable DHCP leases.
* **Control Node (HP Compaq Pro 6300 SFF):** The Intel 82579LM Gigabit Network Connection requires explicit binding to `eno1`. The Layer 2 VIP (`10.10.10.10`) is attached to this interface. 
* **Explicit TALOS Linux Version:** Through the `config_patches` block, we explicitly tell TALOS where to install the OS and which version to use. This was important because without this, the Open Tofu `siderolabs/talos` provider defaulted to installing the latest alpha version of the OS. This caused networking issues so we opted to use the latest stable deployment. The required manifest items are:
   ```yaml
   install = {
          disk = "/dev/sda"
          image = "ghcr.io/siderolabs/installer:v1.13.7"
        }
   ```
* **Establishing Kube-VIP:** To attach the Layer 2 VIP to the control plane's network interface, we added the `vip = {ip = "10.10.10.10"}` within the network portion of the `config_patches` block.  
  * See ADR-0003 for more information on this decision to use the Talos native layer 2 VIP.

### Execution SOP
To provision a node or rebuild the cluster from a bare-metal state:

1. **Initialize Workspace:**
   `tofu init`
2. **Apply Configuration State:**
   `tofu apply`
3. **Extract Talos Client Configuration:**
   `tofu output -raw talosconfig > ~/.talos/config`
   `chmod 600 ~/.talos/config`
   `export TALOSCONFIG=~/.talos/config`
4. **Extract Kubernetes Credentials (Post-Bootstrap):**
   `talosctl --nodes 10.10.10.51 kubeconfig ~/.kube/config`
   `chmod 600 ~/.kube/config`
5. **Check Nodes on the Cluster:**
   `kubectl get nodes -o wide`


## Known Limitations & Operational Guardrails

### 1. Bare-Metal Reprovisioning and Disk Mappings
Executing a node reset (`talosctl reset`) clears the `STATE` and `EPHEMERAL` partitions. However, rebooting physical bare-metal nodes (specifically the Lenovo and Dell worker nodes) can result in the kernel re-enumerating the block storage devices (e.g., shifting the primary installation drive from `/dev/sdc` to `/dev/sdb`). 

If the drive mapping shifts during a remote reset, the node will fail to initialize the Talos OS correctly and will not enter Maintenance Mode over the network. 
*   **Resolution:** This requires a physical failover. You must attach a monitor, insert the Talos bootable USB, and manually boot the machine back into Maintenance Mode, query the node with `talosctl get links --nodes <Node IP> --insecure`, update the `main.tf` manifest with the new mount, and apply to allow OpenTofu to push the configuration to the newly enumerated block device.

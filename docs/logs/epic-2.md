# Epic 2: Kubernetes Bootstrap (Talos OS) - Engineering Log

## Overview
Deployment of the Talos Linux immutable operating system and initialization of the Kubernetes API across bare-metal nodes via OpenTofu.

## Key Technical Decisions & Discoveries

* **Talos Image Generation:** 
  To support the heterogeneous bare-metal hardware (HP and Lenovo), custom ISOs were generated via the [Sidero Image Factory](https://factory.talos.dev/). 
  * Required Extensions: `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` (Mandatory for downstream Longhorn distributed storage primitives).
  * Lenovo and Dell Specifics: `siderolabs/realtek-firmware` was required to ensure Layer 2 stability for the RTL8111/8168 controller.

* **Pre-Flight Hardware Interrogation (mTLS Bypass):**
  Prior to applying the declarative `main.tf` machine configuration, nodes booting into Maintenance Mode lack the cluster's PKI material. Discovering exact logical interfaces and disk endpoints requires bypassing mTLS:
  `talosctl get links --nodes <IP> --insecure`
  `talosctl get disks --nodes <IP> --insecure`

* **Hardware Constraints (Lenovo ideacenter 310S):**
  * The internal Intel Dual Band Wireless-AC 3165 introduces severe `talos-networkd` race conditions. It must be explicitly disabled in the UEFI/BIOS prior to OS installation.
  * The primary HDD enumerates atypically as `/dev/sdc` due to the onboard MicroSD/M2 reader capturing `/dev/sdb`. 
  * The Realtek NIC maps to `enp2s0` rather than standard `eth0`.
  
* **Explicit Talos Image Install:**
  * To ensure the proper machine image was installed via Open Tofu rather than via command line, I used the following two images. 
    * Control Node (HP): `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245`
    * Worker Nodes (Lenovo & HP): `71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09`
  * These are included in the Tofu manifest to ensure explicit reproduce-ability. The `iscsi-tools` and `util-linux-tools` are required for LongHorn in Epic 3. `realtek-firmware` is required for the network device. Below are the specifications for the Sidero Image Factory. 
    * Control (HP): bare-metal, Talos version 1.13.7, amd64, extensions: [siderolabs/iscsi-tools, siderolabs/util-linux-tools], UEFI only bootloader
    * Workers (Lenovo & Dell): bare-metal, Talos version 1.13.7, amd64, extensions: [siderolabs/realtek-firmware, siderolabs/iscsi-tools, siderolabs/util-linux-tools], UEFI only bootloader
  * **Checking Extensions.** To ensure all required extensions exist, apply the `talosctl get extensions` command:
    * Control Node:
| NODE | NAMESPACE | TYPE | ID | VERSION | NAME | VERSION |
|---|---|---|---|---|---|---|
| 10.10.10.51 | runtime | ExtensionStatus | 0 | 1 | iscsi-tools | v0.2.0 |
| 10.10.10.51 | runtime | ExtensionStatus | 1 | 1 | util-linux-tools | 2.42.2 |
| 10.10.10.51 | runtime | ExtensionStatus | 2 | 1 | schematic | d30235af7822d8ab9218631278e8cf545cdccb30650607f2211e4f670489587f |  
    * Worker 1 Node (Lenovo):
| NODE | NAMESPACE | TYPE | ID | VERSION | NAME | VERSION |
|---|---|---|---|---|---|---|
| 10.10.10.52 | runtime | ExtensionStatus | 0 | 1 | iscsi-tools | v0.2.0 |
| 10.10.10.52 | runtime | ExtensionStatus | 1 | 1 | realtek-firmware | 20260622 |
| 10.10.10.52 | runtime | ExtensionStatus | 2 | 1 | util-linux-tools | 2.42.2 |
| 10.10.10.52 | runtime | ExtensionStatus | 3 | 1 | schematic | b3be65417e75019263b7b4c7831117653b737af5fb6d27f136b562b28cfa3cbb |  
    * Worker 2 Node (DELL):
| NODE | NAMESPACE | TYPE | ID | VERSION | NAME | VERSION |
|---|---|---|---|---|---|---|
| 10.10.10.53 | runtime | ExtensionStatus | 0 | 1 | iscsi-tools | v0.2.0 |
| 10.10.10.53 | runtime | ExtensionStatus | 1 | 1 | realtek-firmware | 20260622 |
| 10.10.10.53 | runtime | ExtensionStatus | 2 | 1 | util-linux-tools | 2.42.2 |
| 10.10.10.53 | runtime | ExtensionStatus | 3 | 1 | schematic | 71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09 |

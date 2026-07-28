# Epic 2: Kubernetes Bootstrap (Talos OS) - Engineering Log

## Overview
Deployment of the Talos Linux immutable operating system and initialization of the Kubernetes API across bare-metal nodes via OpenTofu.

## Key Technical Decisions & Discoveries

* **Talos Image Generation:** 
  To support the heterogeneous bare-metal hardware (HP and Lenovo), custom ISOs were generated via the [Sidero Image Factory](https://factory.talos.dev/). 
  * Required Extensions: `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` (Mandatory for downstream Longhorn distributed storage primitives).
  * Lenovo Specifics: `siderolabs/realtek-firmware` was required to ensure Layer 2 stability for the RTL8111/8168 controller.

* **Pre-Flight Hardware Interrogation (mTLS Bypass):**
  Prior to applying the declarative `main.tf` machine configuration, nodes booting into Maintenance Mode lack the cluster's PKI material. Discovering exact logical interfaces and disk endpoints requires bypassing mTLS:
  `talosctl get links --nodes <IP> --insecure`
  `talosctl get disks --nodes <IP> --insecure`

* **Hardware Constraints (Lenovo ideacenter 310S):**
  * The internal Intel Dual Band Wireless-AC 3165 introduces severe `talos-networkd` race conditions. It must be explicitly disabled in the UEFI/BIOS prior to OS installation.
  * The primary HDD enumerates atypically as `/dev/sdc` due to the onboard MicroSD/M2 reader capturing `/dev/sdb`. 
  * The Realtek NIC maps to `enp2s0` rather than standard `eth0`.
  
* **Checking the Hardware State After Bootstrapping:**
  * After bootstrapping the control node and worker 1 (Lenovo), I wanted to ensure we had all required extensions in the Talos Linux OS required for future work. Running `talosctl get extensions --nodes 10.10.10.51` returned an empty response, indicating the original install failed to include the `iscsi-tools` and `util-linux-tools` we will require for LongHorn in Epic 3. 
    * To address this, I went back to the [Talos Image Factory](https://factory.talos.dev/), built the image again. Below are the specifications for the control and worker (lenovo) nodes: 
      * Control (HP): bare-metal, Talos version 1.13.7, amd64, extensions: [siderolabs/iscsi-tools, siderolabs/util-linux-tools], UEFI only bootloader
      * Worker 1 (Lenovo): bare-metal, Talos version 1.13.7, amd64, extensions: [siderolabs/realtek-firmware, siderolabs/iscsi-tools, siderolabs/util-linux-tools], UEFI only bootloader
    * To install each, take the URL from about halfway down the final Talos Linux Image Factory page under the heading **Upgrading Talos Linux** and run these commands:
      * Control Node (HP): `talos upgrade --nodes 10.10.10.51 --image <url from Talos image factory>`
      * Worker 1 (Lenovo): `talos upgrade --nodes 10.10.10.52 --image <url from Talos image factory>`
  * **Checking Extensions.** After applying this upgrade to both, I got the following responses from the `talos get extensions` command:
    * Control Node:
| NODE | NAMESPACE | TYPE | ID | VERSION | NAME | VERSION |
|---|---|---|---|---|---|---|
| 10.10.10.51 | runtime | ExtensionStatus | 0 | 1 | iscsi-tools | v0.2.0 |
| 10.10.10.51 | runtime | ExtensionStatus | 1 | 1 | util-linux-tools | 2.42.2 |
| 10.10.10.51 | runtime | ExtensionStatus | 2 | 1 | schematic | d30235af7822d8ab9218631278e8cf545cdccb30650607f2211e4f670489587f |  
    * Worker 1 Node:
| NODE | NAMESPACE | TYPE | ID | VERSION | NAME | VERSION |
|---|---|---|---|---|---|---|
| 10.10.10.52 | runtime | ExtensionStatus | 0 | 1 | iscsi-tools | v0.2.0 |
| 10.10.10.52 | runtime | ExtensionStatus | 1 | 1 | realtek-firmware | 20260622 |
| 10.10.10.52 | runtime | ExtensionStatus | 2 | 1 | util-linux-tools | 2.42.2 |
| 10.10.10.52 | runtime | ExtensionStatus | 3 | 1 | schematic | b3be65417e75019263b7b4c7831117653b737af5fb6d27f136b562b28cfa3cbb |

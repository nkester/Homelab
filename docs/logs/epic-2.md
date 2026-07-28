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

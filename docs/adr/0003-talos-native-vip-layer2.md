# ADR-0003: Talos Native Layer 2 VIP & Interface Binding

* **Status:** Accepted
* **Date:** 2026-07-26
* **Author:** Neil Kester

## 1. Context
The operations research platform requires a highly available Kubernetes API endpoint to prevent single points of failure during control plane scaling or node maintenance. Standard GitOps practices often deploy `kube-vip` as a DaemonSet or static pod to manage the cluster endpoint. However, the underlying OS (Talos Linux) provides a native, integrated Layer 2 VIP controller. Furthermore, implicit network configuration failed to bind the VIP to the physical hardware during initial bootstrapping.

## 2. Decision
1. We will utilize the native Talos Layer 2 VIP configuration embedded directly within the immutable machine configuration (`config_patches`), deprecating the need for a separate `kube-vip` deployment.
2. We will explicitly define the physical network interface mapping in the machine configuration to ensure the VIP controller correctly binds to the hardware. For the HP Compaq Pro 6300 Control Node, the Intel 82579LM Gigabit Network Connection is bound to `eno1`.
3. DHCP will be explicitly enabled on the targeted interface alongside the VIP declaration to prevent the kernel from stripping routing tables during configuration application.

## 3. Consequences
*   **Positive:** Reduces control plane complexity by removing a critical third-party networking dependency (`kube-vip`).
*   **Positive:** Failover and Gratuitous ARP (GARP) are handled directly by the OS, accelerating recovery times.
*   **Negative:** Hardcoding the physical interface (`eno1`) into the `main.tf` creates a hardware-specific dependency. Replacing the HP Control Node or adding heterogeneous control plane nodes will require specific OpenTofu patch overrides for differing NIC naming conventions.

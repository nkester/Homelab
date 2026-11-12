# ==============================================================================
# Feature 3.4-R: Iterative Node Provisioning Configuration (terraform.tfvars)
# ==============================================================================

cluster_name  = "homelab-cluster"
talos_version = "v1.13.7"
cluster_vip   = "10.10.10.10"
gateway_ip    = "10.10.10.1"
node_subnet   = "10.10.10.0/24"

# ------------------------------------------------------------------------------
# Step 3.1: Control Plane Node (HP Compaq Pro 6300 SFF - 20GB RAM)
# Primary OS/etcd Disk: /dev/sda (256GB SSD)
# Secondary Data Disk:  /dev/sdb (931.5GB 2.5" HDD mounted at /var/mnt/longhorn-extra)
# ------------------------------------------------------------------------------
control_plane = {
  hostname             = "controlplane-1"
  ip                   = "10.10.10.51"
  interface            = "eno1"
  install_disk         = "/dev/sda"
  installer_image      = "factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.13.7"
  allow_scheduling     = true
  mount_secondary_disk = true
}

# ------------------------------------------------------------------------------
# Steps 3.2 & 3.3: Worker Nodes (Iterative Provisioning)
# - For Step 3.1 (Control Plane only): leave worker_nodes = {} empty.
# - For Step 3.2 (Worker 1 - HP Pavilion 590-p0xxx): uncomment "worker-1".
# - For Step 3.3 (Worker 2 - Lenovo ideacenter 310S): uncomment "worker-2".
# ------------------------------------------------------------------------------
worker_nodes = {
  # Uncomment for Step 3.2 after booting HP Pavilion 590-p0xxx into Maintenance Mode:
  # "worker-1" = {
  #   ip                   = "10.10.10.52"
  #   interface            = "enp2s0"
  #   install_disk         = "/dev/sda"
  #   installer_image      = "factory.talos.dev/metal-installer/71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7"
  #   mount_secondary_disk = true
  # }

  # Uncomment for Step 3.3 after booting Lenovo ideacenter 310S into Maintenance Mode:
  # "worker-2" = {
  #   ip                   = "10.10.10.53"
  #   interface            = "enp2s0"
  #   install_disk         = "/dev/sdb"
  #   installer_image      = "factory.talos.dev/metal-installer/71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7"
  #   mount_secondary_disk = false
  # }
}

# ------------------------------------------------------------------------------
# Phase 4: Declarative ArgoCD & App-of-Apps Bootstrap
# Keep false during Phase 3 node staging; set to true in Phase 4 once all 3 nodes
# are running in their final enclave positions on the TL-SG108E switch.
# ------------------------------------------------------------------------------
enable_argocd_bootstrap = false

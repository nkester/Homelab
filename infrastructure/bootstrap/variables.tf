variable "cluster_name" {
  description = "Name of the Talos Kubernetes cluster"
  type        = string
  default     = "homelab-cluster"
}

variable "talos_version" {
  description = "Target Talos Linux version"
  type        = string
  default     = "v1.13.7"
}

variable "cluster_vip" {
  description = "Talos native Layer 2 Virtual IP for the Kubernetes API server"
  type        = string
  default     = "10.10.10.10"
}

variable "gateway_ip" {
  description = "Default gateway IP for VLAN 10 (Analytic Enclave)"
  type        = string
  default     = "10.10.10.1"
}

variable "node_subnet" {
  description = "CIDR subnet for VLAN 10 nodes"
  type        = string
  default     = "10.10.10.0/24"
}

variable "control_plane" {
  description = "Control plane node hardware and network configuration"
  type = object({
    hostname             = string
    ip                   = string
    interface            = string
    install_disk         = string
    installer_image      = string
    allow_scheduling     = bool
    mount_secondary_disk = bool
  })
}

variable "worker_nodes" {
  description = "Map of worker nodes to provision iteratively (key = hostname)"
  type = map(object({
    ip                   = string
    interface            = string
    install_disk         = string
    installer_image      = string
    mount_secondary_disk = bool
  }))
  default = {}
}

variable "enable_argocd_bootstrap" {
  description = "When true (Phase 4), declaratively provisions ArgoCD and registers argocd/root-app.yaml via Talos control plane manifests"
  type        = bool
  default     = false
}

terraform {
  # GitLab-managed HTTP Terraform State Backend (initialized via ./init-state.sh)
  backend "http" {}

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0-alpha.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
  }
}

provider "talos" {}

# ==============================================================================
# Cryptographic Root of Trust (Persisted in GitLab Encrypted HTTP State)
# ==============================================================================

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.control_plane.ip]
  nodes                = concat([var.control_plane.ip], [for k, v in var.worker_nodes : v.ip])
}

# ==============================================================================
# Control Plane Node: HP Compaq Pro 6300 SFF (10.10.10.51 / VIP 10.10.10.10)
# ==============================================================================

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = concat(
    [
      yamlencode({
        cluster = {
          allowSchedulingOnControlPlanes = var.control_plane.allow_scheduling
          network = {
            cni = {
              name = "none"
            }
          }
          extraManifests  = []
          inlineManifests = []
        }
        machine = {
          install = {
            disk  = var.control_plane.install_disk
            image = var.control_plane.installer_image
          }
          kubelet = {
            nodeIP = {
              validSubnets = [var.node_subnet]
            }
            extraMounts = var.control_plane.mount_secondary_disk ? [
              {
                destination = "/var/mnt/longhorn-extra"
                type        = "bind"
                source      = "/var/mnt/longhorn-extra"
                options     = ["bind", "rshared", "rw"]
              }
            ] : []
          }
          network = {
            interfaces = [
              {
                interface = var.control_plane.interface
                addresses = ["${var.control_plane.ip}/24"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.gateway_ip
                  }
                ]
                vip = {
                  ip = var.cluster_vip
                }
              }
            ]
          }
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        auto       = "off"
        hostname   = var.control_plane.hostname
      })
    ],
    var.control_plane.mount_secondary_disk ? [
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = "longhorn-extra"
        provisioning = {
          diskSelector = {
            match = "disk.transport == 'sata' && !system_disk"
          }
          minSize = "100GB"
        }
        filesystem = {
          type = "xfs"
        }
      })
    ] : []
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.control_plane.ip
}

resource "time_sleep" "wait_for_reboot" {
  depends_on      = [talos_machine_configuration_apply.controlplane]
  create_duration = "120s"
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [time_sleep.wait_for_reboot]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

# ==============================================================================
# Worker Nodes (Iterative Provisioning via var.worker_nodes Map)
# - worker-1: HP Pavilion 590-p0xxx (10.10.10.52, 12GB RAM, Dual 1TB HDDs)
# - worker-2: Lenovo ideacenter 310S (10.10.10.53, 8GB RAM, 465.8GB HDD)
# ==============================================================================

data "talos_machine_configuration" "workers" {
  for_each = var.worker_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = concat(
    [
      yamlencode({
        cluster = {
          network = {
            cni = {
              name = "none"
            }
          }
        }
        machine = {
          install = {
            disk  = each.value.install_disk
            image = each.value.installer_image
          }
          kubelet = {
            nodeIP = {
              validSubnets = [var.node_subnet]
            }
            extraMounts = each.value.mount_secondary_disk ? [
              {
                destination = "/var/mnt/longhorn-extra"
                type        = "bind"
                source      = "/var/mnt/longhorn-extra"
                options     = ["bind", "rshared", "rw"]
              }
            ] : []
          }
          network = {
            interfaces = [
              {
                interface = each.value.interface
                addresses = ["${each.value.ip}/24"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.gateway_ip
                  }
                ]
              }
            ]
          }
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        auto       = "off"
        hostname   = each.key
      })
    ],
    each.value.mount_secondary_disk ? [
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = "longhorn-extra"
        provisioning = {
          diskSelector = {
            match = "disk.transport == 'sata' && !system_disk"
          }
          minSize = "100GB"
        }
        filesystem = {
          type = "xfs"
        }
      })
    ] : []
  )
}

resource "talos_machine_configuration_apply" "workers" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.workers[each.key].machine_configuration
  node                        = each.value.ip

  depends_on = [talos_machine_bootstrap.this]
}

# ==============================================================================
# Kubernetes API Credentials & Cluster Health Gate
# ==============================================================================

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_plane.ip
}

# Stage 1 Health Gate (Pre-CNI): Wait for Talos OS daemons (etcd, kubelet, machined)
# and the API server (:6443) to come online before Helm connects to install Cilium.
data "talos_cluster_health" "pre_cni" {
  depends_on             = [talos_cluster_kubeconfig.this, talos_machine_configuration_apply.workers]
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [var.control_plane.ip]
  worker_nodes           = [for k, v in var.worker_nodes : v.ip]
  endpoints              = data.talos_client_configuration.this.endpoints
  skip_kubernetes_checks = true
}

# ==============================================================================
# CNI Layer: Cilium (eBPF Native Routing + Layer 2 LoadBalancer Announcements)
# Namespace: kube-system
# ==============================================================================

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  version          = "1.15.5"
  namespace        = "kube-system"
  create_namespace = false
  cleanup_on_fail  = true

  values = [
    <<-EOT
    cluster:
      name: ${var.cluster_name}
      id: 1
    kubeProxyReplacement: true
    k8sServiceHost: "${var.cluster_vip}"
    k8sServicePort: 6443
    l2announcements:
      enabled: true
    k8sClientRateLimit:
      qps: 50
      burst: 100
    ipam:
      mode: kubernetes
    routingMode: native
    autoDirectNodeRoutes: true
    ipv4NativeRoutingCIDR: "10.244.0.0/16"
    hubble:
      enabled: true
      relay:
        enabled: true
        servicePort: 4245
      ui:
        enabled: true
      metrics:
        enabled:
          - dns:query
          - drop
          - tcp
          - flow
          - port-distribution
          - icmp
          - http
    operator:
      replicas: 1

    # Talos Linux Specific Bypasses
    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup
    securityContext:
      privileged: true
      capabilities:
        ciliumAgent:
          - CHOWN
          - KILL
          - NET_ADMIN
          - NET_RAW
          - IPC_LOCK
          - SYS_ADMIN
          - SYS_RESOURCE
          - DAC_OVERRIDE
          - FOWNER
          - SETGID
          - SETUID
        cleanCiliumState:
          - NET_ADMIN
          - SYS_ADMIN
          - SYS_RESOURCE
    EOT
  ]

  depends_on = [talos_cluster_kubeconfig.this, data.talos_cluster_health.pre_cni]
}

# Stage 2 Health Gate (Post-CNI): Wait for Cilium CNI to initialize, all configured
# nodes to report Ready, and all kube-system pods (including CoreDNS) to become Ready.
data "talos_cluster_health" "post_cni" {
  depends_on             = [helm_release.cilium, talos_machine_configuration_apply.workers]
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [var.control_plane.ip]
  worker_nodes           = [for k, v in var.worker_nodes : v.ip]
  endpoints              = data.talos_client_configuration.this.endpoints
  skip_kubernetes_checks = false
}

# ==============================================================================
# GitOps Bootstrap Layer: ArgoCD & Root App-of-Apps (Phase 4)
# Namespace: argocd
# ==============================================================================

resource "helm_release" "argocd" {
  count            = var.enable_argocd_bootstrap ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "6.7.18"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      crds = {
        install = false
      }
      server = {
        extraArgs = ["--insecure"]
      }
      extraObjects = [
        yamldecode(file("${path.module}/../../argocd/root-app.yaml"))
      ]
    })
  ]

  depends_on = [data.talos_cluster_health.post_cni]
}

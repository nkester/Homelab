terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0-alpha.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
  }
}

provider "talos" {}

resource "talos_machine_secrets" "this" {
  talos_version = "v1.13.7"
}

data "talos_client_configuration" "this" {
  cluster_name         = "homelab-cluster"
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = ["10.10.10.51"]
}

# ==========================================
# Control Plane: HP Compaq Pro 6300 SFF
# IP: 10.10.10.51
# ==========================================

data "talos_machine_configuration" "controlplane" {
  cluster_name     = "homelab-cluster"
  cluster_endpoint = "https://10.10.10.10:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.13.7" 

  config_patches = [
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
          disk = "/dev/sda"
          # Talos v 1.13.7 with extensions: iscsi-tools, util-linux-tools for Longhorn
          image = "factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.13.7"
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["10.10.10.0/24"]
          }
        }
        network = {
          interfaces = [
            {
              interface = "eno1"
              addresses = ["10.10.10.51/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = "10.10.10.1"
                }
              ]
              vip = {
                ip = "10.10.10.10"
              }
            }
          ]
        }
      }
    }),
    yamlencode({
	  apiVersion = "v1alpha1"
      kind = "HostnameConfig"
      auto = "off"
      hostname = "controlplane-1"
    })
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = "10.10.10.51"
}

resource "time_sleep" "wait_for_reboot" {
  depends_on      = [talos_machine_configuration_apply.controlplane]
  create_duration = "120s"
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [time_sleep.wait_for_reboot]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.10.10.51"
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

# ==========================================
# Worker Node 1: Lenovo ideacenter 310S
# IP: 10.10.10.52
# ==========================================

data "talos_machine_configuration" "worker1" {
  cluster_name     = "homelab-cluster"
  cluster_endpoint = "https://10.10.10.10:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.13.7" 

  config_patches = [
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
          # Explicitly target the 465.8G ST500DM002-1SB10 HDD
          disk = "/dev/sdb" 
          # Talos v 1.13.7 with extensions: iscsi-tools, util-linux-tools for Longhorn and realtek-firmware for the chipset
          image = "factory.talos.dev/metal-installer/71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7"
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["10.10.10.0/24"]
          }
        }
        network = {
          interfaces = [
            {
              interface = "enp2s0" 
              addresses = ["10.10.10.52/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = "10.10.10.1"
                }
              ]
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "HostnameConfig"
      auto = "off"
      hostname = "worker-1"
    })
  ]
}

resource "talos_machine_configuration_apply" "worker1" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker1.machine_configuration
  node                        = "10.10.10.52"
  
  # Ensure the control plane is bootstrapped and ready before provisioning workers
  depends_on = [talos_machine_bootstrap.this] 
}

# ==========================================
# Worker Node 2: Dell Inspiron 15R-5537
# IP: 10.10.10.53
# ==========================================

data "talos_machine_configuration" "worker2" {
  cluster_name     = "homelab-cluster"
  cluster_endpoint = "https://10.10.10.10:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.13.7" 

  config_patches = [
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
          # Explicitly target the 931.5G ST1000LM024 HN-M101MBB disk
          disk = "/dev/sda" 
          # Talos v 1.13.7 with extensions: iscsi-tools, util-linux-tools for Longhorn and realtek-firmware for the chipset
          image = "factory.talos.dev/metal-installer/71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7" 
        }
        kubelet = {
          nodeIP = {
            validSubnets = ["10.10.10.0/24"]
          }
        }
        network = {
          interfaces = [
            {
              interface = "enp1s0" 
              addresses = ["10.10.10.53/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = "10.10.10.1"
                }
              ]
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "HostnameConfig"
      auto = "off"
      hostname = "worker-2"
    })
  ]
}

resource "talos_machine_configuration_apply" "worker2" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker2.machine_configuration
  node                        = "10.10.10.53"
  
  # Ensure the control plane is bootstrapped and ready before provisioning workers
  depends_on = [talos_machine_bootstrap.this] 
}

# ==========================================
# Kubernetes API Credentials Extraction
# ==========================================

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.10.10.51"
}

# ==========================================
# Wait until the cluster is healthy to deploy helm charts
# ==========================================

data "talos_cluster_health" "this" {
  depends_on            = [talos_cluster_kubeconfig.this]
  client_configuration  = talos_machine_secrets.this.client_configuration
  control_plane_nodes   = ["10.10.10.51"]
  worker_nodes          = ["10.10.10.52", "10.10.10.53"]
  endpoints             = data.talos_client_configuration.this.endpoints
  skip_kubernetes_checks = true   # no CNI yet, so k8s-node-ready checks would hang forever
}

# ==========================================
# CNI Layer: Cilium (eBPF Native Routing)
# Namespace: kube-system
# ==========================================

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

  values = [
    <<-EOT
    cluster:
      name: homelab-cluster
      id: 1
    kubeProxyReplacement: true
    k8sServiceHost: "10.10.10.10"
    k8sServicePort: 6443
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

  depends_on = [talos_cluster_kubeconfig.this, data.talos_cluster_health.this]
}
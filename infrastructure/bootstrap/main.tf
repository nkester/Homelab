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

data "talos_machine_configuration" "controlplane" {
  cluster_name     = "homelab-cluster"
  cluster_endpoint = "https://10.10.10.10:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v1.13.7" 

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          image = "ghcr.io/siderolabs/installer:v1.13.7"
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

# Open Pryv.io template for Exoscale.
#
# Builds on Exoscale itself: Packer starts an instance from the stock Ubuntu
# template, provisions it over SSH, snapshots it and registers the snapshot as
# a custom template in every zone of `zones` (registered in the first zone,
# then copied to the others; the copies keep the same template ID).
#
# Usage: see README.md ("Building a template").

packer {
  required_plugins {
    exoscale = {
      source  = "github.com/exoscale/exoscale"
      version = ">= 0.5.2"
    }
  }
}

variable "exoscale_api_key" {
  description = "Exoscale IAM API key (read from EXOSCALE_API_KEY)."
  type        = string
  default     = env("EXOSCALE_API_KEY")
  sensitive   = true
}

variable "exoscale_api_secret" {
  description = "Exoscale IAM API secret (read from EXOSCALE_API_SECRET)."
  type        = string
  default     = env("EXOSCALE_API_SECRET")
  sensitive   = true
}

variable "pryv_tag" {
  description = "open-pryv.io release tag baked into the template, e.g. 2.0.0-rc.41."
  type        = string
}

variable "build" {
  description = "Template build number for this pryv_tag (1, 2, ...), recorded as the template build."
  type        = string
  default     = "1"
}

variable "zones" {
  description = "Exoscale zones to register the template in. The first one also hosts the build instance."
  type        = list(string)
  default     = ["ch-gva-2"]
}

variable "name_suffix" {
  description = "Appended to the template name, e.g. \" (test)\" for a test build."
  type        = string
  default     = ""
}

variable "base_template" {
  description = "Stock Exoscale template the build starts from."
  type        = string
  default     = "Linux Ubuntu 24.04 LTS 64-bit"
}

variable "boot_mode" {
  description = "Boot mode of the registered template: must match the base template (legacy or uefi; the stock Ubuntu 24.04 template boots uefi)."
  type        = string
  default     = "uefi"
}

variable "security_group" {
  description = "Security group of the build instance; it must allow TCP 22 from the machine running Packer."
  type        = string
  default     = "packer"
}

locals {
  template_name = "Open Pryv.io ${var.pryv_tag}${var.name_suffix}"
}

source "exoscale" "openpryv" {
  api_key                  = var.exoscale_api_key
  api_secret               = var.exoscale_api_secret
  instance_template        = var.base_template
  instance_type            = "medium"
  instance_disk_size       = 10
  instance_security_groups = [var.security_group]
  template_zones           = var.zones
  template_name            = local.template_name
  template_description     = "Open Pryv.io ${var.pryv_tag}: personal data and consent management server. Setup: https://pryv.github.io/ops-image-exoscale-open-pryv.io/"
  template_username        = "ubuntu"
  template_boot_mode       = var.boot_mode
  template_maintainer      = "Pryv"
  template_version         = var.pryv_tag
  template_build           = var.build
  ssh_username             = "ubuntu"
}

build {
  sources = ["source.exoscale.openpryv"]

  # Files installed into the image by 30-pryv.sh (uploaded as /tmp/image)
  provisioner "file" {
    source      = "${path.root}/../image"
    destination = "/tmp"
  }

  provisioner "shell" {
    execute_command  = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
    environment_vars = ["PRYV_TAG=${var.pryv_tag}", "PRYV_BUILD=${var.build}"]
    scripts = [
      "${path.root}/scripts/exoscale/motd-news-telemetry-disable.sh",
      "${path.root}/scripts/exoscale/apt-dist-upgrade.sh",
      "${path.root}/scripts/10-base.sh",
      "${path.root}/scripts/20-docker.sh",
      "${path.root}/scripts/30-pryv.sh",
      "${path.root}/scripts/exoscale/apt-cleanup.sh",
      "${path.root}/scripts/90-cloud-init-reset.sh",
      "${path.root}/scripts/exoscale/dhcp-cleanup.sh",
      "${path.root}/scripts/exoscale/history-cleanup.sh",
      "${path.root}/scripts/exoscale/machine-id-reset.sh",
      "${path.root}/scripts/exoscale/lock-root.sh",
      "${path.root}/scripts/exoscale/freespace-zero.sh",
      "${path.root}/scripts/98-journal-reset.sh",
      "${path.root}/scripts/99-ssh-reset.sh",
    ]
  }
}

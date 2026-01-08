terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.89.0"
    }
  }
}

variable "yc_token" {
  description = "Yandex.Cloud OAuth Token"
  type        = string
  sensitive   = true
}

variable "cloud_id" {
  description = "ID облака в Yandex.Cloud"
  type        = string
}

variable "folder_id" {
  description = "ID папки в Yandex.Cloud"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

################################################################
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Licensed Materials - Property of IBM
#
# ©Copyright IBM Corp. 2022
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################

################################################################
# Configure IBM Cloud
################################################################
variable "ibmcloud_api_key" {
  description = "IBM Cloud API key associated with user's identity"
  default     = "<key>"
}

variable "service_instance_id" {
  description = "The cloud instance ID of your account"
  default     = ""
}

variable "ibmcloud_region" {
  description = "The IBM Cloud region where you want to create the resources"
  default     = ""
}

variable "ibmcloud_zone" {
  description = "The zone of an IBM Cloud region where you want to create Power System resources"
  default     = ""
}

################################################################
# Configure the Bastion Instance details
################################################################

variable "bastion" {
  # only one node is supported
  default = {
    count      = 1
    memory     = "16"
    processors = "1"
  }
  validation {
    condition     = lookup(var.bastion, "count", 1) == 1
    error_message = "The bastion.count value must be either 1 or 2."
  }
}

variable "rhel_image_name" {
  description = "Name of the RHEL image that you want to use for the bastion node"
  default     = "rhel-8.6"
}

variable "processor_type" {
  description = "The type of processor mode (shared/dedicated)"
  default     = "shared"
}

variable "system_type" {
  description = "The type of system (s922/e980)"
  default     = "s922"
}

variable "network_name" {
  description = "The name of the network to be used for deploy operations"
  default     = "my_network_tang"
}

variable "dns_forwarders" {
  default = "8.8.8.8; 8.8.4.4"
}

variable "name_prefix" {}

variable "bastion_health_status" {
  type        = string
  description = "Specify if bastion should poll for the Health Status to be OK or WARNING. Default is OK."
  default     = "OK"
  validation {
    condition     = contains(["OK", "WARNING"], var.bastion_health_status)
    error_message = "The bastion_health_status value must be either OK or WARNING."
  }
}

variable "ansible_repo_name" {}

variable "rhel_subscription_username" {
  default = ""
}

variable "rhel_subscription_password" {
  default = ""
}
variable "rhel_subscription_org" {
  type    = string
  default = ""
}

variable "rhel_subscription_activationkey" {
  type    = string
  default = ""
}
variable "domain" {}
variable "rhel_smt" {}
variable "private_network_mtu" {}
variable "setup_squid_proxy" {
  type        = bool
  description = "Flag to install and configure squid proxy server on bastion node"
  default     = false
}
variable "proxy" {
  type        = object({})
  description = "External Proxy server details in a map"
  default     = {
    server = "",
    port = ""
    user = "",
    user_pass = ""
    no_proxy = ""
  }
  #    default = {
  #        server = "10.10.1.166",
  #        port = "3128"
  #        user = "pxuser",
  #        user_pass = "pxpassword"
  #    }
}
################################################################
# Configure the SSH Settings
################################################################

variable "rhel_username" {
  default = "root"
}

variable "private_key" {
  description = "private key"
}

variable "public_key" {
  description = "public key"
}

variable "connection_timeout" {
  description = "Timeout in minutes for SSH connections"
  default     = 5
}

variable "ssh_agent" {
  description = "Enable or disable SSH Agent. Can correct some connectivity issues. Default: false"
  default     = false
}
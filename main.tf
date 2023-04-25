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

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_region
  zone             = var.ibmcloud_zone
  alias            = "ibm-cloud-powervs"
}

resource "random_id" "label" {
  count       = var.vm_id == "" ? 1 : 0
  byte_length = "2" # Since we use the hex, the word lenght would double
  prefix      = "${var.vm_id_prefix}-"
}

locals {
  # Generates vm_id as combination of vm_id_prefix + (random_id or user-defined vm_id)
  name_prefix = var.name_prefix != "" ? random_id.label[0].hex : "${var.name_prefix}"

  # Private Key
  private_key_file = var.private_key_file == "" ? "${path.cwd}/data/id_rsa" : "${path.cwd}/${var.private_key_file}"
  private_key      = var.private_key == "" ? file(coalesce(local.private_key_file, "/dev/null")) : var.private_key

  public_key_file = var.public_key_file == "" ? "${path.cwd}/data/id_rsa.pub" : "${path.cwd}/${var.public_key_file}"
  public_key      = var.public_key == "" ? file(coalesce(local.public_key_file, "/dev/null")) : var.public_key
}

module "bastion" {
  # If the bastion.count is zero, then we're skipping as the bastion already exists
  count  = var.bastion.count >= 1 ? 1 : 0
  source = "./modules/1_bastion/"

  providers = {
    ibm = ibm.ibm-cloud-powervs
  }

  service_instance_id             = var.service_instance_id
  bastion                         = var.bastion
  rhel_image_name                 = var.rhel_image_name
  processor_type                  = var.processor_type
  system_type                     = var.system_type
  network_name                    = var.network_name
  dns_forwarders                  = var.dns_forwarders
  name_prefix                     = local.name_prefix
  bastion_health_status           = var.bastion_health_status
  ansible_repo_name               = var.ansible_repo_name
  rhel_subscription_username      = var.rhel_subscription_username
  rhel_subscription_password      = var.rhel_subscription_password
  rhel_subscription_org           = var.rhel_subscription_org
  rhel_subscription_activationkey = var.rhel_subscription_activationkey
  domain                          = var.domain
  rhel_smt                        = var.rhel_smt
  setup_squid_proxy               = var.setup_squid_proxy
  proxy                           = var.proxy
  rhel_username                   = var.rhel_username

  private_key         = local.private_key
  public_key          = local.public_key
  connection_timeout  = var.connection_timeout
  ssh_agent           = var.ssh_agent
  private_network_mtu = var.private_network_mtu
}

locals {
  bastion_network = module.bastion[0].bastion_network
  bastion_ip      = module.bastion[0].bastion_ip

  # Bastion Public IP is either from the vars file or from the prior module
  bastion_public_ip    = var.bastion_public_ip == "" ? module.bastion[0].bastion_public_ip : var.bastion_public_ip
  bastion_instance_ids = module.bastion[0].bastion_instance_ids
}

module "nbde" {
  source = "./modules/2_nbde"

  providers = {
    ibm = ibm.ibm-cloud-powervs
  }

  # Provider Details
  service_instance_id = var.service_instance_id

  # From Bastion
  bastion_ip        = local.bastion_ip
  bastion_public_ip = local.bastion_public_ip

  # Tang Setup
  tang                            = var.tang
  rhel_image_name                 = var.rhel_image_name
  processor_type                  = var.processor_type
  system_type                     = var.system_type
  network_name                    = var.network_name
  dns_forwarders                  = var.dns_forwarders
  name_prefix                     = local.name_prefix
  tang_health_status              = var.tang_health_status
  ansible_repo_name               = var.ansible_repo_name
  rhel_subscription_username      = var.rhel_subscription_username
  rhel_subscription_password      = var.rhel_subscription_password
  rhel_subscription_org           = var.rhel_subscription_org
  rhel_subscription_activationkey = var.rhel_subscription_activationkey
  domain                          = var.domain
  rhel_smt                        = var.rhel_smt
  setup_squid_proxy               = var.setup_squid_proxy
  proxy                           = var.proxy
  rhel_username                   = var.rhel_username

  private_key         = local.private_key
  connection_timeout  = var.connection_timeout
  ssh_agent           = var.ssh_agent
  private_network_mtu = var.private_network_mtu
  cluster_id_prefix   = var.cluster_id_prefix
  cluster_id          = var.cluster_id == "" ? random_id.label[0].hex : (var.cluster_id_prefix == "" ? var.cluster_id : "${var.cluster_id_prefix}-${var.cluster_id}")
}

locals {
  tang_instance_ids = module.nbde.tang_instance_ids
  tang_ips          = module.nbde.tang_ips
}

module "fips" {
  count  = var.fips_compliant ? 1 : 0
  source = "./modules/3_fips"

  providers = {
    ibm = ibm.ibm-cloud-powervs
  }

  depends_on = [
    module.bastion,
    module.nbde
  ]

  # IBM Cloud
  service_instance_id = var.service_instance_id

  # Bastion
  bastion_count        = lookup(var.bastion, "count", 1)
  bastion_instance_ids = local.bastion_instance_ids
  bastion_public_ip    = local.bastion_public_ip

  # Tang
  tang_count        = lookup(var.tang, "count", 1)
  tang_instance_ids = local.tang_instance_ids
  tang_ips          = local.tang_ips

  # RHEL
  rhel_username      = var.rhel_username
  private_key        = local.private_key
  ssh_agent          = var.ssh_agent
  connection_timeout = var.connection_timeout
}

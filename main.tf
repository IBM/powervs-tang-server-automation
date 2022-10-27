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
}

resource "random_id" "label" {
  count       = var.vm_id == "" ? 1 : 0
  byte_length = "2" # Since we use the hex, the word lenght would double
  prefix      = "${var.vm_id_prefix}-"
}

locals {
  # Generates vm_id as combination of vm_id_prefix + (random_id or user-defined vm_id)
  name_prefix = var.name_prefix != "" ? random_id.label[0].hex : "${var.name_prefix}"
}


locals {
  private_key_file = var.private_key_file == "" ? "${path.cwd}/data/id_rsa" : var.private_key_file
  private_key      = var.private_key == "" ? file(coalesce(local.private_key_file, "/dev/null")) : var.private_key
}

module "bastion" {
  # If the bastion.count is zero, then we're skipping as the bastion already exists
  count  = var.bastion.count >= 1 ? 1 : 0
  source = "modules/1_bastion"

  # IBM Cloud
  ibmcloud_api_key    = var.ibmcloud_api_key
  service_instance_id = var.service_instance_id
  ibmcloud_region     = var.ibmcloud_region
  ibmcloud_zone       = var.ibmcloud_zone

  name_prefix                     = local.name_prefix
  cluster_domain                  = var.domain
  rhel_image_name                 = var.rhel_image_name
  processor_type                  = var.processor_type
  system_type                     = var.system_type
  network_name                    = var.network_name
  network_dns                     = var.dns_forwarders == "" ? [] : [for dns in split(";", var.dns_forwarders) : trimspace(dns)]
  bastion_health_status           = var.bastion_health_status
  private_network_mtu             = var.private_network_mtu
  rhel_username                   = var.rhel_username
  private_key                     = local.private_key
  public_key                      = local.public_key
  ssh_agent                       = var.ssh_agent
  connection_timeout              = var.connection_timeout
  rhel_subscription_username      = var.rhel_subscription_username
  rhel_subscription_password      = var.rhel_subscription_password
  rhel_subscription_org           = var.rhel_subscription_org
  rhel_subscription_activationkey = var.rhel_subscription_activationkey
  ansible_repo_name               = var.ansible_repo_name
  rhel_smt                        = var.rhel_smt

  setup_squid_proxy = var.setup_squid_proxy
  proxy             = var.proxy
}

module "nbde" {
  source = "./modules/2_nbde"

  # Conditionally set bastion_public_ip or from bastion module if bastion was deployed
  service_instance_id = var.service_instance_id
  processor_type      = var.processor_type
  system_type         = var.system_type
  network_name        = var.network_name
  domain              = var.domain
  name_prefix         = local.name_prefix

  bastion_public_ip = module.bastion.bastion_public_ip
  rhel_username     = var.rhel_username
  private_key       = local.private_key
  ssh_agent         = var.ssh_agent
}


module "fips" {
  count  = var.fips_compliant ? 1 : 0
  source = "./modules/3_fips"

  # IBM Cloud
  ibmcloud_api_key    = var.ibmcloud_api_key
  service_instance_id = var.service_instance_id
  ibmcloud_region     = var.ibmcloud_region
  ibmcloud_zone       = var.ibmcloud_zone

  # Bastion
  bastion_count        = lookup(var.bastion, "count", 1)
  bastion_instance_ids = module.bastion.bastion_instance_ids
  bastion_public_ip    = module.bastion.bastion_public_ip

  # Tang
  tang_count        = lookup(var.tang, "count", 1)
  tang_instance_ids = module.nbde.tang_instance_ids
  tang_public_ip    = module.nbde.tang_ips

  # conn
  rhel_username      = var.rhel_username
  private_key        = local.private_key
  ssh_agent          = var.ssh_agent
  connection_timeout = var.connection_timeout
}
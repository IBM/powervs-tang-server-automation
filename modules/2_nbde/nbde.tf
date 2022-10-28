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

locals {
  private_key      = var.private_key

  proxy = {
    server    = lookup(var.proxy, "server", ""),
    port      = lookup(var.proxy, "port", "3128"),
    user      = lookup(var.proxy, "user", ""),
    password  = lookup(var.proxy, "password", "")
    user_pass = lookup(var.proxy, "user", "") == "" ? "" : "${lookup(var.proxy, "user", "")}:${lookup(var.proxy, "password", "")}@"
    no_proxy  = "127.0.0.1,localhost,.${var.cluster_id}.${var.domain}"
  }
}

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = var.service_instance_id
}

# Note: the image may need to be different than the bastion, so a unique block is used.
locals {
  catalog_tang_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.rhel_image_name]
  rhel_image_id      = length(local.catalog_tang_image) == 0 ? data.ibm_pi_image.tang[0].id : local.catalog_tang_image[0].image_id
  tang_storage_pool  = length(local.catalog_tang_image) == 0 ? data.ibm_pi_image.tang[0].storage_pool : local.catalog_tang_image[0].storage_pool
}

data "ibm_pi_image" "tang" {
  # a short-circuit to fail the ibm_pi_instance creation
  count                = length(local.catalog_tang_image) == 0 ? 1 : 0
  pi_image_name        = var.rhel_image_name
  pi_cloud_instance_id = var.service_instance_id
}

# Creates the Tang Servers
resource "ibm_pi_instance" "tang" {
  count = var.tang.count

  pi_memory            = var.tang["memory"]
  pi_processors        = var.tang["processors"]
  pi_instance_name     = "${var.name_prefix}-tang-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = local.rhel_image_id
  pi_key_pair_name     = "${var.name_prefix}-keypair"
  pi_sys_type          = var.system_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.tang_health_status

  pi_storage_pool = local.tang_storage_pool

  pi_network {
    network_id = var.bastion_network
  }
}

data "ibm_pi_instance_ip" "tang_ip" {
  count      = var.tang.count
  depends_on = [ibm_pi_instance.tang]

  pi_instance_name     = ibm_pi_instance.tang[count.index].pi_instance_name
  pi_network_name      = var.bastion_network
  pi_cloud_instance_id = var.service_instance_id
}

locals {
  tang_inventory = {
    rhel_username = var.rhel_username
    tang_hosts    = data.ibm_pi_instance_ip.tang_ip.*.ip
  }
}

resource "null_resource" "tang_install" {
  count = 1

  depends_on = [
    ibm_pi_instance.tang
  ]

  triggers = {
    external_ip        = var.bastion_public_ip
    rhel_username      = var.rhel_username
    private_key        = local.private_key
    ssh_agent          = var.ssh_agent
    connection_timeout = "${var.connection_timeout}m"
  }

  connection {
    type        = "ssh"
    user        = self.triggers.rhel_username
    host        = self.triggers.external_ip
    private_key = self.triggers.private_key
    agent       = self.triggers.ssh_agent
    timeout     = self.triggers.connection_timeout
  }

  # If the bastion has an existing nbde_server folder, it erases, and clones a repo with a single branch (tag)
  provisioner "remote-exec" {
    inline = [
      <<EOF
rm -rf nbde_server
echo 'Cloning into nbde_server...'
git clone "${var.nbde_repo}"
cd nbde_server
git checkout "${var.nbde_tag}"
EOF
    ]
  }

  # Copy over the files into the existing playbook and ensures the names are unique
  provisioner "file" {
    source      = "${path.cwd}/modules/2_nbde/templates/powervs-setup.yml"
    destination = "powervs-setup.yml"
  }

  provisioner "file" {
    source      = "${path.cwd}/modules/2_nbde/templates/powervs-tang.yml"
    destination = "powervs-tang.yml"
  }

  provisioner "file" {
    source      = "${path.cwd}/modules/2_nbde/templates/powervs-remove-subscription.yml"
    destination = "powervs-remove-subscription.yml"
  }

  provisioner "file" {
    content     = templatefile("${path.cwd}/modules/2_nbde/templates/inventory", local.tang_inventory)
    destination = "inventory"
  }

  # Added quotes to avoid globbing issues in the extra-vars
  provisioner "remote-exec" {
    when = create
    inline = [
      <<EOF
echo 'Running tang setup playbook...'
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory powervs-setup.yml --extra-vars username="${var.rhel_subscription_username}"\
  --extra-vars password="${var.rhel_subscription_password}"\
  --extra-vars bastion_ip="${var.bastion_ip}" \
  --extra-vars rhel_subscription_org="${var.rhel_subscription_org}" \
  --extra-vars ansible_repo_name="${var.ansible_repo_name}" \
  --extra-vars rhel_subscription_activationkey="${var.rhel_subscription_activationkey}" \
  --extra-vars proxy_user="${local.proxy.user}" \
  --extra-vars proxy_user_pass="${local.proxy.user_pass}" \
  --extra-vars proxy_server="${local.proxy.server}" \
  --extra-vars proxy_port="${local.proxy.port}" \
  --extra-vars no_proxy="${local.proxy.no_proxy}" \
  --extra-vars private_network_mtu="${var.private_network_mtu}"  \
  --extra-vars domain="${var.domain}"

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory powervs-tang.yml
EOF
    ]
  }

  # destroy optimistically destroys the subscription (if it fails, and it can it pipes to true to shortcircuit)
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      <<EOF
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory powervs-remove-subscription.yml
EOF
    ]
  }
}

resource "null_resource" "tang_allnodes" {
  count = 1

  depends_on = [
    ibm_pi_instance.tang
  ]

  triggers = {
    external_ip        = var.bastion_public_ip
    rhel_username      = var.rhel_username
    private_key        = local.private_key
    ssh_agent          = var.ssh_agent
    connection_timeout = "${var.connection_timeout}m"
  }

  connection {
    type        = "ssh"
    user        = self.triggers.rhel_username
    host        = self.triggers.external_ip
    private_key = self.triggers.private_key
    agent       = self.triggers.ssh_agent
    timeout     = self.triggers.connection_timeout
  }

  provisioner "remote-exec" {
    when = create
    inline = [
      <<EOF
echo "=All NBDE Server jwk keys="
find nbde_server/keys/ -type f
EOF
    ]
  }
}
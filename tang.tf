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
  bastion_count = lookup(var.bastion, "count", 1)
  proxy = {
    server    = lookup(var.proxy, "server", ""),
    port      = lookup(var.proxy, "port", "3128"),
    user      = lookup(var.proxy, "user", ""),
    password  = lookup(var.proxy, "password", "")
    user_pass = lookup(var.proxy, "user", "") == "" ? "" : "${lookup(var.proxy, "user", "")}:${lookup(var.proxy, "password", "")}@"
    no_proxy  = "127.0.0.1,localhost,.${var.cluster_id}.${var.cluster_domain}"
  }
}

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = var.service_instance_id
}

locals {
  catalog_bastion_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.rhel_image_name]
  rhel_image_id         = length(local.catalog_bastion_image) == 0 ? data.ibm_pi_image.bastion[0].id : local.catalog_bastion_image[0].image_id
  bastion_storage_pool  = length(local.catalog_bastion_image) == 0 ? data.ibm_pi_image.bastion[0].storage_pool : local.catalog_bastion_image[0].storage_pool
}

data "ibm_pi_image" "bastion" {
  # TODO: Check on the following... it doesn't make sense.
  count                = length(local.catalog_bastion_image) == 0 ? 1 : 0
  pi_image_name        = var.rhel_image_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_network" "network" {
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_network" "public_network" {
  pi_network_name      = "${local.name_prefix}-pub-net"
  pi_cloud_instance_id = var.service_instance_id
  pi_network_type      = "pub-vlan"
  pi_dns               = var.dns_forwarders == "" ? [] : [for dns in split(";", var.dns_forwarders) : trimspace(dns)]
}

resource "ibm_pi_key" "key" {
  pi_cloud_instance_id = var.service_instance_id
  pi_key_name          = "${local.name_prefix}-keypair"
  pi_ssh_key           = var.public_key
}

resource "ibm_pi_instance" "bastion" {
  count = local.bastion_count

  pi_memory            = var.bastion["memory"]
  pi_processors        = var.bastion["processors"]
  pi_instance_name     = "${local.name_prefix}-bastion-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = local.rhel_image_id
  pi_key_pair_name     = ibm_pi_key.key.key_id
  pi_sys_type          = var.system_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.bastion_health_status
  pi_volume_ids        = var.storage_type == "nfs" ? ibm_pi_volume.volume.*.volume_id : null
  pi_storage_pool      = local.bastion_storage_pool

  pi_network {
    network_id = ibm_pi_network.public_network.network_id
  }
  pi_network {
    network_id = data.ibm_pi_network.network.id
  }
}

data "ibm_pi_instance_ip" "bastion_ip" {
  count      = local.bastion_count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "bastion_public_ip" {
  count      = local.bastion_count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = ibm_pi_network.public_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "null_resource" "bastion_init" {
  count = local.bastion_count

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [
      "whoami"
    ]
  }
  provisioner "file" {
    content     = var.private_key
    destination = ".ssh/id_rsa"
  }
  provisioner "file" {
    content     = var.public_key
    destination = ".ssh/id_rsa.pub"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
sudo chmod 600 .ssh/id_rsa*
sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg
sudo hostnamectl set-hostname --static ${lower(local.name_prefix)}bastion-${count.index}.${var.cluster_domain}
echo 'HOSTNAME=${lower(local.name_prefix)}bastion-${count.index}.${var.cluster_domain}' | sudo tee -a /etc/sysconfig/network > /dev/null
sudo hostname -F /etc/hostname
echo 'vm.max_map_count = 262144' | sudo tee --append /etc/sysctl.conf > /dev/null
# Set SMT to user specified value; Should not fail for invalid values.
sudo ppc64_cpu --smt=${var.rhel_smt} | true
# turn off rx and set mtu to var.private_network_mtu for all ineterfaces to improve network performance
cidrs=("${ibm_pi_network.public_network.pi_cidr}" "${data.ibm_pi_network.network.cidr}")
for cidr in "$${cidrs[@]}"; do
  envs=($(ip r | grep "$cidr dev" | awk '{print $3}'))
  for env in "$${envs[@]}"; do
    con_name=$(sudo nmcli -t -f NAME connection show | grep $env)
    sudo nmcli connection modify "$con_name" ethtool.feature-rx off
    sudo nmcli connection modify "$con_name" ethernet.mtu ${var.private_network_mtu}
    sudo nmcli connection up "$con_name"
  done
done
EOF
    ]
  }
}

resource "null_resource" "setup_proxy_info" {
  count      = !var.setup_squid_proxy && local.proxy.server != "" ? local.bastion_count : 0
  depends_on = [null_resource.bastion_init]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  # Setup proxy
  provisioner "remote-exec" {
    inline = [
      <<EOF
echo "Setting up proxy details..."
# System
set http_proxy="http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
set https_proxy="http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
set no_proxy="${local.proxy.no_proxy}"
echo "export http_proxy=\"http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}\"" | sudo tee /etc/profile.d/http_proxy.sh > /dev/null
echo "export https_proxy=\"http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null
echo "export no_proxy=\"${local.proxy.no_proxy}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null
# RHSM
sudo sed -i -e 's/^proxy_hostname =.*/proxy_hostname = ${local.proxy.server}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_port =.*/proxy_port = ${local.proxy.port}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_user =.*/proxy_user = ${local.proxy.user}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_password =.*/proxy_password = ${local.proxy.password}/' /etc/rhsm/rhsm.conf
# YUM/DNF
# Incase /etc/yum.conf is a symlink to /etc/dnf/dnf.conf we try to update the original file
yum_dnf_conf=$(readlink -f -q /etc/yum.conf)
sudo sed -i -e '/^proxy.*/d' $yum_dnf_conf
echo "proxy=http://${local.proxy.server}:${local.proxy.port}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_username=${local.proxy.user}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_password=${local.proxy.password}" | sudo tee -a $yum_dnf_conf > /dev/null
EOF
    ]
  }
}

resource "null_resource" "bastion_register" {
  count      = (var.rhel_subscription_username == "" || var.rhel_subscription_username == "<subscription-id>") && var.rhel_subscription_org == "" ? 0 : local.bastion_count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info]
  triggers = {
    external_ip        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    rhel_username      = var.rhel_username
    private_key        = var.private_key
    ssh_agent          = var.ssh_agent
    connection_timeout = var.connection_timeout
  }

  connection {
    type        = "ssh"
    user        = self.triggers.rhel_username
    host        = self.triggers.external_ip
    private_key = self.triggers.private_key
    agent       = self.triggers.ssh_agent
    timeout     = "${self.triggers.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
# Give some more time to subscription-manager
sudo subscription-manager config --server.server_timeout=600
sudo subscription-manager clean
if [[ '${var.rhel_subscription_username}' != '' && '${var.rhel_subscription_username}' != '<subscription-id>' ]]; then 
    sudo subscription-manager register --username='${var.rhel_subscription_username}' --password='${var.rhel_subscription_password}' --force
else
    sudo subscription-manager register --org='${var.rhel_subscription_org}' --activationkey='${var.rhel_subscription_activationkey}' --force
fi
sudo subscription-manager refresh
sudo subscription-manager attach --auto
EOF
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp/terraform_*"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = self.triggers.rhel_username
      host        = self.triggers.external_ip
      private_key = self.triggers.private_key
      agent       = self.triggers.ssh_agent
      timeout     = "2m"
    }
    when       = destroy
    on_failure = continue
    inline = [
      "sudo subscription-manager unregister",
      "sudo subscription-manager remove --all",
    ]
  }
}

resource "null_resource" "enable_repos" {
  count      = local.bastion_count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
# Additional repo for installing ansible package
if ( [[ -z "${var.rhel_subscription_username}" ]] || [[ "${var.rhel_subscription_username}" == "<subscription-id>" ]] ) && [[ -z "${var.rhel_subscription_org}" ]]; then
  sudo yum install -y epel-release
else
  sudo subscription-manager repos --enable ${var.ansible_repo_name}
fi
EOF
    ]
  }
}

resource "null_resource" "bastion_packages" {
  count = local.bastion_count
  depends_on = [
    null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register,
    null_resource.enable_repos
  ]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "#sudo yum update -y --skip-broken",
      "sudo yum install -y wget iptables jq git net-tools vim python3 tar",
      "iptables -A FORWARD -i env3 -j ACCEPT",
      "iptables -A FORWARD -o env3 -j ACCEPT",
      "iptables -t nat -A POSTROUTING -o env2 -j MASQUERADE",
      "sysctl -w net.ipv4.ip_forward=1"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl unmask NetworkManager",
      "sudo systemctl start NetworkManager",
      "for i in $(nmcli device | grep unmanaged | awk '{print $1}'); do echo NM_CONTROLLED=yes | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-$i; done",
      "sudo systemctl restart NetworkManager",
      "sudo systemctl enable NetworkManager"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y ansible-2.9.*"
    ]
  }
}

# Workaround for unable to access RHEL 8.3 instance after reboot. TODO: Remove when permanently fixed.
resource "null_resource" "rhel83_fix" {
  count      = local.bastion_count
  depends_on = [null_resource.bastion_packages]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum remove cloud-init --noautoremove -y",
    ]
  }
}

# Creates the Tang Servers
resource "ibm_pi_instance" "tang" {
  count      = var.tang_count
  depends_on = [ibm_pi_instance.bastion]

  pi_memory            = var.tang["memory"]
  pi_processors        = var.tang["processors"]
  pi_instance_name     = "${local.name_prefix}-tang-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = local.rhel_image_id
  pi_key_pair_name     = ibm_pi_key.key.key_id
  pi_sys_type          = var.system_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.tang_health_status
  pi_storage_pool      = local.bastion_storage_pool

  pi_network {
    network_id = data.ibm_pi_network.network.id
  }
}

data "ibm_pi_instance_ip" "tang_ip" {
  count      = var.tang_count
  depends_on = [ibm_pi_instance.tang]

  pi_instance_name     = ibm_pi_instance.tang[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.name
  pi_cloud_instance_id = var.service_instance_id
}

locals {

  tang_inventory = {
    rhel_username = var.rhel_username
    tang_hosts    = data.ibm_pi_instance_ip.tang_ip.*.ip
  }
}

resource "null_resource" "install" {
  depends_on = [
    null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register,
    null_resource.enable_repos, ibm_pi_instance.bastion
  ]

  count = local.bastion_count

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }


  provisioner "remote-exec" {
    inline = [
      "rm -rf nbde_server",
      "echo 'Cloning into nbde_server...'",
      "git clone ${var.nbde_repo} --quiet",
      "cd nbde_server && git checkout ${var.nbde_tag}",
    ]
  }
  provisioner "file" {
    source      = "${path.cwd}/templates/tang-playbook.yml"
    destination = "nbde_server/tests/"
  }


  provisioner "file" {
    source      = "${path.cwd}/templates/subscription.yml"
    destination = "nbde_server/tests/"
  }

  provisioner "file" {
    content     = templatefile("${path.cwd}/templates/tang_inventory", local.tang_inventory)
    destination = "nbde_server/inventory"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running tang setup playbook...'",
      "cd nbde_server && export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i inventory tests/subscription_tang.yml --extra-vars username=${var.rhel_subscription_username} --extra-vars password=${var.rhel_subscription_password} --extra-vars bastion_ip=${data.ibm_pi_instance_ip.bastion_ip[0].ip} && ansible-playbook -i inventory tests/tang-playbook.yml"
    ]
  }
}




########################################################################################################################
# For the tang instances, the final steps are:
# 1. Remove cloud-init
# 2. Enable fips on the tang servers
# 3. Reboot the tang instances to enable fips

resource "null_resource" "finalize_tang" {
  count      = var.fips_compliant ? 1 : 0
  depends_on = [null_resource.bastion_packages]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    source      = "${path.cwd}/templates/enable-fips.yml"
    destination = "fips/tasks/"
  }

  provisioner "file" {
    content     = templatefile("${path.cwd}/templates/tang_inventory", local.tang_inventory)
    destination = "fips/inventory"
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
echo 'Running tang setup playbook...'
ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i inventory enable-fips.yml
EOF
    ]
  }
}

# Reboot the instance
resource "ibm_pi_instance_action" "fips_tang_reboot" {
  depends_on = [
    null_resource.finalize_tang
  ]
  count                = var.fips_compliant ? var.tang.count : 0
  pi_cloud_instance_id = var.service_instance_id

  # Example: 99999-AA-5554-333-0e1248fa30c6/10111-b114-4d11-b2224-59999ab
  pi_instance_id = split("/", ibm_pi_instance.tang_inst[count.index].id)[1]
  pi_action      = "soft-reboot"
}

########################################################################################################################
# For the Bastion instances, the final steps are:
# 1. Remove cloud-init
# 2. Enable fips
# 3. Reboot the bastion instances to enable fips

resource "null_resource" "bastion_remove_cloud_init" {
  count      = var.bastion.count
  depends_on = [null_resource.bastion_packages]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
sudo yum remove cloud-init --noautoremove -y
EOF
    ]
  }
}

resource "null_resource" "fips_enable" {
  count      = var.fips_compliant ? var.bastion.count : 0
  depends_on = [null_resource.bastion_remove_cloud_init]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
# enable FIPS as required
if [[ ${var.fips_compliant} = true ]]; then
  sudo fips-mode-setup --enable
fi
sudo yum remove cloud-init --noautoremove -y
EOF
    ]
  }
}

# Reboot the bastion instance
resource "ibm_pi_instance_action" "fips_bastion_reboot" {
  depends_on = [
    null_resource.fips_enable
  ]
  count                = var.fips_compliant ? var.bastion.count : 0
  pi_cloud_instance_id = var.service_instance_id

  # Example: 99999-AA-5554-333-0e1248fa30c6/10111-b114-4d11-b2224-59999ab
  pi_instance_id = split("/", ibm_pi_instance.bastion_inst[count.index].id)[1]
  pi_action      = "soft-reboot"
}
########################################################################################################################
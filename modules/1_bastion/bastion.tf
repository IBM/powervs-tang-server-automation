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

data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = var.service_instance_id
}

locals {
  private_key           = var.private_key
  public_key            = var.public_key
  catalog_bastion_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.rhel_image_name]
  rhel_image_id         = length(local.catalog_bastion_image) == 0 ? data.ibm_pi_image.bastion[0].id : local.catalog_bastion_image[0].image_id
  bastion_storage_pool  = length(local.catalog_bastion_image) == 0 ? data.ibm_pi_image.bastion[0].storage_pool : local.catalog_bastion_image[0].storage_pool
}

data "ibm_pi_image" "bastion" {
  count                = length(local.catalog_bastion_image) == 0 ? 1 : 0
  pi_image_name        = var.rhel_image_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_network" "network" {
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "ibm_pi_network" "public_network" {
  pi_network_name      = "${var.name_prefix}-pub-net"
  pi_cloud_instance_id = var.service_instance_id
  pi_network_type      = "pub-vlan"
  pi_dns               = var.dns_forwarders == "" ? [] : [for dns in split(";", var.dns_forwarders) : trimspace(dns)]
}

resource "ibm_pi_key" "key" {
  pi_cloud_instance_id = var.service_instance_id
  pi_key_name          = "${var.name_prefix}-keypair"
  pi_ssh_key           = var.public_key
}

resource "ibm_pi_instance" "bastion" {
  depends_on = [ibm_pi_key.key]
  count      = var.bastion.count

  pi_memory            = var.bastion["memory"]
  pi_processors        = var.bastion["processors"]
  pi_instance_name     = "${var.name_prefix}-bastion-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = local.rhel_image_id
  pi_key_pair_name     = "${var.name_prefix}-keypair"
  pi_sys_type          = var.system_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.bastion_health_status

  pi_storage_pool = local.bastion_storage_pool

  pi_network {
    network_id = ibm_pi_network.public_network.network_id
  }
  pi_network {
    network_id = data.ibm_pi_network.network.id
  }
}

data "ibm_pi_instance_ip" "bastion_ip" {
  count      = var.bastion.count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "bastion_public_ip" {
  count      = var.bastion.count
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion[count.index].pi_instance_name
  pi_network_name      = ibm_pi_network.public_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

resource "null_resource" "bastion_init" {
  count = var.bastion.count

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
      "whoami"
    ]
  }
  provisioner "file" {
    content     = local.private_key
    destination = ".ssh/id_rsa"
  }
  provisioner "file" {
    content     = local.public_key
    destination = ".ssh/id_rsa.pub"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
sudo chmod 600 .ssh/id_rsa*
sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg
sudo hostnamectl set-hostname --static ${lower(var.name_prefix)}-bastion-${count.index}.${var.domain}
echo 'HOSTNAME=${lower(var.name_prefix)}bastion-${count.index}.${var.domain}' | sudo tee -a /etc/sysconfig/network > /dev/null
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
  count      = !var.setup_squid_proxy && length(var.proxy) != 0 ? var.bastion.count : 0
  depends_on = [null_resource.bastion_init]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  # Setup proxy
  provisioner "remote-exec" {
    inline = [
      <<EOF
echo "Setting up proxy details..."
# System
set http_proxy="http://${var.proxy[0].user_pass}${var.proxy[0].server}:${var.proxy[0].port}"
set https_proxy="http://${var.proxy[0].user_pass}${var.proxy[0].server}:${var.proxy[0].port}"
set no_proxy="${var.proxy[0].no_proxy}"
echo "export http_proxy=\"http://${var.proxy[0].user_pass}${var.proxy[0].server}:${var.proxy[0].port}\"" | sudo tee /etc/profile.d/http_proxy.sh > /dev/null
echo "export https_proxy=\"http://${var.proxy[0].user_pass}${var.proxy[0].server}:${var.proxy[0].port}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null
echo "export no_proxy=\"${var.proxy[0].no_proxy}\"" | sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null
# RHSM
sudo sed -i -e 's/^proxy_hostname =.*/proxy_hostname = ${var.proxy[0].server}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_port =.*/proxy_port = ${var.proxy[0].port}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_user =.*/proxy_user = ${var.proxy[0].user}/' /etc/rhsm/rhsm.conf
sudo sed -i -e 's/^proxy_password =.*/proxy_password = ${var.proxy[0].user_pass}/' /etc/rhsm/rhsm.conf
# YUM/DNF
# Incase /etc/yum.conf is a symlink to /etc/dnf/dnf.conf we try to update the original file
yum_dnf_conf=$(readlink -f -q /etc/yum.conf)
sudo sed -i -e '/^proxy.*/d' $yum_dnf_conf
echo "proxy=http://${var.proxy[0].server}:${var.proxy[0].port}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_username=${var.proxy[0].user}" | sudo tee -a $yum_dnf_conf > /dev/null
echo "proxy_password=${var.proxy[0].user_pass}" | sudo tee -a $yum_dnf_conf > /dev/null
EOF
    ]
  }
}

resource "null_resource" "bastion_register" {
  count      = (var.rhel_subscription_username == "" || var.rhel_subscription_username == "<subscription-id>") && var.rhel_subscription_org == "" ? 0 : var.bastion.count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info]
  triggers = {
    external_ip        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    rhel_username      = var.rhel_username
    private_key        = local.private_key
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
  count      = var.bastion.count
  depends_on = [null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register]

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
# Additional repo for installing ansible package
if ( [[ -z "${var.rhel_subscription_username}" ]] || [[ "${var.rhel_subscription_username}" == "<subscription-id>" ]] ) && [[ -z "${var.rhel_subscription_org}" ]]; then
  sudo yum install -y epel-release
else
  os_ver=$(cat /etc/os-release | egrep "^VERSION_ID=" | awk -F'"' '{print $2}')
  if [[ $os_ver != "9"* ]]; then
    sudo subscription-manager repos --enable ${var.ansible_repo_name}
  else
    sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  fi
fi
EOF
    ]
  }
}

resource "null_resource" "bastion_packages" {
  count = var.bastion.count
  depends_on = [
    null_resource.bastion_init, null_resource.setup_proxy_info, null_resource.bastion_register,
    null_resource.enable_repos
  ]

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
      sudo yum install -y wget jq git net-tools vim python3 tar firewalld iptables

      os_ver=$(cat /etc/os-release | egrep "^VERSION_ID=" | awk -F'"' '{print $2}')
      if [[ $os_ver == "9"* ]]
      then
        # version 9: uses firewalld and masquerade
        # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/pdf/configuring_firewalls_and_packet_filters/red_hat_enterprise_linux-9-configuring_firewalls_and_packet_filters-en-us.pdf
        yum install -y firewalld
        systemctl start firewalld
        systemctl enable firewalld --now
        firewall-cmd --zone=public --change-interface=env2
        firewall-cmd --zone=trusted --change-interface=env3
        firewall-cmd --zone=public --add-masquerade
      else
        # version 8: uses iptables
        iptables -A FORWARD -i env3 -j ACCEPT
        iptables -A FORWARD -o env3 -j ACCEPT
        iptables -t nat -A POSTROUTING -o env2 -j MASQUERADE
        sysctl -w net.ipv4.ip_forward=1
      fi
EOF
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
      <<EOF
#Installing ansible package.
 os_ver=$(cat /etc/os-release | egrep "^VERSION_ID=" | awk -F'"' '{print $2}')
  if [[ $os_ver == "9"* ]]; then
    sudo yum install -y ansible-core
  elif [[ $os_ver == "8.*"* ]]; then
    sudo yum install -y ansible-2.9.*
  else
    sudo yum install -y ansible
  fi
EOF
    ]
  }
}

# Always have to have this in PowerVS
resource "null_resource" "bastion_setup_rsct" {
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
# Adds the RSCT rpms
sudo yum install -y rsct.basic.ppc64le rsct.core.ppc64le rsct.core.utils.ppc64le rsct.opt.storagerm.ppc64le
EOF
    ]
  }
}

# There was an issue in RHEL8.3, this is left as it is known to work.
resource "null_resource" "bastion_remove_cloud_init" {
  count      = var.bastion.count
  depends_on = [null_resource.bastion_setup_rsct]

  triggers = {
    external_ip        = data.ibm_pi_instance_ip.bastion_public_ip[count.index].external_ip
    rhel_username      = var.rhel_username
    private_key        = var.private_key
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
    inline = [
      <<EOF
sudo yum remove cloud-init --noautoremove -y
EOF
    ]
  }

  # destroy optimistically destroys the subscription (if it fails, and it can it pipes to true to shortcircuit)
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue

    inline = [
      <<EOF
sudo subscription-manager unregister || true
sudo subscription-manager remove --all || true
EOF
    ]
  }
}

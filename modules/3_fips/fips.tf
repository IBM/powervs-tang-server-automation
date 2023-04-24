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
  private_key = var.private_key
}

################################################################
# For the tang instances, the final steps are:
# 1. Enable fips on the tang servers
# 2. Reboot the tang instances to enable fips

resource "null_resource" "tang_fips_enable" {
  count = 1

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
mkdir -p fips/
EOF
    ]
  }

  provisioner "file" {
    source      = "${path.cwd}/modules/3_fips/files/fips.yml"
    destination = "fips/fips.yml"
  }

  provisioner "remote-exec" {
    inline = [
      <<EOF
echo "Hosts: ${var.tang_ips}"
echo "[vmhost],${var.tang_ips}" | tr "," "\n\t" > fips/inventory

echo 'Running fips enablement playbook'
cd fips
ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i inventory fips.yml
EOF
    ]
  }
}

resource "ibm_pi_instance_action" "tang_fips_reboot" {
  depends_on = [
    null_resource.tang_fips_enable
  ]
  count                = length(var.tang_instance_ids)
  pi_cloud_instance_id = var.service_instance_id

  # Example: 99999-AA-5554-333-0e1248fa30c6/10111-b114-4d11-b2224-59999ab
  pi_instance_id = split("/", var.tang_instance_ids[count.index])[1]
  pi_action      = "soft-reboot"
}

################################################################
# For the Bastion instances, the final steps are:
# 1. Enable fips
# 3. Reboot the bastion instances to enable fips

resource "null_resource" "bastion_fips_enable" {
  # If the bastion.count is zero, then we're skipping as the bastion
  # already exists
  depends_on = [
    null_resource.tang_fips_enable
  ]
  count = var.bastion_count

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip
    private_key = local.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOF
# enable FIPS as required
sudo fips-mode-setup --enable
# We considered using ibm_pi_instance_action and opted for an Operating Systems controlled reboot as we know the state when we take this action.
sudo shutdown -r +1
EOF
    ]
  }
}

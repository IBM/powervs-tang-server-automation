





resource "null_resource" "cloud_init" {
  count      = var.tang.count
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
sudo yum remove cloud-init --noautoremove -y
EOF
    ]
  }
}
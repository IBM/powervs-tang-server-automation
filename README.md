# `powervs-tang-server-automation`

The [`powervs-tang-server-automation` project](https://github.com/IBM/powervs-tang-server-automation) provides Terraform
based automation code to help with the deployment
of [Network Bound Disk Encryption (NBDE)](https://github.com/linux-system-roles/nbde_server)
on [IBM® Power Systems™ Virtual Server on IBM Cloud](https://www.ibm.com/cloud/power-virtual-server).

The NBDE Server, also called the tang server, is deployed in a 3-node cluster with a
single [bastion host](https://en.wikipedia.org/wiki/Bastion_host). The tang server socket listens on port 7500.

# Installation Quickstart

- [Installation Quickstart](#installation-quickstart)
    - [Download the Automation Code](#download-the-automation-code)
    - [Setup Terraform Variables](#setup-terraform-variables)
    - [Start Install](#start-install)
    - [Post Install](#post-install)
        - [Fetch Keys from Bastion Node](#fetch-keys-from-bastion-node)
        - [Destroy Tang Server](#destroy-tang-server)

## Download the Automation Code

You'll need to use git to clone the deployment code when working off the master branch

```
$ git clone https://github.com/ibm/powervs-tang-server-automation
$ cd powervs-tang-server-automation
```

## Setup Terraform Variables

Update following variables in the [var.tfvars](../var.tfvars) based on your environment.

```
ibmcloud_api_key    = "xyzaaaaaaaabcdeaaaaaa"
ibmcloud_region     = "xya"
ibmcloud_zone       = "abc"
service_instance_id = "abc123xyzaaaa"
rhel_image_name     = "<rhel_or_centos_image-name>"
network_name        = "ocp-net"
public_key_file             = "data/id_rsa.pub"
private_key_file            = "data/id_rsa"
rhel_subscription_username  = "user@test.com"
rhel_subscription_password  = "mypassword"
```

Note: rhel_image_name should reference a PowerVS image for Red Hat Enterprise Linux 8.6 or 9.0 or Centos 8.6. 
Also, please note this automation does not support Centos with FIPS enabled.

## Start Install

Run the following commands from within the directory.

```
$ terraform init
$ terraform plan --var-file=var.tfvars
$ terraform apply -var-file=var.tfvars
```

Note: Terraform Version should be ~>1.2.0

Now wait for the installation to complete. It may take around 20 mins to complete provisioning.

On successful install cluster details will be printed as shown below.

```
bastion_ip = [
  "193.168.*.*",
]
bastion_public_ip = [
  "163.68.*.*",
]
tang_ip = "193.168.*.*,193.168.*.*,193.168.*.*"
```

These details can be retrieved anytime by running the following command from the root folder of the code

```
$ terraform output
```

In case of any errors, you'll have to re-apply.

## Post Install

### Fetch Keys from Bastion Node

Once the deployment is completed successfully, you can connect to bastion node and fetch keys for every tang server

```
$ cat /root/nbde_server/keys/*
```

### Destroy Tang Server

Destroy the Tang Server

```
$ terraform destroy -var-file var.tfvars
```

### Backup

Per [Red Hat](https://www.redhat.com/en/blog/advanced-automation-and-management-network-bound-disk-encryption-rhel-system-roles)'
s blog, we've added the `nbde_server_fetch_keys: yes` This downloads the keys to the 'bastion host' and customers are
expected to backup the keys using their operations processes.

### Re-keying all NBDE servers

1. Connect to your Bastion host
2. Change directory to `nbde_server`
   `cd nbde_server`
3. Run the playbook with the rotate keys variable

```terraform
ANSIBLE_HOST_KEY_CHECKING = False ansible-playbook -i inventory tasks/powervs-tang.yml -e nbde_server_rotate_keys = yes
```

### Re-keying (Deleting) a single Tang server keys

1. Connect to your Bastion host

2. Change directory to `nbde_server`

```cd nbde_server```

3. Copy the `inventory` to `inventory-del`

```cp inventory inventory-del```

4. Edit the `inventory-del` for the hosts you want to rekey

5. Run the playbook with the rotate keys variable

```terraform
ANSIBLE_HOST_KEY_CHECKING = False ansible-playbook -i inventory tasks/powervs-tang.yml -e nbde_server_rotate_keys = yes
```

## Automation Host Prerequisites

The automation needs to run from a system with internet access. This could be your laptop or a VM with public internet
connectivity. This automation code have been tested on the following Operating Systems:

- Mac OSX (Darwin)
- Linux (x86_64/ppc64le)
- Windows 10

Follow the [guide](docs/automation_host_prereqs.md) to complete the prerequisites.

## PowerVS Prerequisites

Follow the [guide](docs/prereqs_powervs.md) to complete the PowerVS prerequisites.

## Tang Infra Install

Follow the [quickstart](docs/quickstart.md) guide for NBDE installation on PowerVS.

## Make It Better

For bugs/enhancement requests etc. please open a
GitHub [issue](https://github.com/ibm/powervs-tang-server-automation/issues)

## Contributing

Please see the [contributing doc](CONTRIBUTING.md) for more details.

PRs are most welcome !!

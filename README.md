# Tang-infra-automation

This repo will be used for tang-infra-automation where we can deploy 1 bastion node with 3 tang servers.

# Installation Quickstart

- [Installation Quickstart](#installation-quickstart)
  - [Download the Automation Code](#download-the-automation-code)
  - [Setup Terraform Variables](#setup-terraform-variables)
  - [Start Install](#start-install)
  - [Post Install](#post-install)
      - [Fetch Keys from Bastion Node](#fetch-keys-from-bastion-node)
  

## Download the Automation Code

You'll need to use git to clone the deployment code when working off the master branch

```
$ git clone https://github.com/gauravpbankar/tang-infra-automation
$ cd tang-infra-automation
```

All further instructions assumes you are in the code directory eg. `tang-infra-automation`

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
Note: rhel image should be rhel-86

## Start Install

Run the following commands from within the directory.

```
$ terraform init
$ terraform plan --var-file=var.tfvars
$ terraform apply -var-file var.tfvars
```
Note: Terraform Version should be ~>0.13.0

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


#### Fetch Keys from Bastion Node

Once the deployment is completed successfully, you can connect to bastion node and fetch keys for every tang server 
```
$ cat /root/tang-keys/allnodes.txt
```

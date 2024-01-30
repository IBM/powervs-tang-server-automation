# How to use var.tfvars

- [How to use var.tfvars](#how-to-use-vartfvars)
    - [Introduction](#introduction)
        - [IBM Cloud Details](#ibm-cloud-details)
        - [Tang Cluster Details](#tang-cluster-details)

## Introduction

This guide gives an overview of the various terraform variables that are used for the deployment.
The default values are set in [variables.tf](../variables.tf)

### IBM Cloud Details

These set of variables specify the access key and PowerVS location details.

```
ibmcloud_api_key    = "xyzaaaaaaaabcdeaaaaaa"
ibmcloud_region     = "xya"
ibmcloud_zone       = "abc"
service_instance_id = "abc123xyzaaaa"
```

You'll need to create an API key to use the automation code. Please refer to the following instructions to generate API
key - https://cloud.ibm.com/docs/account?topic=account-userapikey

In order to retrieve the PowerVS region, zone and instance specific details please use the IBM Cloud CLI.

1. Run `ibmcloud pi workspace list`. It will list the service instance names with IDs.
2. The ID will be of the form
   ```
   crn:v1:bluemix:public:power-iaas:eu-de-1:a/65b64c1f1c29460e8c2e4bbfbd893c2c:360a5df8-3f00-44b2-bd9f-d9a51fe53de6::
   ```
3. The **6th** field is the **ibmcloud_zone** and **8th** field is the **service_instance_id**
   ```
   $ echo "crn:v1:bluemix:public:power-iaas:eu-de-1:abc:1234-cdef-defg-bd9f-dghjk::" | cut -f6,8 -d":"
   eu-de-1:1234-cdef-defg-bd9f-dghjk
   ```

   Following are the region and zone mapping:

   | ibmcloud_region | ibmcloud_zone  |
         |-----------------|----------------|
   | eu-de           | eu-de-1        |
   | eu-de           | eu-de-2        |
   | dal             | dal12          |
   | lon             | lon04          |
   | lon             | lon06          |
   | syd             | syd04          |
   | sao             | sao01          |
   | tor             | tor01          |
   | tok             | tok04          | 
   | us-east         | us-east        |

   NOTE:  us-east is Washington, DC datacenter.

### Tang Cluster Details

These set of variables specify the cluster capacity.

Change the values as per your requirement.
The defaults (recommended config) should suffice for most of the common use-cases.

```
bastion = { memory = "16", processors = "1", "count" = 1 }
```

Note: The bastion memory and processor will be used for the tang server VMs because it will have the same configuration.

This variable specifies the count of tang servers to be used.

```
tang_count = 3
```

These set of variables specify the RHEL and RHCOS boot image names. These images should have been already imported in
your PowerVS service instance.
Change the image names according to your environment. Ensure that you use the correct RHCOS image specific to the
pre-release version

```
rhel_image_name     = "<rhel_or_centos_image-name>"
rhcos_image_name    = "<rhcos-image-name>"
```

Note that the boot images should have a minimum disk size of 120GB

These set of variables should be provided when RHCOS image should be imported from public bucket of cloud object storage
to your PowerVS service instance

```
rhcos_import_image              = true                                                   # true/false (default=false)
rhcos_import_image_filename     = "rhcos-411-85-202203181612-0-ppc64le-powervs.ova.gz"   # RHCOS boot image file name available in cloud object storage
rhcos_import_image_storage_type = "tier1"                                                # tier1/tier3 (default=tier1) Storage type in PowerVS where image needs to be uploaded
```

This variable specifies the name of the private network that is configured in your PowerVS service instance.

```
network_name        = "ocp-net-priv"
```

These set of variables specify the type of processor and physical system type to be used for the VMs.
Change the default values according to your requirement.

```
processor_type      = "shared"  #Can be shared or dedicated
system_type         = "s922"    #Can be either s922 or e980
```

These set of variables specify the username and the SSH key to be used for accessing the bastion node.

```
rhel_username               = "root"  #Set it to an appropriate username for non-root user access
public_key_file             = "data/id_rsa.pub"
private_key_file            = "data/id_rsa"
```

rhel_username is set to root. rhel_username can be set to an appropriate username having superuser privileges with no
password prompt.
Please note that only OpenSSH formatted keys are supported. Refer to the following links for instructions on creating
SSH key based on your platform.

- Windows 10 - https://phoenixnap.com/kb/generate-ssh-key-windows-10
- Mac OSX - https://www.techrepublic.com/article/how-to-generate-ssh-keys-on-macos-mojave/
- Linux - https://www.siteground.com/kb/generate_ssh_key_in_linux/

Create the SSH key-pair and keep it under the `data` directory

These set of variables specify the RHEL subscription details, RHEL subscription supports two methods: one is using
username and password, the other is using activation key.
This is sensitive data, and if you don't want to save it on disk, use environment variables `RHEL_SUBS_USERNAME`
and `RHEL_SUBS_PASSWORD` and pass them to `terraform apply` command as shown in
the [Quickstart guide](./quickstart.md#setup-terraform-variables).
If you are using CentOS as the bastion image, then leave these variables as-is.

```
rhel_subscription_username  = "user@test.com"
rhel_subscription_password  = "mypassword"
```

Or define following variables to use activation key for RHEL subscription:

```
rhel_subscription_org = "org-id"
rhel_subscription_activationkey = "activation-key"
```

This variable specifies the number of hardware threads (SMT) that's used for the bastion node.
Default setting should be fine for majority of the use-cases.

```
rhel_smt                    = 4
```

### Using IBM Cloud Services

This variable specify if bastion or tang node should poll for the Health Status to be OK or WARNING. Default is OK.

```
bastion_health_status       = "OK"
tang_health_status    = "WARNING"
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.46.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./modules/1_bastion/ | n/a |
| <a name="module_fips"></a> [fips](#module\_fips) | ./modules/3_fips | n/a |
| <a name="module_nbde"></a> [nbde](#module\_nbde) | ./modules/2_nbde | n/a |

## Resources

| Name | Type |
|------|------|
| [random_id.label](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description                                                                                                                                                                                     | Type | Default                                                                        | Required |
|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------|--------------------------------------------------------------------------------|:--------:|
| <a name="input_ansible_repo_name"></a> [ansible\_repo\_name](#input\_ansible\_repo\_name) | The Ansible repository name                                                                                                                                                                     | `string` | `"ansible-2.9-for-rhel-8-ppc64le-rpms"`                                        | no |
| <a name="input_bastion"></a> [bastion](#input\_bastion) | n/a                                                                                                                                                                                             | `map` | <pre>{<br>  "count": 1,<br>  "memory": "16",<br>  "processors": "1"<br>}</pre> | no |
| <a name="input_bastion_health_status"></a> [bastion\_health\_status](#input\_bastion\_health\_status) | Specify if bastion should poll for the Health Status to be OK or WARNING. Default is OK.                                                                                                        | `string` | `"OK"`                                                                         | no |
| <a name="input_bastion_public_ip"></a> [bastion\_public\_ip](#input\_bastion\_public\_ip) | The bastion\_public\_ip is the IP used to deploy the NBDE servers when the bastion.count = 0, and uses a pre-existing bastion host                                                              | `string` | `""`                                                                           | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | n/a                                                                                                                                                                                             | `string` | `""`                                                                           | no |
| <a name="input_connection_timeout"></a> [connection\_timeout](#input\_connection\_timeout) | Timeout in minutes for SSH connections                                                                                                                                                          | `number` | `30`                                                                           | no |
| <a name="input_dns_forwarders"></a> [dns\_forwarders](#input\_dns\_forwarders) | n/a                                                                                                                                                                                             | `string` | `"8.8.8.8; 8.8.4.4"`                                                           | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Domain name to use to setup the cluster. A DNS Forward Zone should be a registered in IBM Cloud if use\_ibm\_cloud\_services = true                                                             | `string` | `"ibm.com"`                                                                    | no |
| <a name="input_fips_compliant"></a> [fips\_compliant](#input\_fips\_compliant) | Set to true to enable usage of FIPS for the deployment.                                                                                                                                         | `bool` | `false`                                                                        | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API key associated with user's identity                                                                                                                                               | `string` | `"<key>"`                                                                      | no |
| <a name="input_ibmcloud_region"></a> [ibmcloud\_region](#input\_ibmcloud\_region) | The IBM Cloud region where you want to create the resources                                                                                                                                     | `string` | `""`                                                                           | no |
| <a name="input_ibmcloud_zone"></a> [ibmcloud\_zone](#input\_ibmcloud\_zone) | The zone of an IBM Cloud region where you want to create Power System resources                                                                                                                 | `string` | `""`                                                                           | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | n/a                                                                                                                                                                                             | `string` | `""`                                                                           | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | The name of the network to be used for deploy operations                                                                                                                                        | `string` | `"my_network_tang"`                                                            | no |
| <a name="input_private_key"></a> [private\_key](#input\_private\_key) | content of private ssh key                                                                                                                                                                      | `string` | `""`                                                                           | no |
| <a name="input_private_key_file"></a> [private\_key\_file](#input\_private\_key\_file) | Path to private key file                                                                                                                                                                        | `string` | `"data/id_rsa"`                                                                | no |
| <a name="input_private_network_mtu"></a> [private\_network\_mtu](#input\_private\_network\_mtu) | MTU value for the private network interface on RHEL and RHCOS nodes                                                                                                                             | `number` | `1450`                                                                         | no |
| <a name="input_processor_type"></a> [processor\_type](#input\_processor\_type) | The type of processor mode (shared/dedicated)                                                                                                                                                   | `string` | `"shared"`                                                                     | no |
| <a name="input_proxy"></a> [proxy](#input\_proxy) | External Proxy server details in a map                                                                                                                                                          | `object({})` | `{}`                                                                           | no |
| <a name="input_public_key"></a> [public\_key](#input\_public\_key) | Public key                                                                                                                                                                                      | `string` | `""`                                                                           | no |
| <a name="input_public_key_file"></a> [public\_key\_file](#input\_public\_key\_file) | Path to public key file                                                                                                                                                                         | `string` | `"data/id_rsa.pub"`                                                            | no |
| <a name="input_rhel_image_name"></a> [rhel\_image\_name](#input\_rhel\_image\_name) | Name of the RHEL image that you want to use for the bastion node                                                                                                                                | `string` | `"rhel-8.6"`                                                                   | no |
| <a name="input_rhel_smt"></a> [rhel\_smt](#input\_rhel\_smt) | SMT value to set on the bastion node. Eg: on,off,2,4,8                                                                                                                                          | `number` | `4`                                                                            | no |
| <a name="input_rhel_subscription_activationkey"></a> [rhel\_subscription\_activationkey](#input\_rhel\_subscription\_activationkey) | n/a                                                                                                                                                                                             | `string` | `"The subscription key for activating rhel"`                                   | no |
| <a name="input_rhel_subscription_org"></a> [rhel\_subscription\_org](#input\_rhel\_subscription\_org) | n/a                                                                                                                                                                                             | `string` | `""`                                                                           | no |
| <a name="input_rhel_subscription_password"></a> [rhel\_subscription\_password](#input\_rhel\_subscription\_password) | n/a                                                                                                                                                                                             | `string` | `""`                                                                           | no |
| <a name="input_rhel_subscription_username"></a> [rhel\_subscription\_username](#input\_rhel\_subscription\_username) | n/a                                                                                                                                                                                             | `string` | `""`                                                                           | no |
| <a name="input_rhel_username"></a> [rhel\_username](#input\_rhel\_username) | n/a                                                                                                                                                                                             | `string` | `"root"`                                                                       | no |
| <a name="input_service_instance_id"></a> [service\_instance\_id](#input\_service\_instance\_id) | The cloud instance ID of your account                                                                                                                                                           | `string` | `""`                                                                           | no |
| <a name="input_setup_squid_proxy"></a> [setup\_squid\_proxy](#input\_setup\_squid\_proxy) | Flag to install and configure squid proxy server on bastion node                                                                                                                                | `bool` | `false`                                                                        | no |
| <a name="input_ssh_agent"></a> [ssh\_agent](#input\_ssh\_agent) | Enable or disable SSH Agent. Can correct some connectivity issues. Default: false                                                                                                               | `bool` | `false`                                                                        | no |
| <a name="input_system_type"></a> [system\_type](#input\_system\_type) | The type of system (s922/e980)                                                                                                                                                                  | `string` | `"s922"`                                                                       | no |
| <a name="input_tang"></a> [tang](#input\_tang) | n/a                                                                                                                                                                                             | `map` | <pre>{<br>  "count": 3,<br>  "memory": "16",<br>  "processors": "1"<br>}</pre> | no |
| <a name="input_tang_health_status"></a> [tang\_health\_status](#input\_tang\_health\_status) | n/a                                                                                                                                                                                             | `string` | `"WARNING"`                                                                    | no |
| <a name="input_vm_id"></a> [vm\_id](#input\_vm\_id) | Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character Length cannot exceed 14 characters when combined with cluster\_id\_prefix | `string` | `""`                                                                           | no |
| <a name="input_vm_id_prefix"></a> [vm\_id\_prefix](#input\_vm\_id\_prefix) | Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character Should not be more than 14 characters                                     | `string` | `"infra-node"`                                                                 | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | n/a |
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
You'll need to create an API key to use the automation code. Please refer to the following instructions to generate API key - https://cloud.ibm.com/docs/account?topic=account-userapikey

In order to retrieve the PowerVS region, zone and instance specific details please use the IBM Cloud CLI.

1. Run `ibmcloud pi service-list`. It will list the service instance names with IDs.
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

These set of variables specify the RHEL and RHCOS boot image names. These images should have been already imported in your PowerVS service instance.
Change the image names according to your environment. Ensure that you use the correct RHCOS image specific to the pre-release version
```
rhel_image_name     = "<rhel_or_centos_image-name>"
rhcos_image_name    = "<rhcos-image-name>"
```
Note that the boot images should have a minimum disk size of 120GB

These set of variables should be provided when RHCOS image should be imported from public bucket of cloud object storage to your PowerVS service instance
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
rhel_username is set to root. rhel_username can be set to an appropriate username having superuser privileges with no password prompt.
Please note that only OpenSSH formatted keys are supported. Refer to the following links for instructions on creating SSH key based on your platform.
- Windows 10 - https://phoenixnap.com/kb/generate-ssh-key-windows-10
- Mac OSX - https://www.techrepublic.com/article/how-to-generate-ssh-keys-on-macos-mojave/
- Linux - https://www.siteground.com/kb/generate_ssh_key_in_linux/

Create the SSH key-pair and keep it under the `data` directory

These set of variables specify the RHEL subscription details, RHEL subscription supports two methods: one is using username and password, the other is using activation key.
This is sensitive data, and if you don't want to save it on disk, use environment variables `RHEL_SUBS_USERNAME` and `RHEL_SUBS_PASSWORD` and pass them to `terraform apply` command as shown in the [Quickstart guide](./quickstart.md#setup-terraform-variables).
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


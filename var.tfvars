### IBM Cloud details

ibmcloud_api_key    = "****"
ibmcloud_region     = "***"
ibmcloud_zone       = "***"
service_instance_id = "*****"

### VM Details
vm_id_prefix = "infra-tang-node"
vm_id        = ""

#cluster_id_prefix = "test-tang"
name_prefix = "infra-node4"

### This is default minimalistic config. For PowerVS processors are equal to entitled physical count
### So N processors == N physical core entitlements == ceil[N] vCPUs.
### Example 0.5 processors == 0.5 physical core entitlements == ceil[0.5] = 1 vCPU == 8 logical OS CPUs (SMT=8)
### Example 1.5 processors == 1.5 physical core entitlements == ceil[1.5] = 2 vCPU == 16 logical OS CPUs (SMT=8)
### Example 2 processors == 2 physical core entitlements == ceil[2] = 2 vCPU == 16 logical OS CPUs (SMT=8)
bastion = { memory = "16", processors = "1", "count" = 1 }
tang    = { memory = "16", processors = "1", "count" = 3, data_volume_count = 1, data_volume_size = 10 }

public_key = "****"

#public_key = file("${path.cwd}/data/id_rsa.pub")
#private_key = <<-EOT
#-----BEGIN OPENSSH PRIVATE KEY-----
#*************************************
#-----END OPENSSH PRIVATE KEY-----
#EOT

rhel_image_name            = "rhel-8.6"
processor_type             = "shared"
system_type                = "s922"
network_name               = "ocp-net-priv"
rhel_username              = "root"
public_key_file            = "data/id_rsa.pub"
private_key_file           = "data/id_rsa"
rhel_subscription_username = "******" #Leave this as-is if using CentOS as bastion image
rhel_subscription_password = "******" #Leave this as-is if using CentOS as bastion image
rhel_smt                   = 4

bastion_health_status = "WARNING"
tang_health_status    = "WARNING"

# Enables FIPS in the RHEL or CENTOS PVM instance.
fips_compliant = false

# Testing

The [`powervs-tang-server-automation` project](https://github.com/IBM/powervs-tang-server-automation) provides Terraform
based automation code to help with the deployment
of [Network Bound Disk Encryption (NBDE)](https://github.com/linux-system-roles/nbde_server)
on [IBM® Power Systems™ Virtual Server on IBM Cloud](https://www.ibm.com/cloud/power-virtual-server).

The project tests in layers - linting (valdity testing) and manual End-to-end testing.

**Test Cases**

1. Deploy with FIPS
2. Deploy without FIPS.
3. Deploy with an existing bastion
4. Deploy without an existing bastion

These are tested with RHEL8.6, RHEL9.0, Centos 8 Stream.

Backup and Restore are beyond the purpose of this automation, and customers are expected to test/run these
Non-Functional aspects as part of their operations.

# Testing during `development`

1. Bastion Module: Testing `Deploy the Bastion`

    1. Setup the `var.tfvars` file per the `modules/1_bastion/variables.tf`
    2. Create a temporary `versions.tf` file in the module
    3. Run the following commands:
        1. `terraform init`
        2. `terraform plan -var-file=data/var.tfvars`
        3. `terraform apply -var-file=data/var.tfvars`
        4. `terraform destroy -var-file=data/var.tfvars`
    4. Review the output for success and you see output like:

```terraform
Apply complete! Resources : 8 added, 0 changed, 0 destroyed.

Outputs :

bastion_instance_ids = "4145f3a8-dfe9-4b2e-8c5e-729d8a3daf9a"
bastion_ip = [
"192.168.100.123",
]
bastion_public_ip = [
"192.111.111.111",
]
```

2. NBDE Module: Testing `Deploy the Network Bound Disk Encryption`

    1. Setup the `var.tfvars` file per the `modules/2_nbde/variables.tf`
    2. Add vars:
        2. `bastion_ip`
        3. `bastion_public_ip`
    3. Create a temporary `versions.tf` file in the module
    4. Run the following commands:
        1. `terraform init`
        2. `terraform plan -var-file=data/var.tfvars`
        3. `terraform apply -var-file=data/var.tfvars`
        4. `terraform destroy -var-file=data/var.tfvars`
    5. Review the output for success and you see output:

```terraform
Apply complete! Resources : 8 added, 0 changed, 0 destroyed.

Outputs :

tang_instance_ids = [
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/3392969a-3c36-40d8-a4fe-182faf822982",
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/37e1db68-6739-4f7e-a10a-4de15cfeb95d",
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/02df0b02-91ca-4697-96bf-fd797717ea7a",
]
tang_ips = "192.168.164.44,192.168.164.45,192.168.164.46"
```

3. FIPS Module: Testing `Configure FIPS and reboot`

1. Setup the `var.tfvars` file per the `modules/3_nbde/variables.tf`
2. Add vars:
    1. `bastion_instance_ids`
    3. `bastion_public_ip`
    4. `tang_instance_ids`
    5. `tang_count`
3. Create a temporary `versions.tf` file in the module
4. Run the following commands:
    1. `terraform init`
    2. `terraform plan -var-file=data/var.tfvars`
    3. `terraform apply -var-file=data/var.tfvars`
    4. `terraform destroy -var-file=data/var.tfvars`
5. Review the output for success and you see output:

```terraform
Apply complete! Resources : 8 added, 0 changed, 0 destroyed.

Outputs :

tang_instance_ids = [
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/3392969a-3c36-40d8-a4fe-182faf822982",
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/37e1db68-6739-4f7e-a10a-4de15cfeb95d",
"6d0e46e9-8232-4a75-a9d4-0e1248fa30c6/02df0b02-91ca-4697-96bf-fd797717ea7a",
]
tang_ips = "192.168.164.44,192.168.164.45,192.168.164.46"
```
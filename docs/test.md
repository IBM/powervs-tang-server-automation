# Testing

The [`powervs-tang-server-automation` project](https://github.com/IBM/powervs-tang-server-automation) provides Terraform
based automation code to help with the deployment of [Network Bound Disk Encryption (NBDE)](https://github.com/linux-system-roles/nbde_server)
on [IBM® Power Systems™ Virtual Server on IBM Cloud](https://www.ibm.com/cloud/power-virtual-server).

The project tests in layers - linting (valdity testing) and manual End-to-end testing. 

**Test Cases**

1. Deploy with FIPS
2. Deploy without FIPS. 
3. Deploy with an existing bastion
4. Deploy without an existing bastion

Backup and Restore are beyond the purpose of this automation, and customers are expected to test/run these Non-Functional aspects outside of the apply and destroy.
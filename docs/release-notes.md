# Release 0.0.1-next
-TBD-

# Release 0.0.1-alpha
1. Updated terraform to 1.46.0
2. Added dependabot to keep in sync with latest
3. Added Terraform verification workflow to ensure uniform docs and formatting
4. Added automation to confirm RSCT is installed
5. Converted the tang infrastructure for PowerVS to modules
    - 1_bastion deploys the bastion
    - 2_nbde deploys the operating system and configures NBDE
    - 3_fips configures fips on the operating system and reboots 
    - uses terraform ibm powervs [link](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/pi_instance_ip#external_ip)
6. Support for operating systems:
    - Centos 8.6,9.0
    - Red Hat Linux Enterprise 8.6, 9.0
7. Added support for bring-your-own-bastion
    - Must set the `bastion_ip`
    - Skips `fips` enablement on the bastion
8. Added docs/vars.tfvars-doc.md with a list / description of the variables.
9. Added documentation
    - Added a quickstart.md
    - Added prereq documents for client/powervs
    - Added doc on testing
    - Updated readme.md
    - Added docs on Rekeying all NBDE node and Rekeying single NBDE node
    - Backup
10. NBDE Server Automation Settings
   - Changed `nbde_server_port` port from the default 80 to 7500 
   - Changed `nbde_server_manage_firewall` to manage firewall 
   - Added support for rekeying and fetching
   - Use non-test path for automation
   - Changed relative paths used for the ansible automation
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

#### Fetch Keys from Bastion Node

Once the deployment is completed successfully, you can connect to bastion node and fetch keys for every tang server

```
$ cat /root/tang-keys/allnodes.txt
```

### Destroy Tang Server

Destroy the Tang Cluster

```
$ terraform destroy -var-file var.tfvars
```

If you encounter errors - use `TF_LOG=debug <COMMAND>`
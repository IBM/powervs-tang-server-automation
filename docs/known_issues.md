# Known Issues

This page lists the known issues and potential next steps when deploying `tang` in Power Systems Virtual Server (
PowerVS)

## Terraform apply returns the following error

- **Error**:
  > timeout - last error: Error connecting to bastion: dial tcp 161.156.139.82:22: connect: operation timed out

- **Cause**: The public network attached to bastion is not reachable.

  Ping to the public/external IP of bastion node (eg. 161.156.139.82) will not return any response

- **Workaround**: Re-run TF again and if it doesn't help, destroy the TF resources and re-run.

  If it doesn't work, then please open a support case with IBM Cloud to fix issue with reachability of public IP for
  PowerVS instance.

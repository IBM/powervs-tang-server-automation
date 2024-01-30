# **PowerVS Prerequisites**
----------------------

## Create an IBM Cloud account.

If you don’t already have one, you need a paid IBM Cloud account to create your Power Systems Virtual Server instance.
To create an account, go to: [cloud.ibm.com](https://cloud.ibm.com).

## Create an IBM Cloud account API key

Please refer to the following [documentation](https://cloud.ibm.com/docs/account?topic=account-userapikey) to create an
API key.

## Create Power Systems Virtual Server Service Instance

After you have an active IBM Cloud account, you can create a Power Systems Virtual Server service. To do so, perform the
following steps:

1. Log in to the IBM Cloud [dashboard](https://cloud.ibm.com/) and search for **Power** in the catalog.
   &nbsp;
2. Select **Power Systems Virtual Server**
   &nbsp;
3. Fill required details
   &nbsp;
   Provide a meaningful name for your instance in the **Service name** field and select the proper **resource group**.
   More details on resource groups is available from the
   following [link](https://cloud.ibm.com/docs/account?topic=account-rgs)
   &nbsp;
4. Create Service
   Click on "**Create**" to create the service instance.
   &nbsp;

## Create Private Network

A private network is required for your OpenShift cluster. Perform the following steps to create a private network for
the Power Systems Virtual Server service instance created in the previous step.

1. Select the previously created "**Service Instance**" and create a private subnet by clicking "**Subnets**" and
   providing the required inputs.
   &nbsp;
   **Note:** If you see a screen displaying CRN and GUID, then click "View full details" to access the "Subnet" creation
   page.
   &nbsp;
2. Provide the network details and click **"Create subnet"**
   &nbsp;
   On successful network creation, the following output will be displayed in the dashboard.

### Enable communication over the private network

Two options are available to enable communication over the private network.

*Option 1*

You can use the IBM Cloud CLI with the latest power-iaas plug-in (version 0.3.4 or later) to enable a private network
communication.
Refer: https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-managing-cloud-connections

This requires attaching the private network to an IBM Cloud Direct Link Connect 2.0 connection.
Perform the following steps to enable private network communication by attaching to the Direct Link Connect 2.0
connection.

- Select a specific service instance
  You’ll need the CRN of the service instance created earlier (for example, ocp-powervs-test-1).

```
ibmcloud pi workspace target crn:v1:bluemix:public:power-iaas:tok04:a/65b64c1f1c29460e8c2e4bbfbd893c2c:e4bb3d9d-a37c-4b1f-a923-4537c0c8beb3::
```

- Get the ID of the private network

```
ibmcloud pi network ls | grep -w ocp-net


ID           93cc386a-53c5-4aef-9882-4294025c5e1f
Name         ocp-net
Type         vlan
VLAN         413
CIDR Block   192.168.201.0/24
IP Range     [192.168.201.2  192.168.201.254]
Gateway      192.168.201.1
DNS          127.0.0.1

```

You’ll need the ID in subsequent steps.

### Uploading to IBM Cloud Object Storage

- **Create IBM Cloud Object Storage service and bucket**
  Please refer to the
  following [link](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage)
  for instructions to create IBM Cloud Object Storage service and required storage bucket to upload the OVA images.
  &nbsp;
- **Create secret and access keys with Hash-based Message Authentication Code (HMAC)**
  Please refer to the
  following [link](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-uhc-hmac-credentials-main)
  for instructions to create the keys required for importing the images into your PowerVS service instance.
  &nbsp;
- **Upload the OVA image to Cloud Object storage bucket**
  Please refer to the
  following [link](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload) for uploading the
  OVA image to the respective bucket. Alternatively you can also use the
  following [tool](https://github.com/ppc64le-cloud/pvsadm).

### Importing the images in PowerVS

Choose the previously created PowerVS **"Service Instance"**, click **"View full details"** and select **"Boot images"**
.
Click the **"Import image"** option and fill the requisite details like image name, storage type and cloud object
storage details.

Example screenshot showing import of RHEL image that is used for bastion
&nbsp;
![Image Import-RHEL](https://raw.githubusercontent.com/ocp-power-automation/ocp4-upi-powervs/master/docs/media/image-import1.png)
&nbsp;

Your PowerVS service instance is now ready for the NBDE infrastructure.

Source: [ocp-power-automation/ocp4-upi-powervs](https://raw.githubusercontent.com/ocp-power-automation/ocp4-upi-powervs/master/docs/ocp_prereqs_powervs.md)

# CP4M-Turbonomic-Composable-Install
Improved Install Script for IBM-Turbonomic PPA Using Composable

## Install
**Note that this will also install the [IBM Composable Operator](https://operatorhub.io/operator/composable-operator) into the `turbonomic` namespace.**

First follow [these instructions](https://docs.openshift.com/container-platform/4.5/registry/accessing-the-registry.html#registry-accessing-directly_accessing-the-registry) to gain root access to one of your cluster's nodes and login to the `oc` cli tool and the internal image registry using your cluster-admin credential.

Then download the IBM Turbonomic PPA there and then extract it:
```
tar -xvf ibm_turbonomic_x86.tar
```

Then cd into the newly created `turbonomic` directory, set the REPOSITORY environment variable to match the `turbonomic` namespace in the internal OpenShift Registry and then download and run the `install_using_composable.sh` script from this Github repo. You will be asked to confirm that you have accepted the license agreement at the beginning of the installation script:

```
cd turbonomic
export REPOSITORY=image-registry.openshift-image-registry.svc:5000/turbonomic
curl "https://raw.githubusercontent.com/CloudPak-SDK/CP4M-Turbonomic-Composable-Install/main/install_using_composable.sh" -LO
chmod +x install_using_composable.sh
./install_using_composable.sh
```

## Create the Turbonomic Administrator User and Grant Roles to CP4M Users
TODO




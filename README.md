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
The installation script should finish with a similar to this:
```
Turbonomic Console URL is: https://api-turbonomic.apps.<my-cluster-domain>
```
Proceed to this URL in your browser. You will be asked to create an `Administrator` user for the new Turbonomic installation.

![image](https://user-images.githubusercontent.com/62120488/113747837-6b719500-96cd-11eb-909c-47a18659c107.png)

Create the `Adminstrator` user and then login as `Administrator`. Click `Let's Go` and then `Import License`. Then select and upload your license file. Once you have completed the inital setup, go to the settings tab and then enter the `User Management` menu. From here go to the `External Authentication` section and use the `New External User` and `New External Group` options to assign roles to CP4M users.

![image](https://user-images.githubusercontent.com/62120488/113749210-04ed7680-96cf-11eb-8aab-041b6e395e2c.png)

Now log out of Turbonomic and proceed to the CP4M UI and login there. You should now see the option `Application Resource Manager` under the `Monitor Health` section of the CP4M menu.

![image](https://user-images.githubusercontent.com/62120488/113748841-93152d00-96ce-11eb-9c7e-4a602ad92813.png)

Click this option to open Turbonomic using SSO login.



# Bicep Framework for deploying CBS on Azure

## Prerequisites
- bash
- Windows (**WSL recommended**)/Linux/MacOS
- `az-cli`, `bicep-cli`, `jq` (all should get installed with setup-machine script)

## Installation


1. Add permissions to execute scripts:
```bash
$ chmod +x 00-setup-machine.sh 01-deploy-prerequisities.sh 02-deploy-cbs.sh 03-deploy-test-vm.sh deploy-e2e-demo.sh
```
1. Run the `00-setup-machine.sh` script to install all required tooling and log into Azure.


## Usage

### Option A - E2E DEMO Deployment

This repository contains a script `deploy-e2e-demo.sh` that combines all modules in the repository and enables easy testing and hands-on experience of the CBS (Pure Cloud Block Store) on Azure. 
With just one script, you can quickly set up and run a test environment to explore the features and capabilities of the CBS.

The script includes all required CBS resources and sets up a test Windows SQL Server VM with mounted CBS volumes via iSCSI.

To use this script:
1. rename the file `e2e-demo-params.sh.example` to `e2e-demo-params.sh` 
1. enter the necessary values into the `e2e-demo-params.sh` file
1. execute the script `./deploy-e2e-demo.sh`



### Option B - Bicep Modules

The repository also contains 3 modules for deploying CBS on Azure using infrastructure-as-code [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep) templates.

These modules can be customized and modified, for example, to be incorporated into your landing zone templates.


#### Module #01 - CBS Prerequisites

The script `01-deploy-prerequisities.sh` (Bicep template file `prerequisities.bicep`) deploys all required resources for CBS:
- vNET resource, including all required subnets
- public IP address + NAT gateway for `system` subnet
- user managed identity
- a custom role definition
- a role assignment

To use prepare inputs in a parameter file `01-prereq.bicepparam` (you can use `01-prereq.bicepparam.example`) and execute `01-deploy-prerequisities.sh` script.




#### Module #02 - CBS Managed App

The script `02-deploy-cbs.sh` (Bicep template file `cbs-managed-app.bicep`) deploys CBS managed application itself.

To use prepare inputs in a parameter file `02-cbs.bicepparam` and execute `02-deploy-cbs.sh` script.
Please keep in mind, you need to pass into the parameter file `02-cbs.bicepparam` some outputs from `01-deploy-prerequisities.sh` script.

> [!NOTE]  
> If you intend to use only a Bicep template for the programmatic deployment of CBS, you must also accept the Azure Marketplace license for the given product/plan. Since Azure does not support accepting licenses via Bicep templates, you must accept the license using PowerShell or Azure CLI before executing the Bicep deployment.

#### Module #03 - Test VM

The script `03-deploy-test-vm.sh` deploys a test Windows Server VM with MS SQL server installed.

It automatically creates 3 volumes in the CBS array, and mount them on the VM via iSCSI to be used by SQL server.

## Limitations / Troubleshooting


### one common vNET
01-prereq:
TODO: only one common vNET support, could be in another RG but only one

### custom role/assignment re-deployment fails
TODO: only onetimer, manual remove

### test VM - sql extension fails
TODO: It's because of existing volumes in CBS, just delete them and execute the deployment again.

## Disclaimer

*The sample script and documentation are provided AS IS and are not supported by
the author or the author's employer, unless otherwise agreed in writing. You bear
all risk relating to the use or performance of the sample script and documentation.* 

*The author and the author's employer disclaim all express or implied warranties
(including, without limitation, any warranties of merchantability, title, infringement
or fitness for a particular purpose). In no event shall the author, the author's employer
or anyone else involved in the creation, production, or delivery of the scripts be liable
for any damages whatsoever arising out of the use or performance of the sample script and
documentation (including, without limitation, damages for loss of business profits,
business interruption, loss of business information, or other pecuniary loss), even if
such person has been advised of the possibility of such damages.*


## Authors

- [Vaclav Jirovsky](https://blog.vjirovsky.cz)
- [David Stamen](https://davidstamen.com)
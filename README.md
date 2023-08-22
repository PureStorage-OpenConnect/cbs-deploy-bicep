# Bicep framework for deploying CBS on Azure - EXPERIMENTAL 

## Prerequisites
- bash
- Windows/Linux/MacOS
- `az-cli`, `bicep-cli`, `jq` (all should get installed with setup-machine script)

## Installation

1. Add permissions to execute scripts:
```bash
$ chmod +x 00-setup-machine.sh 01-deploy-prerequisities.sh 02-deploy-cbs.sh 03-deploy-test-vm.sh
```
1. Run the `00-setup-machine.sh` script to install all required tooling.


## Usage

### 01 - CBS Prerequisites

The script `01-deploy-prerequisities.sh` deploys all required resources for CBS:
- vNET including subnets
- IP address + NAT gateway for `system` subnet
- user managed identity
- a custom role definition
- a role assignment

To use prepare inputs in a parameter file `01-prereq.bicepparam` (you can use `01-prereq.bicepparam.examle`) and execute `01-deploy-prerequisities.sh` script.


### 02 - CBS Managed App

The script `02-deploy-cbs.sh` deploys CBS managed application itself.

To use prepare inputs in a parameter file `02-cbs.bicepparam` and execute `02-deploy-cbs.sh` script.
Please keep in mind, you need to pass into the parameter file `02-cbs.bicepparam` some outputs from `01-deploy-prerequisities.sh` script.

### 03 - Test VM (WiP)
TODO: description
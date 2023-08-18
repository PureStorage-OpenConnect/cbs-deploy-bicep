#!/bin/bash
set -e
SHOW_DEBUG_OUTPUT=false

source $(dirname $0)/script-modules/common.sh


# Read the bicep parameters
parametersfilename='./03-test-vm.bicepparam'

source $(dirname $0)/script-modules/ascii-logo.sh

echo -e "
------------------------------------------------------------
        Pure Cloud Block Store - Test VM Deployment
                (c) 2023 Pure Storage
                        v$CLI_VERSION
------------------------------------------------------------
"

echo -e "${C_BLUE3}${C_GREY85}
[Step #1] Getting your current IP address...

"

myIpAddress=(`curl ifconfig.me 2> /dev/null`)

if [ -z "$myIpAddress" ]; then
    echoerr "Something failed during gathering public IP address!"
    exit 1;
else
    echosuccess "Your public IP address: $myIpAddress"
    echo "There will be a network security group restricting access just for your IP address."
fi



paramsJson=`bicep build-params $parametersfilename --stdout  | jq -r ".parametersJson"`

tmpJsonFilename='tmp03.json'
subscriptionId=`echo $paramsJson | jq -r ".parameters.subscriptionId.value"`
resourceGroupName=`echo $paramsJson | jq -r ".parameters.resourceGroupName.value"`
(echo $paramsJson | sed "s/\$myIpAddress/$myIpAddress/") > $tmpJsonFilename



echo -e "${C_BLUE3}${C_GREY85}
[Step #2] Deploying VM into subscription $subscriptionId into RG ${resourceGroupName}:${NO_FORMAT}

"


# Deploy our infrastructure
output=$(az deployment group create \
  --name "test-vm-deploy-sh" \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --template-file "templates/test-vm.bicep" \
  --parameters @$tmpJsonFilename

  )

rm $tmpJsonFilename

vmIpAddress=`echo $output | jq -r '.properties.outputs.vmIpAddress.value'`
adminUsername=`echo $output | jq -r '.properties.outputs.adminUsername.value'`
adminPassword=`echo $output | jq -r '.properties.outputs.adminPassword.value'`



echo ""
echo ""
echo ""
echosuccess "The deployment of DEMO Virtual Machine has been completed."
echo ""

echo " ******** VM parameters ********"

echo ""
echo ""
echo " -------- Endpoints for management -------------"
echo "|  VM Public IP address    |  ${vmIpAddress}"
echo "|  Admin username          |  ${adminUsername}"
echo "|  Admin password          |  ${adminPassword}"
echo " -----------------------------------------------"
echo ""
echo ""

# if running in Windows Subsystem in Linux
if [ -n "${WSLENV}" ];
then
    echo -e "${C_BLUE3}${C_GREY85}
[Step #3][Optional] Opening Remote Desktop Connection session into the test VM:${NO_FORMAT}
"
    echo " Adding credentials to cmdkey:"
    cmdkey.exe /generic:"$vmIpAddress" /user:"$adminUsername" /pass:"$adminPassword"
    echo " Trying to open RDP connection..."
    mstsc.exe /v:$vmIpAddress
    echosuccess 'The RDP connection should be opened.'

    echo "For new RDP session use command:
> mstsc.exe /v:$vmIpAddress"
fi


# running in MacOS
if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo " MacOS detected - trying to open Microsoft Remote Desktop app:"
    open -a /Applications/Microsoft\ Remote\ Desktop.app "rdp://full%20address=s:$vmIpAddress:3389&username=$adminUsername&audiomode=i:2&disable%20themes=i:1"
fi

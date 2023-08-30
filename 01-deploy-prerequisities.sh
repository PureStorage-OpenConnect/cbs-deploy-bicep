#!/bin/bash
set -e
SHOW_DEBUG_OUTPUT=false


source $(dirname $0)/script-modules/common.sh

# Read the bicep parameters
parametersfilename='01-prereq.bicepparam'

source $(dirname $0)/script-modules/ascii-logo.sh

echo -e "
------------------------------------------------------------
    Pure Cloud Block Storage - Prerequisites Deployment 
                (c) 2023 Pure Storage
                        v$CLI_VERSION
------------------------------------------------------------
"


paramsJson=`bicep build-params $parametersfilename --stdout  | jq -r ".parametersJson"`


location=`echo $paramsJson | jq -r ".parameters.location.value"`
subscriptionId=`echo $paramsJson | jq -r ".parameters.subscriptionId.value"`
resourceGroupName=`echo $paramsJson | jq -r ".parameters.resourceGroupName.value"`

echo -e "${C_BLUE3}${C_GREY85}
[Step #1] Deploying required infrastructure in subscription $subscriptionId:${NO_FORMAT}

"
echo "
Subscription Id: $subscriptionId
RG name: $resourceGroupName
Location: $location

"


# Deploy our infrastructure
output=$(az deployment sub create \
  --name "CBS-deploy-prereq-bicep-sh" \
  --location $location \
  --subscription $subscriptionId \
  --template-file "templates/prerequisites.bicep" \
  --parameters $parametersfilename
  )
  

subscriptionId=`echo $output | jq -r '.properties.outputs.subscriptionId.value'`
mainRgName=`echo $output | jq -r '.properties.outputs.mainRgName.value'`
arrayVnetId=`echo $output | jq -r '.properties.outputs.arrayVnetId.value'`
arrayVnetName=`echo $output | jq -r '.properties.outputs.arrayVnetName.value'`
vnetMngmtUserManagedIdentityId=`echo $output | jq -r '.properties.outputs.vnetMngmtUserManagedIdentityId.value'`

echo " -------------------------------------------------------"
echo "|  Subscription Id        |  ${subscriptionId} "
echo "|  Main resource group    |  ${mainRgName}"
echo " -------------------------------------------------------"
echo ""
echo ""
echo " -------- Array virtual network (vNET) --------"
echo "|  vNET name    |  ${arrayVnetName}"
echo "|  vNET id      |  ${arrayVnetId}"
echo " ----------------------------------------------"


echo " -------- User managed identity --------"
echo "|  Resource Id    |  ${vnetMngmtUserManagedIdentityId}"
echo " ----------------------------------------------"


echo ""
echo ""
echo ""
echosuccess "[COMPLETED] The deployment of prerequisities has been completed. Now you can proceed to deployment of CBS with **02-deploy-cbs.sh** script file."
echo ""
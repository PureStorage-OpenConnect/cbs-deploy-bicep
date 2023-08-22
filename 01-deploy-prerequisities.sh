#!/bin/bash
set -e
SHOW_DEBUG_OUTPUT=false

escape_quotes(){
    echo $@ | sed s/'"'/'\\"'/g
}


echoerr() { printf "\033[0;31m%s\n\033[0m" "$*" >&2; }
echosuccess() { printf "\033[0;32m%s\n\033[0m" "$*" >&2; }


# Read the bicep parameters
parametersfilename='01-prereq.bicepparam'

echo "           "
echo "           "
echo "  CBS DEPLOYMENT - PREREQUISITES   "
echo "           "
echo "           "
echo "           "


echo "Deploying required infrastructure"

paramsJson=`bicep build-params $parametersfilename --stdout  | jq -r ".parametersJson"`


location=`echo $paramsJson | jq -r ".parameters.location.value"`
subscriptionId=`echo $paramsJson | jq -r ".parameters.subscriptionId.value"`

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
echosuccess "The deployment of prerequisities has been completed. Now you can proceed to deployment of CBS itself with *02-deploy-cbs.sh*."
echo ""
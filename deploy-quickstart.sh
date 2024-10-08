#!/bin/bash
set -e
SHOW_DEBUG_OUTPUT=false
source $(dirname $0)/quickstart-params.sh

source $(dirname $0)/script-modules/common.sh


source $(dirname $0)/script-modules/ascii-logo.sh

echo -e "
------------------------------------------------------------
        Pure Cloud Block Store - QuickStart DEMO Deployment
                (c) 2023 Pure Storage
                        v$CLI_VERSION
------------------------------------------------------------
"



# deploy prereqs


echo -e "${C_BLUE3}${C_GREY85}
[Step #1] Deploying required infrastructure in subscription ${subscriptionId}:${NO_FORMAT}"
echo "
RG name: $resourceGroupName
Location: $location

"


# Deploy our infrastructure
output=$(az deployment sub create \
  --name "CBS-E2E-$location-deploy-prereq-bicep-sh" \
  --location $location \
  --subscription $subscriptionId \
  --template-file "templates/prerequisites.bicep" \
  --parameters subscriptionId=$subscriptionId location=$location resourceGroupName=$resourceGroupName
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
echosuccess "[STEP COMPLETED] The deployment of prerequisities has been completed."
echo ""


# generate a SSH key and upload it into CBS and test VM
echo -e "${C_BLUE3}${C_GREY85}
[Step #2] Generating a SSH key for array management:${NO_FORMAT}"

sshOutput=$( { az sshkey create --name "ssh-cbs-test-$resourceGroupName" --resource-group $resourceGroupName; } 2>&1 )
sshPrivateKeyFile=`echo $sshOutput | grep -oP 'Private key is saved to "\K[^"]*'`
sshPublicKeyFile=`echo $sshOutput | grep -oP ' WARNING: Public key is saved to "\K[^"]*'`
sshDetails=`az sshkey show --name "ssh-cbs-test-$resourceGroupName" --resource-group $resourceGroupName`
sshPublicKeyInOpenSSHFormat=`echo $sshDetails | jq -r ".publicKey"`

sshPrivateKeyContentInBase64=`base64 $sshPrivateKeyFile -w 0`

echo "
Generated SSH key: $sshPublicKeyInOpenSSHFormat

"


# Read the bicep parameters for CBS
mainfilename='./templates/cbs-managed-app.bicep'
tmpfilename='./templates/tmp-e2e-02.bicepparam'
bicep_gen_raw=`bicep generate-params $mainfilename --output-format bicepparam --outfile $tmpfilename`
bicep_raw=`bicep build-params $tmpfilename --stdout`
paramsJson=`echo $bicep_raw | jq -r ".parametersJson"`


echo -e "${C_BLUE3}${C_GREY85}
[Step #3] Enabling CBS deployment for selected subscription $subscriptionId:${NO_FORMAT}

"

#in E2E demo we use the latest version
latestPlan=`(echo '{"plans":[';curl 'https://catalogapi.azure.com/offers/purestoragemarketplaceadmin.pure_cloud_block_store_product_deployment?api-version=2018-08-01-beta&market=US&includeStopSoldPlans=true&x-ms-effective-locale=en.en-us' 2> /dev/null  | jq -c '.plans | to_entries | .[] | select(.value.isStopSell == false) | select(.value.isHidden == false) | [.value.planId,.value.displayName, (.value.artifacts | .[] | select(.name == "DefaultTemplate").uri)]' | while IFS=$"\n" read -r line; do let "i=i+1";[[ $i == 1 ]] && add="" || add=","; echo $add;planId=\`echo $line | jq -r '.[0]'\`;displayName=\`echo $line | jq -r '.[1]'\`;uri=\`echo $line | jq -r '.[2]'\`;planVersion=\`curl "$uri" 2>/dev/null | jq -r '.resources | .[] | select(.type == "Microsoft.Solutions/applications").plan.version'\`;echo "{\"planId\":\"$planId\",\"planDisplayName\":\"$displayName\",\"planVersion\":\"$planVersion\"}";done;echo "]}") | jq '(.plans | sort_by(.planId) | reverse)[0]'`


AZURE_MARKETPLACE_PLAN_NAME=`echo $latestPlan | jq -r .planId`
AZURE_MARKETPLACE_PUBLISHER=`echo $bicep_raw | jq -r .templateJson | jq -r .parameters.azureMarketPlacePlanPublisher.defaultValue`
AZURE_MARKETPLACE_PLAN_OFFER=`echo $bicep_raw | jq -r .templateJson | jq -r .parameters.azureMarketPlacePlanOffer.defaultValue`
AZURE_MARKETPLACE_PLAN_VERSION=`echo $latestPlan | jq -r .planVersion`

AZURE_LOGGED_USER_ID=`az ad signed-in-user show | jq -r .id`
AZURE_LOGGED_USER_EMAIL=`az ad signed-in-user show | jq -r .mail`

enablementOutput=$(az vm image terms accept \
    --subscription $subscriptionId \
    --publisher $AZURE_MARKETPLACE_PUBLISHER \
    --offer $AZURE_MARKETPLACE_PLAN_OFFER \
    --plan $AZURE_MARKETPLACE_PLAN_NAME)

accepted=`echo $enablementOutput | jq -r '.properties.outputs.accepted.value'`
if [ $accepted ]
then 
    echosuccess "[STEP COMPLETED] Plan '$AZURE_MARKETPLACE_PLAN_NAME' enabled."
else
    echoerr "[Step #2][FAILURE] Enablement failed - offer: $AZURE_MARKETPLACE_PLAN_OFFER, plan: $AZURE_MARKETPLACE_PLAN_NAME, publisher: $AZURE_MARKETPLACE_PUBLISHER"
    echo $enablementOutput
    exit 1;
fi

echo -e "${C_BLUE3}${C_GREY85}
[Step #4] Deploying CBS managed app (~20mins):${NO_FORMAT}
"
jitApprovers="[{'displayName':'$AZURE_LOGGED_USER_EMAIL','id':'$AZURE_LOGGED_USER_ID','type':'user'}]"

# Deploy CBS
output=$(az deployment group create \
  --name "CBS-E2E-$location-deploy-sh" \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --template-file "templates/cbs-managed-app.bicep" \
  --parameters subscriptionId=$subscriptionId \
               location=$location \
               resourceGroupName=$resourceGroupName \
               managedUserIdentityId=$vnetMngmtUserManagedIdentityId \
               resourceName=$arrayResourceName \
               arrayName=$arrayName \
               vnetName=$arrayVnetName \
               licenseKey=$licenseKey \
               alertRecipients=$alertRecipients \
               cbsModelSku=$cbsModelSku \
               orgDomain=$orgDomain \
               availabilityZone=$availabilityZone \
               azureMarketPlacePlanVersion=$AZURE_MARKETPLACE_PLAN_VERSION \
               azureMarketPlacePlanName=$AZURE_MARKETPLACE_PLAN_NAME \
               azureMarketPlacePlanPublisher=$AZURE_MARKETPLACE_PUBLISHER \
               azureMarketPlacePlanOffer=$AZURE_MARKETPLACE_PLAN_OFFER \
               jitApprovers="$jitApprovers" \
               sshPublicKey="$sshPublicKeyInOpenSSHFormat"
  )

cbsmanagementLbIp=`echo $output | jq -r '.properties.outputs.cbsmanagementLbIp.value'`
cbsmanagementEndpointCT0=`echo $output | jq -r '.properties.outputs.cbsmanagementEndpointCT0.value'`
cbsmanagementEndpointCT1=`echo $output | jq -r '.properties.outputs.cbsmanagementEndpointCT1.value'`

cbsreplicationEndpointCT0=`echo $output | jq -r '.properties.outputs.cbsreplicationEndpointCT0.value'`
cbsreplicationEndpointCT1=`echo $output | jq -r '.properties.outputs.cbsreplicationEndpointCT1.value'`

cbsiSCSIEndpointCT0=`echo $output | jq -r '.properties.outputs.cbsiSCSIEndpointCT0.value'`
cbsiSCSIEndpointCT1=`echo $output | jq -r '.properties.outputs.cbsiSCSIEndpointCT1.value'`


echo ""
echo ""
echo ""
echosuccess "[STEP COMPLETED] The deployment of CBS managed application has been completed."
echo ""

echo " ******** Array parameters ********"

echo ""
echo ""
echo " -------- Endpoints for management -------------"
echo "  Load balancer IP   |  ${cbsmanagementLbIp}"
echo "  CT0 IP address     |  ${cbsmanagementEndpointCT0}"
echo "  CT1 IP address     |  ${cbsmanagementEndpointCT1}"
echo " -----------------------------------------------"

echo ""
echo ""
echo " --------- Endpoints for replication -----------"
echo "  CT0 IP address    |  ${cbsreplicationEndpointCT0}"
echo "  CT1 IP address    |  ${cbsreplicationEndpointCT1}"
echo " -----------------------------------------------"

echo ""
echo ""
echo " ------------ Endpoints for iSCSI --------------"
echo "  CT0 IP address    |  ${cbsiSCSIEndpointCT0}"
echo "  CT1 IP address    |  ${cbsiSCSIEndpointCT1}"
echo " -----------------------------------------------"


echo -e "${C_BLUE3}${C_GREY85}
[Step #5] Getting your current IP address...${NO_FORMAT}

"


myIpAddress=(`curl ifconfig.me 2> /dev/null`)

if [ -z "$myIpAddress" ]; then
    echoerr "Something failed during gathering public IP address!"
    exit 1;
else
    echosuccess "Your public IP address: $myIpAddress"
    echo "There will be a network security group restricting access just for your IP address."
fi



echo -e "${C_BLUE3}${C_GREY85}
[Step #6] Deploying VM into subscription $subscriptionId into RG ${resourceGroupName} (~20mins):${NO_FORMAT}

"


# Deploy our infrastructure
output=$(az deployment group create \
  --name "CBS-E2E-$location-test-vm-deploy-sh" \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --template-file "templates/test-vm.bicep" \
  --parameters subscriptionId=$subscriptionId \
               location=$location \
               resourceGroupName=$resourceGroupName \
               extensionFileUrl=$extensionFileUrl \
               extensionCustomizeUXFileUrl=$extensionCustomizeUXFileUrl \
               PureManagementIP=$cbsmanagementLbIp \
               PureManagementUser=$pureManagementUser \
               PureManagementPassword=$pureManagementPassword \
               virtualMachineSize=$virtualMachineSize \
               virtualMachineName=$virtualMachineName \
               adminUsername=$adminUsername \
               adminPassword=$adminPassword \
               vNetName=$arrayVnetName \
               sshPrivateKeyContentInBase64="${sshPrivateKeyContentInBase64}"\
               whitelistedSourceAddress=$myIpAddress
  )


vmIpAddress=`echo $output | jq -r '.properties.outputs.vmIpAddress.value'`
adminUsername=`echo $output | jq -r '.properties.outputs.adminUsername.value'`
adminPassword=`echo $output | jq -r '.properties.outputs.adminPassword.value'`



echo ""
echo ""
echo ""
echosuccess "The deployment of DEMO WinServer Virtual Machine has been completed."
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
[Step #7][Optional] Opening Remote Desktop Connection session into the test VM:${NO_FORMAT}
"
    echo " Adding credentials to cmdkey:"
    cmdkey.exe /generic:"$vmIpAddress" /user:"$adminUsername" /pass:"$adminPassword"
    echo " Trying to open RDP connection..."
    mstsc.exe /v:$vmIpAddress &

    echosuccess 'The RDP connection should be opened.'

    echo "For new RDP session use command:
> mstsc.exe /v:$vmIpAddress"
fi

# running in MacOS
if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo " MacOS detected - trying to open Microsoft Remote Desktop app:"
    open -a /Applications/Microsoft\ Remote\ Desktop.app "rdp://full%20address=s:$vmIpAddress:3389&username=$adminUsername&audiomode=i:2&disable%20themes=i:1"
fi
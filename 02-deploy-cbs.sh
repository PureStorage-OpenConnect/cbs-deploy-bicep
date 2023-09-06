#!/bin/bash
set -e

source $(dirname $0)/script-modules/common.sh

# Read the bicep parameters
parametersfilename='./02-cbs.bicepparam'


source $(dirname $0)/script-modules/ascii-logo.sh

echo -e "
------------------------------------------------------------
        Pure Cloud Block Store - CBS Deployment
                (c) 2023 Pure Storage
                        v$CLI_VERSION
------------------------------------------------------------
"

bicep_raw=`bicep build-params $parametersfilename --stdout`
paramsJson=`echo $bicep_raw | jq -r ".parametersJson"`

location=`echo $paramsJson | jq -r ".parameters.location.value"`
subscriptionId=`echo $paramsJson | jq -r ".parameters.subscriptionId.value"`
resourceGroupName=`echo $paramsJson | jq -r ".parameters.resourceGroupName.value"`

echo -e "${C_BLUE3}${C_GREY85}
[Step #1] Enabling CBS deployment for selected subscription $subscriptionId:${NO_FORMAT}

"



AZURE_MARKETPLACE_PLAN_NAME=`echo $paramsJson | jq -r .parameters.azureMarketPlacePlanName.value`
if [ "$AZURE_MARKETPLACE_PLAN_NAME" = "null"  ];
then
    AZURE_MARKETPLACE_PLAN_NAME=`echo $bicep_raw | jq -r .templateJson | jq -r .parameters.azureMarketPlacePlanName.defaultValue`
fi

AZURE_MARKETPLACE_PUBLISHER=`echo $paramsJson | jq -r .parameters.azureMarketPlacePlanPublisher.value`
if [ "$AZURE_MARKETPLACE_PUBLISHER" = "null"  ];
then
    AZURE_MARKETPLACE_PUBLISHER=`echo $bicep_raw | jq -r .templateJson | jq -r .parameters.azureMarketPlacePlanPublisher.defaultValue`
fi

AZURE_MARKETPLACE_PLAN_OFFER=`echo $paramsJson | jq -r .parameters.azureMarketPlacePlanOffer.value`
if [ "$AZURE_MARKETPLACE_PLAN_OFFER" = "null"  ];
then
    AZURE_MARKETPLACE_PLAN_OFFER=`echo $bicep_raw | jq -r .templateJson | jq -r .parameters.azureMarketPlacePlanOffer.defaultValue`
fi

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
    echoerr "[Step #1][FAILURE] Enablement failed - offer: $AZURE_MARKETPLACE_PLAN_OFFER, plan: $AZURE_MARKETPLACE_PLAN_NAME, publisher: $AZURE_MARKETPLACE_PUBLISHER"
    echo $enablementOutput
    exit 1;
fi

echo -e "${C_BLUE3}${C_GREY85}
[Step #2] Deploying CBS managed app (~20mins):${NO_FORMAT} 
"
echo "
Subscription Id: $subscriptionId
RG name: $resourceGroupName
Location: $location

"
# Deploy our infrastructure
output=$(az deployment group create \
  --name "CBS-deploy-sh" \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --template-file "templates/cbs-managed-app.bicep" \
  --parameters $parametersfilename
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

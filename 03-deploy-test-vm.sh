#!/bin/bash
SHOW_DEBUG_OUTPUT=false

escape_quotes(){
    echo $@ | sed s/'"'/'\\"'/g
}


curlwithcode() {
    code=0
    # Run curl in a separate command, capturing output of -w "%{http_code}" into statuscode
    # and sending the content to a file with -o >(cat >/tmp/curl_body)
    statuscode=$(curl -w "%{http_code}" \
        -o >(cat >/tmp/curl_body) \
        "$@"
    ) || code="$?"

    body="$(cat /tmp/curl_body)"
    echo "{\"statusCode\": $statuscode,"
    echo "\"exitCode\": $code,"
    echo "\"body\": \"$(escape_quotes $body)\"}"
}

echoerr() { printf "\033[0;31m%s\n\033[0m" "$*" >&2; }
echosuccess() { printf "\033[0;32m%s\n\033[0m" "$*" >&2; }


# Read the bicep parameters
parametersfilename='./03-test-vm.bicepparam'

echo "           "
echo "           "
echo "  TEST VM DEPLOYMENT   "
echo "           "
echo "           "
echo "           "



echo "Deploying the VM for testing"
myIpAddress=`curl ifconfig.me 2> /dev/null`

paramsJson=`bicep build-params $parametersfilename --stdout  | jq -r ".parametersJson"`

tmpJsonFilename='tmp.json'
resourceGroupName=`echo $paramsJson | jq -r ".parameters.resourceGroupName.value"`
(echo $paramsJson | sed "s/\$myIpAddress/$myIpAddress/") > $tmpJsonFilename

# Deploy our infrastructure
output=$(az deployment group create \
  --name "test-vm-deploy-sh" \
  --resource-group $resourceGroupName \
  --template-file "templates/test-vm.bicep" \
  --parameters @$tmpJsonFilename

  )

rm $tmpJsonFilename

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
echosuccess "The deployment of CBS managed application has been completed."
echo ""

echo " ******** Array parameters ********"

echo ""
echo ""
echo " -------- Endpoints for management -------------"
echo "|  Load balancer IP   |  ${cbsmanagementLbIp}"
echo "|  CT0 IP address     |  ${cbsmanagementEndpointCT0}"
echo "|  CT1 IP address     |  ${cbsmanagementEndpointCT1}"
echo " -----------------------------------------------"

echo ""
echo ""
echo " --------- Endpoints for replication -----------"
echo "|  CT0 IP address    |  ${cbsreplicationEndpointCT0}"
echo "|  CT1 IP address    |  ${cbsreplicationEndpointCT1}"
echo " -----------------------------------------------"

echo ""
echo ""
echo " ------------ Endpoints for iSCSI --------------"
echo "|  CT0 IP address    |  ${cbsiSCSIEndpointCT0}"
echo "|  CT1 IP address    |  ${cbsiSCSIEndpointCT1}"
echo " -----------------------------------------------"

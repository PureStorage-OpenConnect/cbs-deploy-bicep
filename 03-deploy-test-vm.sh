#!/bin/bash
set -e
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

tmpJsonFilename='tmp03.json'
subscriptionId=`echo $paramsJson | jq -r ".parameters.subscriptionId.value"`
resourceGroupName=`echo $paramsJson | jq -r ".parameters.resourceGroupName.value"`
(echo $paramsJson | sed "s/\$myIpAddress/$myIpAddress/") > $tmpJsonFilename

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


if [ -n "${WSLENV}" ];
then
    echo "WSL only:"
    echo " Adding credentials to cmdkey:"
    cmdkey.exe /generic:"$vmIpAddress" /user:"$adminUsername" /pass:"$adminPassword"
    echo " Trying to open RDP connection..."
    mstsc.exe /v:$vmIpAddress
    echo 'The RDP connection should be opened.'
fi

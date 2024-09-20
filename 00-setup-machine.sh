#!/bin/bash

echoerr() { printf "\033[0;31m%s\n\033[0m" "$*" >&2; }
echosuccess() { printf "\033[0;32m%s\n\033[0m" "$*" >&2; }

if [ -n "${PURE_RUN_IN_DOCKERIMAGE}" ];
then
    echoerr "
In the docker image with pre-installed tools you don't need to run this setup command and you can proceed to the deployment scripts.
    "
    exit 1;
fi



# Install the az (with bicep)
echo "Installing tools:"

#4.5. Install the Azure CLI packages, bicep, jq, .NET, zip
if [[ "$OSTYPE" =~ ^linux ]]; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

  sudo apt -qy install jq

  curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
  # Mark it as executable
  chmod +x ./bicep
  # Add bicep to your PATH (requires admin)
  sudo mv ./bicep /usr/local/bin/bicep
fi

if [[ "$OSTYPE" =~ ^darwin ]]; then

  # install az cli
  brew update && brew install azure-cli  

  # install jq
  brew install jq

  # install bicep cli

  # Fetch the latest Bicep CLI binary
  curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-osx-x64
  # Mark it as executable
  chmod +x ./bicep
  # Add Gatekeeper exception (requires admin)
  sudo spctl --add ./bicep
  # Add bicep to your PATH (requires admin)
  sudo mv ./bicep /usr/local/bin/bicep

fi

# check installed tooling
echo "Testing tools:";
az version
if [ $? == 0 ]; then
  echosuccess "[.] az cli tool...OK";
else
  echoerr "Error with 'az cli' tool!";
  exit 1;
fi

# upgrade az cli
az upgrade --yes --all

# enable az auto-upgrade
az config set auto-upgrade.enable=yes

az bicep version
if [ $? == 0 ]; then
  echosuccess "[.] az-cli bicep support...OK";
else
  echo "Enabling bicep support in az-cli"
  az bicep install
fi

jq --version
if [ $? == 0 ]; then
  echosuccess "[.] jq tool...OK";
else
  echoerr "Error with 'jq' tool!";
  exit 1;
fi

bicep --version
if [ $? == 0 ]; then
  echosuccess "[.] bicep-cli tool...OK";
else
  echoerr "Error with 'bicep-cli' tool!";
  exit 1;
fi

echo "Asking user to log in...";
# ask user for login
az login
if [ $? == 0 ]; then
  echosuccess "
  Your machine should be ready! Now proceed with './deploy-quickstart.sh' or './01-deploy-prerequisities.sh' script
  
  ";
else
  echoerr "Login into Azure failed!";
  exit 1;
fi

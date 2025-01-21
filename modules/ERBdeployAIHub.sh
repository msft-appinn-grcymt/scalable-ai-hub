#!/bin/bash

# Sample usage ./deployAIHub.sh -s sample-subscription

red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
blue='\e[1;34m%s\e[0m\n'

#Get environment parameters for deployment from bicep param file
DEPLOYMENT_PARAM_FILE="./deploy.qa.bicepparam"

SUBSCRIPTION=''

while getopts 's:' flag; 
do
  case "${flag}" in
    s) SUBSCRIPTION=${OPTARG} ;;  
  esac
done

# read -p "Input the Subscription Id for the deployment: " SUBSCRIPTION

printf "$blue" "*** Getting the needed values for the deployment from parameter file ***"

# Get the location from the bicep param file
LOCATION=$(grep -E "param\s+location\s*=" $DEPLOYMENT_PARAM_FILE | awk -F"'" '{print $2}')

# # #  Set the right subscription
printf "$blue" "*** Setting the subsription to $SUBSCRIPTION ***"
az account set --name "$SUBSCRIPTION"

# Get the current date
CURRENT_DATE=$(date +'%m-%d-%Y')

printf "$blue" "*** Starting BICEP deployment for Enterprise AI Hub on $SUBSCRIPTION ***"

DEPLOYMENT_OUTPUTS=$(az deployment sub create \
--name AIHub-"$CURRENT_DATE" \
--location "$LOCATION" \
--parameters "$DEPLOYMENT_PARAM_FILE" )

apimName=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.apimName.value')
appGatewayName=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.appGatewayName.value')
resourceGroupName=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.resourceGroupName.value')
hubDns=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.hubDns.value')
productsArray=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.products.value')


if [[ -z $DEPLOYMENT_OUTPUTS ]]; then 
    printf "$red" "*** BICEP deployment failed! ***"
    exit 1
else
    printf "$green" "*** BICEP deployment completed! ***"
fi

printf "$blue" "*** Creating template spec file from blueprint ***"

cp ./onboard.template.bicep ./onboard.bicep

printf "$blue" "*** Setting values from the completed deployment ***"

sed -i -e "s/APIM_NAME_TO_BE_REPLACED/${apimName}/g" ./onboard.bicep
sed -i -e "s/APP_GW_NAME_TO_BE_REPLACED/${appGatewayName}/g" ./onboard.bicep
sed -i -e "s/DNS_NAME_TO_BE_REPLACED/${hubDns}/g" ./onboard.bicep
sed -i -e "s/LOCATION_TO_BE_REPLACED/${LOCATION}/g" ./onboard.bicep

printf "$blue" "*** Creating the template spec ***"

az ts create --name "OnBoardToAIHub" --version "1.0.0" --resource-group ${resourceGroupName} --location ${LOCATION} --template-file "./onboard.bicep"

printf "$green" "*** AI Hub deployment completed!! ***"

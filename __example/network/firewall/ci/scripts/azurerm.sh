#!/bin/bash

for ARGUMENT in "$@"
do
  KEY=$(echo $ARGUMENT | cut -f1 -d=)
  KEY_LENGTH=${#KEY}
  VALUE="${ARGUMENT:$KEY_LENGTH+1}"
  export "$KEY"="$VALUE"
done

TF_STATE_BLOB_SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

echo "TF_STATE_BLOB_SUBSCRIPTION_NAME      : [$TF_STATE_BLOB_SUBSCRIPTION_NAME]"
echo "TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP : [$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP]"
echo "TF_STATE_BLOB_ACCOUT_LOCATION        : [$TF_STATE_BLOB_ACCOUT_LOCATION]"
echo "TF_STATE_BLOB_ACCOUNT_NAME           : [$TF_STATE_BLOB_ACCOUNT_NAME]"
echo "TF_STATE_BLOB_ACCOUNT_SKU            : [$TF_STATE_BLOB_ACCOUNT_SKU]"
echo "TF_STATE_BLOB_CONTAINER_NAME         : [$TF_STATE_BLOB_CONTAINER_NAME]"

echo "Checking if [$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group actually exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription..."
az group show --name $TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP &> /dev/null
if [[ $? != 0 ]]; then
  echo "No [$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group actually exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
  echo "Creating [$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription..."
  az group create \
    --location $TF_STATE_BLOB_ACCOUT_LOCATION \
    --name $TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP &> /dev/null
  if [[ $? == 0 ]]; then
    echo "[$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group successfully created in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
  else
    echo "Failed to create [$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
    echo "##vso[task.setvariable variable=succeeded;isOutput=true;]false"
    exit -1
  fi
else
	echo "[$TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP] resource group already exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
fi

echo "Checking if [$TF_STATE_BLOB_ACCOUNT_NAME] storage account actually exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription..."
az storage account show --resource-group $TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP --name $TF_STATE_BLOB_ACCOUNT_NAME &> /dev/null
if [[ $? != 0 ]]; then
  echo "No [$TF_STATE_BLOB_ACCOUNT_NAME] storage account actually exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
  echo "Creating [$TF_STATE_BLOB_ACCOUNT_NAME] storage account in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription..."
  az storage account create \
    --name $TF_STATE_BLOB_ACCOUNT_NAME \
    --resource-group $TF_STATE_BLOB_ACCOUNT_RESOURCE_GROUP \
    --location $TF_STATE_BLOB_ACCOUT_LOCATION \
    --https-only \
    --allow-blob-public-access false \
    --min-tls-version TLS1_2 \
    --routing-choice MicrosoftRouting \
    --publish-microsoft-endpoints true \
    --sku $TF_STATE_BLOB_ACCOUNT_SKU &> /dev/null
  if [[ $OSTYPE == 'darwin'* ]]; then
    END=`date -v+30M '+%Y-%m-%dT%H:%MZ'`
  else
    END=`date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'`
  fi
  export TF_STATE_BLOB_SAS_TOKEN=$(az storage account generate-sas \
  --permissions cdlruwap \
  --account-name $TF_STATE_BLOB_ACCOUNT_NAME \
  --services b \
  --resource-types sco \
  --expiry $END \
  --only-show-errors -o tsv) &> /dev/null
  if [[ $? == 0 ]]; then
    echo "[$TF_STATE_BLOB_ACCOUNT_NAME] storage account successfully created in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
  else
    echo "Failed to create [$TF_STATE_BLOB_ACCOUNT_NAME] storage account in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
    echo "##vso[task.setvariable variable=succeeded;isOutput=true;]false"
    exit -1
  fi
else
  echo "[$TF_STATE_BLOB_ACCOUNT_NAME] storage account already exists in the [$TF_STATE_BLOB_SUBSCRIPTION_NAME] subscription"
  if [[ $OSTYPE == 'darwin'* ]]; then
    END=`date -v+30M '+%Y-%m-%dT%H:%MZ'`
  else
    END=`date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'`
  fi
  export TF_STATE_BLOB_SAS_TOKEN=$(az storage account generate-sas \
  --permissions cdlruwap \
  --account-name $TF_STATE_BLOB_ACCOUNT_NAME \
  --services b \
  --resource-types sco \
  --expiry $END \
  --only-show-errors -o tsv) &> /dev/null
fi

echo "Checking if [$TF_STATE_BLOB_CONTAINER_NAME] blob container actually exists in the [$TF_STATE_BLOB_ACCOUNT_NAME] storage account..."
az storage container show --account-name $TF_STATE_BLOB_ACCOUNT_NAME --name $TF_STATE_BLOB_CONTAINER_NAME --sas-token $TF_STATE_BLOB_SAS_TOKEN &> /dev/null 
if [[ $? != 0 ]]; then
  echo "No [$TF_STATE_BLOB_CONTAINER_NAME] blob container actually exists in [$TF_STATE_BLOB_ACCOUNT_NAME] storage account"
  echo "Creating [$TF_STATE_BLOB_CONTAINER_NAME] blob container in [$TF_STATE_BLOB_ACCOUNT_NAME] storage account..."
  az storage container create \
    --name $TF_STATE_BLOB_CONTAINER_NAME \
    --account-name $TF_STATE_BLOB_ACCOUNT_NAME \
    --sas-token $TF_STATE_BLOB_SAS_TOKEN &> /dev/null
  if [[ $? == 0 ]]; then
    echo "[$TF_STATE_BLOB_CONTAINER_NAME] blob container successfully created in [$TF_STATE_BLOB_ACCOUNT_NAME] storage account"
  else
    echo "Failed to create [$TF_STATE_BLOB_CONTAINER_NAME] blob container in [$TF_STATE_BLOB_ACCOUNT_NAME] storage account"
    echo "##vso[task.setvariable variable=succeeded;isOutput=true;]false"
    exit -1
  fi
else
	echo "[$TF_STATE_BLOB_CONTAINER_NAME] blob container already exists in [$TF_STATE_BLOB_ACCOUNT_NAME] storage account"
fi
echo "##vso[task.setvariable variable=SubscriptionName;isOutput=true;]$TF_STATE_BLOB_SUBSCRIPTION_NAME"
echo "##vso[task.setvariable variable=StorageAccountName;isOutput=true;]$TF_STATE_BLOB_ACCOUNT_NAME"
echo "##vso[task.setvariable variable=BlobContainer;isOutput=true;]$TF_STATE_BLOB_CONTAINER_NAME"
echo "##vso[task.setvariable variable=SasToken;isOutput=true;]$TF_STATE_BLOB_SAS_TOKEN"
echo "##vso[task.setvariable variable=succeeded;isOutput=true;]true"

#/bin/bash

rm -rf ./results
mkdir results && pushd results

VAULT_NAME=$1
CLUSTER_FQDN=$2
SECRET_NAME=$(echo $CLUSTER_FQDN | tr -cd '[:alpha:]')

# Create a new self-signed cert, with a custom FQDN
# Note: As of 5/7/17, KeyVault supports only 2048 bit RSA keys
openssl req -x509 -newkey rsa:2048 -subj "/CN=${CLUSTER_FQDN}" -days 365 -out ${CLUSTER_FQDN}.crt -keyout ${CLUSTER_FQDN}.pem -passout pass:${CLUSTER_FQDN} 

# Convert .crt/.pem to PFX
openssl pkcs12 -export -in ${CLUSTER_FQDN}.crt -inkey ${CLUSTER_FQDN}.pem  -passin pass:${CLUSTER_FQDN} -out ${CLUSTER_FQDN}.pfx -passout pass:${CLUSTER_FQDN}

# The Azure Compute resource provider expects certificate secrets to be in a specific JSON format, which is then base64 encoded. Ex:
# {
#   "data": "<base64 encoded PFX>",
#   "dataType": "pfx",
#   "password": "<PFX password>"
# }
SECRET_VALUE=$(jq -n --arg data "$(cat ${CLUSTER_FQDN}.pfx | base64 -w 0)" --arg password ${CLUSTER_FQDN} '{ data:$data, dataType:"pfx", password:$password }' | base64 -w 0)

# Upload the secret to KeyVault, and capture the resulting id
SECRET_ID=$(az keyvault secret set -n ${SECRET_NAME} --vault-name ${VAULT_NAME} --value $SECRET_VALUE --query id -o tsv)

# Print relevant info to make it easy to continue in the Azure Portal and/or ARM templates
# Get the full resource id of the vault, in the format: /subscriptions/{subscriptionId}/resourceGroups/{groupId}/providers/Microsoft.KeyVault/vaults/{vaultId}
VAULT_ID=$(az keyvault show -n ${VAULT_NAME} --query id -o tsv)
echo "sourceVaultValue: ${VAULT_ID}"
echo "certificateUrlValue: ${SECRET_ID}"
# Get the fingerprint and put into Azure-friendly format by stripping "SHA1 Fingerprint=" and separating colons
THUMBPRINT=$(openssl x509 -in ${CLUSTER_FQDN}.crt -fingerprint -noout | sed -r -e 's/.{17}//' -e 's/://g')
echo "certificateThumbprint: ${THUMBPRINT}"

# To retrieve & decode the secret from KeyVault. 
# This performs the inverse of the above steps
# 1. Show the secret, using a JMESPath query to display only the "value" property, and using tsv to eliminate surrounding quotes
# 2. base64 decode the value to get the JSON formatted payload
# 3. Use jq to get the "data" property
# 4. base64 decode to get the resulting PFX
# 5. Save to a .pfx file
#az keyvault secret show -n ${SECRET_NAME} --vault-name ${VAULT_NAME} --query value -o tsv | base64 -d | jq -r .data | base64 -d > ${CLUSTER_FQDN}_out.pfx

# Get public key (.crt) from PFX
#openssl pkcs12 -in ${CLUSTER_FQDN}_out.pfx -passin pass:${CLUSTER_FQDN} -clcerts -nokeys -out ${CLUSTER_FQDN}_out.crt
# Get private key (.pem) from PFX
#openssl pkcs12 -in ${CLUSTER_FQDN}_out.pfx -passin pass:${CLUSTER_FQDN} -nocerts -out ${CLUSTER_FQDN}_out.pem -passout pass:${CLUSTER_FQDN}


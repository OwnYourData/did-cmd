#!/usr/bin/env bash

OYDIDCMD='../oydid.rb'
# OYDIDCMD='oydid'

# start local Semantic Container
docker run --name oydid -p 4000:3000 -e AUTH=true semcon/sc-base

SEMCON_URL='http://localhost:4000'
# SEMCON_URL='https://demo.data-container.net'

APP_KEY=`docker logs oydid | grep APP_KEY | awk -F " " '{print $NF}'`; \
APP_SECRET=`docker logs oydid | grep APP_SECRET | awk -F " " '{print $NF}'`; \
ADMIN_TOKEN=`curl -s -d grant_type=client_credentials -d client_id=$APP_KEY \
	-d client_secret=$APP_SECRET -d scope=admin \
	-X POST http://localhost:4000/oauth/token | jq -r '.access_token'`

# export TOKEN=`curl -X POST -s -d grant_type=client_credentials -d scope=admin \
#     -d client_id=c196066b21eeb9df20056447467d7132696d7558a3208610e0dab6941a9434b8 \
#     -d client_secret=fb6f99f75e2d37943c4a8f9196dd07ed96daeef525a88d03c2246093074973c6 \
#     $SEMCON_URL/oauth/token | \
#     jq -r '.access_token'`

# create DID for Semantic Container
SC_DID=`$OYDIDCMD sc_init location --token $ADMIN_TOKEN --doc-key c2/private_key.b58 --rev-key c2/revocation_key.b58 |
	jq -r '.did'`

# writing to Semantic Container
TOKEN=`$OYDIDCMD sc_token "$SC_DID;$SEMCON_URL" --doc-key c2/private_key.b58 | \
	jq -r '.access_token'`
echo '{"hello": "world"}' | \
	curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
	-d @- -X POST $SEMCON_URL/api/data

# reading from SEMANTIC CONTAINER
curl -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -X GET $SEMCON_URL/api/data

# create DID for record
cat c2/data.json | $OYDIDCMD sc_create --token $ADMIN_TOKEN
DID_REC=`cat c2/data.json | jq -r '.did'`

# output DID
$OYDIDCMD read --w3c-did "$DID_REC;$SEMCON_URL"
#!/bin/bash

# Source this file to add get_bearer_token(){} function to your shell environment

function mosyle_get_bearer_token(){
    # $1 = Username
    # $2 = Password
    # $3 = AccessToken

    local username="${1}"
    local pword="${2}"
    local accessToken="${3}"

    echo "Attempting to get BToken for $orgName - $username"

    if [ -z "$1" ]; then
        echo "ERROR: get_bearer_token was not provided the correct arguments: $orgName location 1"
        return 1
    fi

    if [ -z "$2" ]; then
        echo "ERROR: get_bearer_token was not provided the correct arguments: $orgName location 2"
        return 2
    fi

    if [ -z "$3" ]; then
        echo "ERROR: get_bearer_token was not provided the correct arguments: $orgName location 3"
        return 3
    fi

    export MOSYLE_BEARER_TOKEN_CURL="$(curl -s --include --location 'https://businessapi.mosyle.com/v1/login' \
        --header "accessToken: ${accessToken}" \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "email" : '\""$username"\",'
            "password" : '\"$pword\"'
        }')"

    MOSYLE_BEARER_TOKEN="$(echo "${MOSYLE_BEARER_TOKEN_CURL}" | awk '/Authorization: Bearer / {print $3}' | tr -d '\r')"

    if [[ -z "$MOSYLE_BEARER_TOKEN" ]]; then
        echo "Empty BearVar error: $orgName"
        echo "${MOSYLE_BEARER_TOKEN_CURL}"
    fi

}
#!/bin/bash

# Good doc:
# https://developers.google.com/identity/protocols/oauth2/native-app

# These files should be populated manually

# Downloaded from the Cloud Console
SECRET_FILE="client_secret.json"

# Contains the API key on the first line
# e.g. echo "FOO" > api_key.txt
API_KEY_FILE="api_key.txt"

# These files are generated by the script
ACCESS_TOKEN_FILE="token.txt"
AUTHORIZATION_FILE="authorization.txt"

SCOPES="https://www.googleapis.com/auth/drive"


extract_secret() {
  local field="$1"
  jq -r ".installed.${field}" "${SECRET_FILE}"
}

read_authorization_code() {
  read -d $'\x04' code < "$AUTHORIZATION_FILE"
  echo "${code}"
}

read_token() {
  jq -r ".access_token" "${ACCESS_TOKEN_FILE}"
}

read_api_key() {
  read -d $'\x04' key < "$AUTHORIZATION_FILE"
  echo "${key}"
}


# Ask the other for permission (interactive)
# The request includes the client ID and scopes and we
# get and authorization code back (valid for one token refresh).
get_authorization_token() {
  local client_id="$(extract_secret 'client_id')"  
  local auth_uri="$(extract_secret 'auth_uri')"  
  local redirect_uri="$(extract_secret 'redirect_uris[0]')"  

  curl -Gs -s -o /dev/null -w %{url_effective} "${auth_uri}" \
     --data-urlencode "client_id=${client_id}" \
     --data-urlencode "response_type=code" \
     --data-urlencode "state=state_parameter_passthrough_value" \
     --data-urlencode "scope=${SCOPES}" \
     --data-urlencode "redirect_uri=${redirect_uri}" \
     --data-urlencode 'include_granted_scopes=true' \
     --data-urlencode 'access_type=offline' \
     --data-urlencode 'prompt=consent'

  echo
  echo "Open the URL above in your browser and paste the token here:"
  read token
  echo "$token"  > "${AUTHORIZATION_FILE}"
}

# Exchange the client ID, secret and authorization code for a token
get_token() {
  local token_uri="$(extract_secret 'token_uri')"  
  local client_id="$(extract_secret 'client_id')"  
  local client_secret="$(extract_secret 'client_secret')"  
  local redirect_uri="$(extract_secret 'redirect_uris[0]')"  
  echo "code=$(read_authorization_code)"
  curl -Gs -X POST "${token_uri}" \
     --data-urlencode "client_id=${client_id}" \
     --data-urlencode "client_secret=${client_secret}" \
     --data-urlencode "code=$(read_authorization_code)" \
     --data-urlencode "redirect_uri=${redirect_uri}" \
     --data-urlencode 'grant_type=authorization_code' \
     -o "${ACCESS_TOKEN_FILE}"
}

# Exchange the client ID, secret and authorization code for a token
refresh_token() {
  echo "Refreshing token" >&2
  local token="$(read_token)"
  local token_uri="$(extract_secret 'token_uri')"  
  local client_id="$(extract_secret 'client_id')"  
  local client_secret="$(extract_secret 'client_secret')"  
  curl -Gs -X POST "${token_uri}" \
     --data-urlencode "client_id=${client_id}" \
     --data-urlencode "client_secret=${client_secret}" \
     --data-urlencode "refresh_token=$(read_token)" \
     --data-urlencode 'grant_type=refresh_token' \
     -o "${ACCESS_TOKEN_FILE}"
}

maybe_refresh_token() {
  local last_modification=$(date +%s -r ${ACCESS_TOKEN_FILE}) 
  local now="$(date +%s)"
  local elapsed=$((now - last_modification))
  local token_life=$(jq .expires_in ${ACCESS_TOKEN_FILE})
  local remaining_seconds=$((token_life - elapsed))
  if [[ $remaining_seconds -lt 60 ]] ; then
    refresh_token
  fi
}

find_follow_ups() {
  maybe_refresh_token
  curl -Gs 'https://www.googleapis.com/drive/v3/files' \
    -H "Authorization: Bearer $(read_token)" \
    --data-urlencode 'key=$(read_api_key)' \
    --data-urlencode "q=trashed=false and fullText contains 'followup:actionitems'"  \
     # -o resp.txt

  # for id in $(jq -r '.files[].id' resp.txt) ; do 
  #   echo "Processing file $id"
  #   curl -Gs 'https://www.googleapis.com/drive/v3/files' \
  #     -H "Authorization: Bearer ${token}" \
  #     --data-urlencode 'key=$(read_api_key)' \
  #     --data-urlencode "fileId=${id}"  \
  #     --data-urlencode "fields=*" | jq '.' > "resp_${id}.txt"
  # done
}

maybe_init_oauth() {
  if [[ ! -f ${ACCESS_TOKEN_FILE} ]] ; then 
    get_authorization_token
    get_token
  fi
}

if [[ $# -lt 1 ]] ; then
  echo "Missing action"
else
  action="$1"
  if [[ "$action" == "clean" ]] ; then
    echo rm -f "${ACCESS_TOKEN_FILE}" "${AUTHORIZATION_FILE}"
    rm -f "${ACCESS_TOKEN_FILE}" "${AUTHORIZATION_FILE}"
  elif [[ "$action" == "list" ]] ; then
    maybe_init_oauth
    find_follow_ups
  fi
fi

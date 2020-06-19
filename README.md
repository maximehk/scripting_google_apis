# Fetches oauth2 token and calls the Drive v3 API

## Requirements

### Software

```bash
sudo apt install jq curl
```

### Credentials

Download the client_secret file and API key from the Cloud Console and save them as secrets/client_secret.json and secrets/api_key.txt respectively.

NB: I store these secrets in `$HOME/secrets` so all I have to do is:

```bash
git clone git@github.com:maximehk/scripting_google_apis
cd scripting_google_apis
ln -s $HOME/secrets
```

## Usage

`./make_call.sh list` or `./make_call.sh clean`

## Additional resources

https://developers.google.com/identity/protocols/oauth2/native-app



#!/bin/bash
set -e
dfx stop
dfx start --background --clean

dfx deploy aio-base-frontend


# add recharge principal
echo "Add Recharge Principal"
RECHARGE_PRINCIPAL_ID="jzpwm-zsjcq-ugkzp-nr7au-bydmm-c7rqk-tzp2r-gtode-fws2v-ehkfl-cqe"

if [ -z "$RECHARGE_SUBACCOUNT_ID" ]; then
  dfx canister call aio-base-backend add_recharge_principal_account_api "(
    record {
      principal_id = \"$RECHARGE_PRINCIPAL_ID\"
    }
  )"
else
  dfx canister call aio-base-backend add_recharge_principal_account_api "(
    record {
      principal_id = \"$RECHARGE_PRINCIPAL_ID\"
    }
  )"
fi

./minttokendev.sh

dfx deploy alaya-chat-nexus-frontend

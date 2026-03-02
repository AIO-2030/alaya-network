#!/bin/bash
set -e

# Install dependencies before building
echo "Installing dependencies..."
cd "$(dirname "$0")"
npm install || {
  echo "Warning: npm install failed, trying to install in workspace directories..."
  cd src/aio-base-frontend && npm install || true
  cd ../alaya-chat-nexus-frontend && npm install || true
  cd ../..
}

dfx stop
dfx start --background --clean
dfx deploy aio-base-backend
dfx deploy aio-base-frontend
dfx deploy alaya-chat-nexus-frontend

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

# Initialize Task Rewards Contract
echo "Initializing Task Rewards Contract..."
dfx canister call aio-base-backend init_task_contract "(
  vec {
  record {
      taskid = \"invite_20_friends\";
      reward = 50_000_000 : nat64;
      payfor = null;
    };
    record {
      taskid = \"register_device\";
      reward = 50_000_000 : nat64;
      payfor = null;
    };
    record {
      taskid = \"ai_subscription\";
      reward = 100_000_000 : nat64;
      payfor = opt \"ai_subscription\";
    };
    record {
      taskid = \"voice_clone\";
      reward = 150_000_000 : nat64;
      payfor = null;
    };
  }
)"

echo "Task Rewards Contract initialized successfully!"
echo "- register_device: 50 PMUG (50,000,000 smallest units)"
echo "- ai_subscription: 100 PMUG (100,000,000 smallest units)"
echo "- voice_clone: 150 PMUG (150,000,000 smallest units)"

# Initialize AI Subscription Service Types
echo "Initializing AI Subscription Service Types..."
dfx canister call aio-base-backend ai_sub_create_service '(record { svr_id = "1"; name = "Personal AI"; price_level = variant { M }; price = 5 : nat64 })'
dfx canister call aio-base-backend ai_sub_create_service '(record { svr_id = "2"; name = "Voice Clone"; price_level = variant { E }; price = 15 : nat64 })'
echo "AI Subscription Service Types initialized: (1) Personal AI M/5, (2) Voice Clone E/15 (永久)"

#./minttokendev.sh


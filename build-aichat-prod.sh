#!/bin/bash
set -e


#dfx stop
#dfx start --background --clean
#####dfx deploy aio-base-backend -m upgrade --no-wallet  --network=ic
#####dfx deploy alaya-chat-nexus-frontend -m upgrade --no-wallet --network=ic

# add recharge principal
echo "Add Recharge Principal"
RECHARGE_PRINCIPAL_ID="jzpwm-zsjcq-ugkzp-nr7au-bydmm-c7rqk-tzp2r-gtode-fws2v-ehkfl-cqe"

if [ -z "$RECHARGE_SUBACCOUNT_ID" ]; then
  dfx canister call aio-base-backend add_recharge_principal_account_api "(
    record {
      principal_id = \"$RECHARGE_PRINCIPAL_ID\"
    }
  )" --network=ic
else
  dfx canister call aio-base-backend add_recharge_principal_account_api "(
    record {
      principal_id = \"$RECHARGE_PRINCIPAL_ID\"
    }
  )" --network=ic
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
)" --network=ic

echo "Task Rewards Contract initialized successfully!"
echo "- register_device: 50 PMUG (50,000,000 smallest units)"
echo "- ai_subscription: 100 PMUG (100,000,000 smallest units)"
echo "- voice_clone: 150 PMUG (150,000,000 smallest units)"

# Initialize AI Subscription Service Types (svr_id 需与前端 SVR_ID_PERSONAL_AI / SVR_ID_VOICE_CLONE 一致)
echo "Initializing AI Subscription Service Types..."
dfx canister call aio-base-backend ai_sub_create_service '(record { svr_id = "ai_subscription"; name = "Personal AI"; price_level = variant { M }; price = 0 : nat64 })' --network=ic
dfx canister call aio-base-backend ai_sub_create_service '(record { svr_id = "voice_clone"; name = "Voice Clone"; price_level = variant { E }; price = 0 : nat64 })' --network=ic
echo "AI Subscription Service Types initialized: (ai_subscription) Personal AI, (voice_clone) Voice Clone E/15 USDT"

#./minttokendev.sh


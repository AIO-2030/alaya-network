#!/bin/bash
set -e
dfx stop
dfx start --background  --clean 
#dfx deploy aio-base-backend
dfx deploy aio-base-frontend
./minttokendev.sh
#! /bin/bash

pkill -9 loader
/gramine-sdk/scripts/sign.sh $1
gramine-sgx $1 $2 $3 $4 $5

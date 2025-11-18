#!/bin/bash

sfcip="10.12.179.143"
eqp_no=$1
stage=$2
sn=$3
datetime=$(date -u +"%Y-%m-%dT%H:%M:%S%:z")
func="cimsgetconfigurapi"
project="Megazord"
json=$(cat <<EOF
{
"SN": "$sn", 
"STATION_ID": "$stage", 
"PROJECT": "$project" 
}
EOF
)

#echo "Sending JSON:"
#echo "$json"
#echo "curl -k -s -X POST \"https://${sfcip}/tst/${func}\" -H \"Content-Type: application/json\" -d \"$json\""

msg=$(curl -k -s -X POST "https://${sfcip}/tst/${func}" -H "Content-Type: application/json" -d "$json")

echo "Response:"
echo "$msg"
res=`echo $msg | grep -ic "RESULT\": \"OK\""`
if [ "${res}" -eq "1" ];then
    exit 0
else
    exit 1
fi

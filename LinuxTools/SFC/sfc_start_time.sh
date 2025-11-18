#!/bin/bash
sfcip="10.12.179.143"
eqp_no=$1
stage=$2
sn=$3
datetime=$(date -u +"%Y-%m-%dT%H:%M:%S%:z")
func="cimstartestapi"
json=$(cat <<EOF
{
  "TimeStamp": "${datetime}",
  "EQP_No": "${eqp_no}",
  "Station_Name": "${stage}",
  "Fixture_ID": "",
  "Emp_No": "megazord",
  "Serial_Number": "${sn}",
  "Model_Name": "KODIAK3",
  "Start_Time": "${datetime}",
  "Result": "OK",
  "Message": ""
}
EOF
)

#echo "Sending JSON:"
#echo "$json"
#echo "curl -k -s -X POST \"https://${sfcip}/tst/${func}\" -H \"Content-Type: application/json\" -d \"$json\""

msg=$(curl -k -s -X POST "https://${sfcip}/tst/${func}" -H "Content-Type: application/json" -d "$json")

echo "Response:"
echo "$msg"
res=`echo $msg | grep -ic "Message\": \"OK"`
if [ "${res}" -eq "1" ];then
    exit 0
else
    exit 1
fi

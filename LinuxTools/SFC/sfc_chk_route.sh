#!/bin/bash

sfcip="10.12.179.143"
func="cimscheckrouteapi"
sn=$1
station=$2
emp_no=$3
model=$4
arg_num=4
#datetime=$(date -u +"%Y-%m-%dT%H:%M:%S%:z")

print_help(){
    cat <<EOF
    Usage: ./$(basename $0) "SN" "STATION_ID" "EMP_NO" "MODEL_NAME" | ./$(basename $0) -h
        SN : Rack Serial Number
        STATION_ID : SFC Station ID
        EMP_NO : Employee Number
        MODEL_NAME : 
    Example: ./$(basename $0) M3254000041 FVT IG1558 ""
EOF
}

if [ "$1" = "-h" ];then
    print_help
    exit 1
elif [ "$#" -ne "${arg_num}" ];then
    echo "Need to run with ${arg_num} arguments"
    print_help
    exit 1
fi


json=$(cat <<EOF
{
"SN": "$sn", 
"STATION_ID": "$station", 
"EMP_NO": "$eqp_no", 
"MODEL_NAME": ""
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

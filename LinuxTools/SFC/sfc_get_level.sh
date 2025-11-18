#!/bin/bash

sfcip="10.12.179.143"
sn=$1
station=$2
file_location=$3
datetime=$(date -u +"%Y-%m-%dT%H:%M:%S%:z")
func="getlevel"
arg_num=3

json=$(cat <<EOF
{
"SN": "$sn",
"STATION_ID": "${station}",
"TRANSTYPE": "Start"
}
EOF
)

print_help(){
    cat <<EOF
    Usage: ./$(basename $0) -h | ./$(basename $0) "SN" "STATION_ID" "EMP_NO" "EQP_NO" "MODEL_NAME" "MESSAGE" 
        SN : Rack Serial Number  
        STATION_ID : SFC Station ID   
        TRANSTYPE : Start Type
    Example: ./$(basename $0) M3254000041 FVT 
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


#echo "Sending JSON:"
#echo "$json"
echo "curl -k -s -X POST \"https://${sfcip}/tst/${func}\" -H \"Content-Type: application/json\" -d \"$json\""

curl -k -s -X POST "https://${sfcip}/tst/${func}" -H "Content-Type: application/json" -d "$json" > ${file_location}/$sn.json

cat ${file_location}/$sn.json | jq '.' > ${file_location}/${sn}_formatted.json

#echo "Response:"
#echo "$msg"
#res=`echo $msg | grep -ic "RESULT\": \"OK\""`
#if [ "${res}" -eq "1" ];then
#    exit 0
#else
#    exit 1
#fi

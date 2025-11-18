#!/bin/bash

source ../commonlib

sfcip="10.12.179.143"
func="cimstartestapi"
sn=$1
station=$2
emp_no=$3
eqp_no=$4
modelName=$5
start_time=$(date +"%Y-%m-%dT%H:%M:%S.%6N")
result="OK"
message=$6
arg_num=6
LOGFOLDER="${LOGPATH}/${sn}"

print_help(){
    cat <<EOF
    Usage: ./$(basename $0) -h | ./$(basename $0) "SN" "STATION_ID" "EMP_NO" "EQP_NO" "MODEL_NAME" "MESSAGE" 
        SN : Rack Serial Number  
        STATION_ID : SFC Station ID   
        EMP_NO : Employee Number  
        EQP_NO : Equipment Number   
        MODEL_NAME : Model Name
        MESSAGE : Testing Message
        LOGFOLDER : Log folder
    Example: ./$(basename $0) M3254000041 FVT IG1558 172.20.200.51 "HPRv3" ""
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

#datetime=$(date -u +"%Y-%m-%dT%H:%M:%S%:z")
json=$(cat <<EOF
{
"TimeStamp":"${start_time}",
"Serial_Number": "$sn", 
"Station_Name" : "$station",
"Emp_No" : "$emp_no", 
"EQP_No": "$eqp_no",
"Start_Time":"${start_time}",
"Model_Name" :"${modelName}",
"Result": "OK",
"Message": ""
}
EOF
)

#echo "Sending JSON:"
#echo "$json"
echo "curl -k -s -X POST \"https://${sfcip}/tst/${func}\" -H \"Content-Type: application/json\" -d \"$json\""

msg=$(curl -k -s -X POST "https://${sfcip}/tst/${func}" -H "Content-Type: application/json" -d "$json")
echo "$start_time" > ${LOGFOLDER}/${rack_sn}_starttime.txt

echo "Response:"
echo "$msg"
res=`echo $msg | grep -ic "RESULT\": \"OK\""`
if [ "${res}" -eq "1" ];then
    exit 0
else
    exit 1
fi


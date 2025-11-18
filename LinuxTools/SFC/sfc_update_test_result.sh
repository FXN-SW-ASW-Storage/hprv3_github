#!/bin/bash


sfcip="10.12.179.143"
func="cimsupdatetestresultapi"
sn=$1
station=$2
emp_no=$3
eqp_no=$4
result=$5
start_time=$6
end_time=$7
ec=$8
ec_detail=$9
arg_num=9

print_help(){
    cat <<EOF
    Usage: ./$(basename $0) -h | ./$(basename $0) "SN" "STATION_ID" "EMP_NO" "EQP_NO" "RESULT" "START_DATE" "END_DATE" "EC" "EC_DETAIL"
        SN : Rack Serial Number  
        STATION_ID : SFC Station ID   
        EMP_NO : Employee Number  
        EQP_NO : Equipment Number   
        RESULT : Result obtained
        START_DATE : The time when the rack starts the test
        END_DATE : The time when the rack ends the test
        EC : Error Code
        EC_DETAIL : Error Code with Details
    Example: ./$(basename $0) M3254200002 MFT1 IG1471 172.20.200.51 PASS "2025-11-05T17:08:00+00:00" "2025-11-05T17:08:19+00:00" "" ""
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
"SN": "$sn", 
"STATION_ID" : "$station",
"EMP_NO" : "$emp_no", 
"EQP_NO": "$eqp_no",
"RESULT": "${result}",
"START_DATE":"${start_time}",
"END_DATE" :"${end_time}",
"EC": "${ec}",
"EC_DETAIL": {${ec_detail}}
}
EOF
)

#echo "Sending JSON:"
#echo "$json"
echo "curl -k -s -X POST \"https://${sfcip}/tst/${func}\" -H \"Content-Type: application/json\" -d \"$json\""

msg=$(curl -k -s -X POST "https://${sfcip}/tst/${func}" -H "Content-Type: application/json" -d "$json")

echo "Response:"
echo "$msg"
res=`echo $msg | grep -ic "RESULT\": \"OK\""`
if [ "${res}" -eq "1" ];then
    exit 0
else
    exit 1
fi


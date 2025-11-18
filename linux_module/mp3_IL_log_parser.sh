#!/bin/bash

. ../commonlib

 #set -x
function print_help() {
    cat <<EOF
    Usage: $(basename $0) -f [Filename]
    Example: $(basename $0) -f /log/Diag/abc.log
EOF
}

while getopts r:i:f: OPT; do
    case "${OPT}" in
        "f")
            logfile=${OPTARG}
            #echo "logfile=$logfile"
            if [ ! -f "${logfile}" ];then
                echo "Can not find log file ${logfile}. Please check the file manually first."
                exit 1
            fi
            ;;
        "i")
            index=${OPTARG}
        ;;
        "r")
            RXLog=${OPTARG}
            ;;
        *)
            echo "Wrong Parameter..."
            print_help
            exit 1
            ;;
    esac
done

if [ ! -f "${logfile}" ];then
        echo "Can not find log file ${logfile}. Please check the file manually first."
        print_help
        exit 1
fi

#output_file1="temp.log"
#output_file2="parser_result_insertion_loss.log"

#rm -rf "$output_file1"
#rm -rf "$output_file2"

input_file="${logfile}"
# dos2unix "$input_file"
count=""

declare -A pim_data  

dBvalue=2
type1err="Type_1_Error - Composite TX is less than 1 mW."
type2err="Type_2_Error - TX is less than RX."
type3err="Type_3_Error - dB value = $dBvalue or greater."

#echo "index=${index}"

mW_to_dBm() {
    local mW=$1
    local R=50  #dBm=$(echo "scale=4; 10 * l(($mV^2 / ($R * 1000))) / l(10)" | bc -l)
    dBm=$(echo "scale=2; 10 * l($mW) / l(10)" | bc -l)
    echo "$dBm"
}

dBm_to_mW() {
    local dBm=$1
    dBm2=`echo "scale=2;${dBm}/10" | bc -l`
    mW=`echo "scale=2;e(${dBm2}*l(10))" | bc -l`
    echo "$mW"
}

check_IL()
{
    port_name="Port"
    start_num=$1
    end_num=$2
    for ((num=${start_num};num<=${end_num};num++));
    do
        line=$(cat ${logfile} | grep -A7 -w "Port${num}:" | grep "TX Power")
        #echo "cat ${logfile} | grep -w "${port_name}${num}" | awk '{print $6}'"
        arr=(${line})
        tx_array=("${arr[@]:4:4}")
        tx_sum1=0
        for tx in "${tx_array[@]}"; do
            tx1=$(dBm_to_mW ${tx})
            tx_sum1=`echo "${tx_sum1} + ${tx1}"|bc`
        done

        line=$(cat ${logfile} | grep -A7 -w "Port${num}:" | grep "RX Power")
        #echo "cat ${logfile} | grep -w "${port_name}${num}" | awk '{print $6}'"
        arr=(${line})
        rx_array=("${arr[@]:4:4}")
        rx_sum1=0
        for rx in "${rx_array[@]}"; do
            rx1=$(dBm_to_mW ${rx})
            rx_sum1=`echo "${rx_sum1} + ${rx1}"|bc`
        done 
        tx_dbm1=$(mW_to_dBm ${tx_sum1})
        rx_dbm1=$(mW_to_dBm ${rx_sum1})
        echo "${port_name}${num} Lanes 1-4 composite RX dBm : ${rx_dbm1}" >> ${RXLog}
        diff=$(echo "scale=2;(${tx_dbm1} - ${rx_dbm1})/1" | bc)
        if (( $(echo "${tx_sum1} < 1" | bc -l) )); then
            echo "${port_name}${num} Lanes 1-4  ------- [FAIL] ; Type 1 Error , Composite TX = ${tx_sum1} mW."
            ((err1++))
            ((final++))
            let port_count+=1
        elif (( $(echo "${rx_dbm1} > ${tx_dbm1}" | bc -l) ));then
            #echo "${port_name}${num} Lanes 1-4  ------- [FAIL] ; Type 2 Error , Diff : ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm "
            echo "${port_name}${num} Lanes 1-4  ------- [SKIP] ; Type 2 Error , Diff : ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm "
            #((err2++))
            #((final++))
            ((pass++))
            let port_count+=1
        elif (( $(echo "${diff} >= $dBvalue " | bc -l) )); then
            echo "${port_name}${num} Lanes 1-4  ------- [FAIL] ; Type 3 Error , Diff = ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm"
            ((err3++))
        ((final++))
            let port_count+=1
        else
            echo "${port_name}${num} Lanes 1-4  ------- [PASS]; Diff = ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm"
            ((pass++))
            let port_count+=1
        fi
        line=$(cat ${logfile} | grep -A7 -w "Port${num}:" | grep "TX Power" | tr -d '[:cntrl:]')
        #echo "cat ${logfile} | grep -w "${port_name}${num}" | awk '{print $6}'"
        arr=(${line})
        tx_array=("${arr[@]:8:4}")
        tx_sum1=0
        for tx in "${tx_array[@]}"; do
            tx1=$(dBm_to_mW ${tx})
            tx_sum1=`echo "${tx_sum1} + ${tx1}"|bc`
        done
        line=$(cat ${logfile} | grep -A7 -w "Port${num}:" | grep "RX Power" | tr -d '[:cntrl:]')
        #echo "cat ${logfile} | grep -w "${port_name}${num}" | awk '{print $6}'"
        arr=(${line})
        rx_array=("${arr[@]:7:4}")
        rx_sum1=0
        for rx in "${rx_array[@]}"; do
            rx1=$(dBm_to_mW ${rx})
            rx_sum1=`echo "${rx_sum1} + ${rx1}"|bc`
        done
        tx_dbm1=$(mW_to_dBm ${tx_sum1})
        rx_dbm1=$(mW_to_dBm ${rx_sum1})
        echo "${port_name}${num} Lanes 5-8 composite RX dBm : ${rx_dbm1}" >> ${RXLog}
        diff=$(echo "scale=2;(${tx_dbm1} - ${rx_dbm1})/1" | bc)
        if (( $(echo "${tx_sum1} < 1" | bc -l) )); then
            echo "${port_name}${num} Lanes 5-8  ------- [FAIL] ; Type 1 Error , Composite TX = ${tx_sum1} mW."
            ((err1++))
            ((final++))
            let port_count+=1
        elif (( $(echo "${rx_dbm1} > ${tx_dbm1}" | bc -l) ));then
            #echo "${port_name}${num} Lanes 5-8  ------- [FAIL] ; Type 2 Error , Diff : ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm "
            echo "${port_name}${num} Lanes 5-8  ------- [SKIP] ; Type 2 Error , Diff : ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm "
            #((err2++))
            #((final++))
            ((pass++))
            let port_count+=1
        elif (( $(echo "${diff} >= $dBvalue " | bc -l) )); then
            echo "${port_name}${num} Lanes 5-8  ------- [FAIL] ; Type 3 Error , Diff = ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm"
            ((err3++))
        ((final++))
            let port_count+=1
        else
            echo "${port_name}${num} Lanes 5-8  ------- [PASS]; Diff = ${diff} dB , Composite TX = ${tx_dbm1} dBm , Composite RX = ${rx_dbm1} dBm"
            ((pass++))
            let port_count+=1
        fi
    done
}

main()
{
    pass=0
    err1=0  #Not all TX dBm is more than -0.5 value.
    err2=0  #Not all RX dBm is less than TX dBm.
    err3=0  #Not all difference are less than 1.
    final=0
    port_count=0
    pass1=0
    for set in {0..7}
    do
    	Array=("1@3" "5@7" "9@11" "13@15" "17@19" "21@23" "25@27" "29@31") 
	StartNum=$(echo ${Array[${set}]} | awk -F '@' '{print$1}')
	EndNum=$(echo ${Array[${set}]} | awk -F '@' '{print$2}')
    	check_IL ${StartNum} ${EndNum}
	echo "Current is checking set ${set} with start num : ${StartNum} and end num : ${EndNum}"
    
	echo "Pass rate = $pass/${port_count} = $(echo "($pass/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
	echo "${type1err}"
	echo "Error rate = $err1/${port_count} = $(echo "($err1/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
	echo "${type2err}"
	echo "Error rate = $err2/${port_count} = $(echo "($err2/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
	echo "${type3err}"
	echo "Error rate = $err3/${port_count} = $(echo "($err3/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
    done
#if [ "${final}" -ne "0" ] || [ "${final1}" -ne "0" ];then
	if [ "${final}" -ne "0" ];then
		return 1
	else
		return 0
	fi
}

#main | tee "$output_file2"
main
if [ "${PIPESTATUS[0]}" -ne "0" ];then
        show_fail_msg "SW-${index} Insertion Loss Test"
        exit 1
else
        show_pass_msg "SW-${index} Insertion Loss Test"
        exit 0
fi

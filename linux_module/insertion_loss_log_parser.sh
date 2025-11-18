#!/bin/bash

# set -x
function print_help() {
    cat <<EOF
    Usage: $(basename $0) -f [Filename]
    Example: $(basename $0) -f /log/Diag/abc.log
EOF
}

while getopts f: OPT; do
    case "${OPT}" in
        "f")
            logfile=${OPTARG}
            #echo "logfile=$logfile"
            if [ ! -f "${logfile}" ];then
                echo "Can not find log file ${logfile}. Please check the file manually first."
                exit 1
            fi
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

dBvalue=1.8
type1err="Type 1 Error : Composite TX is less than 1 mW."
type2err="Type 2 Error : TX is less than RX."
type3err="Type 3 Error : dB value = $dBvalue or greater."

port_count=0

mW_to_dBm() {
    local mW=$1
    local R=50  #dBm=$(echo "scale=4; 10 * l(($mV^2 / ($R * 1000))) / l(10)" | bc -l)
    dBm=$(echo "scale=4; 10 * l($mW) / l(10)" | bc -l)
    echo "$dBm"
}


main()
{
pass=0
err1=0  #Not all TX dBm is more than -0.5 value.
err2=0  #Not all RX dBm is less than TX dBm.
err3=0  #Not all difference are less than 1.
final=0
for pim in $(grep "Pim #" "$input_file" | awk '{print $2}' | cut -d'#' -f2 | sort -u -n); do
    for port in $(grep "Pim #$pim Port #" "$input_file" | awk '{print $4}' | cut -d'#' -f2 | sort -u -n); do

        tx_values=$(grep -A 18 "Pim #$pim Port #$port eeprom information" "$input_file" | grep "Tx" | head -n 4 | awk '{print $(4)}')
        rx_values=$(grep -A 18 "Pim #$pim Port #$port eeprom information" "$input_file" | grep "Rx" | head -n 4 | awk '{print $(4)}')
        tx_array=()
        for tx in $tx_values; do
                tx_array+=("$tx")
        done

        rx_array=()
        for rx in $rx_values; do
                rx_array+=("$rx")
        done

        i=1
	res=0
	tx_sum=0
        for tx in "${tx_array[@]}"; do
	#	echo "tx_sum=${tx_sum} + ${tx}"
		tx_sum=`echo "${tx_sum} + ${tx}"|bc`
        done
	#echo "Pim #$pim Port #$port Tx sum = ${tx_sum}"	
        if (( $(echo "${tx_sum} < 1" | bc -l) )); then
		echo "Pim #$pim Port #$port  ------- [FAIL] ; ${type1err}.Composite TX = ${tx_sum} mW"
		((err1++))
	    ((final++))
        let port_count+=1
		continue
	fi
	
	i=1
	res=0
	rx_sum=0
        for rx in "${rx_array[@]}"; do
	#	echo "rx+sum=${rx_sum} + ${rx}"
		rx_sum=`echo "${rx_sum} + ${rx}"|bc`
        done

    tx_dbm=$(mW_to_dBm ${tx_sum})
    rx_dbm=$(mW_to_dBm ${rx_sum})
    diff=$(echo "scale=1;(${tx_dbm} - ${rx_dbm})/1" | bc)
    #diff=`echo "scale=1;(${tx_dbm} - ${rx_dbm})"|bc`
	#echo "Pim #$pim Port #$port Rx sum = ${rx_sum}"	
	#echo "tx_sum=$tx_sum , rx_sum=$rx_sum"
	if (( $(echo "${rx_sum} > ${tx_sum}" | bc -l) ));then
                #echo "Pim #$pim Port #$port ------- [FAIL] ; ${type2err} Composite TX = ${tx_sum} mW, Composite Rx = ${rx_sum} mW."
                echo "Pim #$pim Port #$port ------- [FAIL] ; ${type2err} Diff : ${diff} dB"
		
#grep -A 18 "Pim #$pim Port #$port eeprom information" "$input_file" | grep "Tx" | head -n 4
		#grep -A 18 "Pim #$pim Port #$port eeprom information" "$input_file" | grep "Rx" | head -n 4
		((err2++))
	    	((final++))
            let port_count+=1
            continue
        fi

	tx_dbm=$(mW_to_dBm ${tx_sum})
	rx_dbm=$(mW_to_dBm ${rx_sum})
    diff=$(echo "scale=1;(${tx_dbm} - ${rx_dbm})/1" | bc)
	echo "Pim #$pim Port #$port :"	
        echo "Composite Tx = ${tx_sum} mW = ${tx_dbm} dBm ; Composite Rx = ${rx_sum} mW = ${rx_dbm} dBm ; Difference = ${diff} dB"
	if (( $(echo "${diff} >= $dBvalue " | bc -l) )); then
        #echo "Composite Tx = ${tx_sum} mW = ${tx_dbm} dBm ; Composite Rx = ${rx_sum} mW = ${rx_dbm} dBm ; Difference = ${diff} dB"
	    echo "Pim #$pim Port #$port ------- [FAIL] ; ${type3err} Diff = ${diff} dB"
	    ((err3++))
	    ((final++))
	else	
            #echo "Pim #$pim Port #$port ------- [PASS]"
	    ((pass++))
	fi
    let port_count+=1
    done
done

echo "Pass rate = $pass/${port_count} = $(echo "($pass/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
echo "${type1err}"
echo "Error rate = $err1/${port_count} = $(echo "($err1/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
echo "${type2err}"
echo "Error rate = $err2/${port_count} = $(echo "($err2/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
echo "${type3err}"
echo "Error rate = $err3/${port_count} = $(echo "($err3/${port_count})*100" | bc -l | printf "%03.2f\n" $(cat)) %"
if [ "${final}" -ne "0" ];then
	return 1
else
	return 0
fi
}

#main | tee "$output_file2"
main
if [ "${PIPESTATUS[0]}" -ne "0" ];then
        echo "Insertion Loss Test ----------- [FAIL]"
        exit 1
else
        echo "Insertion Loss Test ----------- [PASS]"
        exit 0
fi

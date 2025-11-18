#!/bin/bash

set -x

#pwd

#ls ../

source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"


switch_index=1

while getopts s:i: OPT; do
    case "${OPT}" in
        "s")
			RackSN=${OPTARG}
			check_sn ${RackSN}
			RackIPN=$(cat ${LOGPATH}/${RackSN}/rackipn.txt)
			RackAsset=$(cat ${LOGPATH}/${RackSN}/assetid.txt)
			wedge400IP=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/mac_ip.txt)
			wedge400SN=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/serialnumber.txt)
		;;
        "i")
			index=${OPTARG}
			if [ -z "${index}" ];then
				print_help
				return 1
			fi 
		;;
        *)
			print_help
			return 1
		;;
    esac
done

Normal_Function_Diagnostic_test()
{
    SMBFRUInfo=("Version" "Product Name" "Product Part Number" "System Assembly Part Number" "Facebook PCBA Part Number" "Facebook PCB Part Number" "ODM PCBA Part Number" "ODM PCBA Serial Number" "Product Production State" "Product Version" "Product Sub-Version" "Product Serial Number" "Product Asset Tag" "System Manufacturer" "System Manufacturing Date" "PCB Manufacturer" "Assembled At" "Local MAC" "Extended MAC Base" "Extended MAC Address Size" "Location on Fabric" "CRC8") 

    SMBFRU_DATA=("3" "WEDGE400-48VDC-F" "20-002948" "00-000000" "132-000137-02" "131-000103-02" "R1149G900102" "GE[0-9]{11}" "4" "4|5" "0" "FH[0-9]{11}" "[0-9]{8}" "CLS" "^[0-1][0-9]-[0-3][0-9]-[0-9]{2}$" "WUS|ISU" "CTH" "[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}" "[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}" "143" "SMB" "0x[0-9a-z]{2}")
    #SMBFRU_DATA=("3" "WEDGE400-48VDC-F" "20-002948" "00-000000" "132-000137-02" "131-000103-02" "R1149G900102" "GE[0-9]{11}" "4" "4" "0" "FH[0-9]{11}" "[0-9]{8}" "CLS" "^[0-1][0-9]-[0-3][0-9]-[0-9]{2}$" "WUS" "CTH" "[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}" "[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}" "143" "SMB" "0x[0-9a-z]{2}")

    echo "Product Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 1
    exeucte_test "/usr/bin/weutil" "${wedge400IP}" | tee ${diagnosticLog}
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/bin/weutil"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    status=$(cat ${diagnosticLog} | grep "CRC8" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
	update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 3
        return 1
    fi

    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${SMBFRU_DATA[@]}")
    for i in "${!SMBFRUInfo[@]}"; do
	record_time "HPRv3_Wedge400" start "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
        if [ "${SMBFRUInfo[$i]}" == "ODM PCBA Serial Number" ] || [ "${SMBFRUInfo[$i]}" == "PCB Manufacturer" ] || [ "${SMBFRUInfo[$i]}" == "Local MAC" ]  || [ "${SMBFRUInfo[$i]}" == "Extended MAC Base" ] || [ "${SMBFRUInfo[$i]}" == "Product Serial Number" ] || [ "${SMBFRUInfo[$i]}" == "Product Asset Tag" ] || [ "${SMBFRUInfo[$i]}" == "System Manufacturing Date" ] || [ "${SMBFRUInfo[$i]}" == "CRC8" ] || [ "${SMBFRUInfo[$i]}" == "Product Version" ];then
            logResultCheck "CheckEGREPFormat" "${SMBFRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
                record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 3
                return 1
            else
                show_pass_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 2
            fi
        elif [ "${SMBFRUInfo[$i]}" == "System Assembly Part Number" ];then                 
            logResultCheck "ZeroValueCheck" "${SMBFRUInfo[$i]}" "NF;NF" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                show_fail_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"                         
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 3
		return 1
            else                         
                show_pass_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"                         
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"       
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 2          
            fi
	elif [ "${SMBFRUInfo[$i]}" == "Version" ];then
		logResultCheck "LogCheck" "^${SMBFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
                record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 3
		return 1
            else
                show_pass_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 2
            fi
        else
            logResultCheck "LogCheck" "${SMBFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                show_fail_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"                         
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 3
                return 1
            else                         
                show_pass_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${SMBFRUInfo[$i]}"                         
                record_time "HPRv3_Wedge400" end "SMB_FRU_Information_Check;${SMBFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"         
		update_status "$SN" "$folder" "$index" "$testitem" "Product Information" 2       
            fi
        fi
    done

    echo "-------------------"
    echo "Sensor Check Test"
    exeucte_test "/usr/local/bin/sensor-util all" "${wedge400IP}"  | grep -Ev "command" | tee ${diagnosticLog}
    update_status "$SN" "$folder" "$index" "$testitem" "Sensor Check" 1
    SYSTEM_AIRFLOW_check_info=$(grep "SYSTEM_AIRFLOW" "${diagnosticLog}" | awk -F ' ' '{print $NF}' || echo "NA")
    if [[ "$SYSTEM_AIRFLOW" == "NA" ]]; then
        show_fail_msg "SYSTEM_AIRFLOW is empty, please check"
        let res+=1
    fi

    grep -Ev "^[a-zA-Z0-9_]+:|SYSTEM_AIRFLOW" "${diagnosticLog}" > "${finalSensorLog}"

    failed_sensors=()
    while read -r line; do
        [[ -z "$line" ]] && continue
        if [[ ! "$line" =~ \|[[:space:]]\(ok\) ]]; then
            failed_sensors+=("$line")
        fi
    done < "${finalSensorLog}"

    if [[ ${#failed_sensors[@]} -eq 0 ]]; then
        show_pass_msg "Rack Module Test -- Sensor Test"                         
        record_time "HPRv3_Wedge400" end "Sensor Test;NA" "OK" "PASS" "${RackSN}" 
	update_status "$SN" "$folder" "$index" "$testitem" "Sensor Check" 2
    else
        show_fail_msg "Rack Module Test -- Sensor Test -> ${failed_sensors[@]}"                         
        record_time "HPRv3_Wedge400" end "Sensor Test;${failed_sensors[@]}" "OK" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "Sensor Check" 3
	return 1
    fi

    echo "-------------------"
    echo "SSD FW Check Test"
    executeCMDinDiagBMCOS "nvme id-ctrl /dev/nvme0" ${wedge400IP}  | tee ${diagnosticLog}
    update_status "$SN" "$folder" "$index" "$testitem" "SSD FW Check" 1
    cat "${diagnosticLog}" | sed -n '/NVME Identify Controller/,/command finish/ p' | sed '$d' | grep -Ev "sn|wctemp|cctemp|subnqn" > "${SSDFWLog}" 
    grep -Ev "sn|wctemp|cctemp|subnqn" "${INIPATH}/Wedge400_SSDFW.ini" > "${LOGPATH}/${RackSN}/Filtered_wedge400_SSDFW_Standard.log"

    diff -bB "${SSDFWLog}" "${LOGPATH}/${RackSN}/Filtered_wedge400_SSDFW_Standard.log" > "${LOGPATH}/${RackSN}/wedge400_SSDFW_Diff.log"

    Serial_number_log=$(grep "sn" "${diagnosticLog}" | awk -F ': ' '{print $2}' | tr -d ' ' | tr -d '\r\n'|| echo "")
    Serial_number_ini=$(grep "sn" "${INIPATH}/Wedge400_SSDFW.ini" | awk -F ': ' '{print $2}' || echo "")
    
    Serial_number_len_log=${#Serial_number_log}
    Serial_number_len_ini=${#Serial_number_ini}

    SSDFW_subnqn_log=$(grep "subnqn" "${diagnosticLog}" | awk -F ': ' '{print $2}' | tr -d ' ' | tr -d '\r\n' || echo "")
    SSDFW_subnqn_ini=$(grep "subnqn" "${INIPATH}/Wedge400_SSDFW.ini" | awk -F ': ' '{print $2}' || echo "")

    SSDFW_subnqn_len_log=${#SSDFW_subnqn_log}
    SSDFW_subnqn_len_ini=${#SSDFW_subnqn_ini}

    if [[ -s "${LOGPATH}/${RackSN}/wedge400_SSDFW_Diff.log" ]]; then
        show_fail_msg "Rack Module Test -- SSD FW Test -- Info Error"                         
        record_time "HPRv3_Wedge400" end "SSD FW Test;Info Error" "OK" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "SSD FW Check" 3
    elif [[ $Serial_number_len_log -lt "10" ]]; then
        show_fail_msg "Rack Module Test -- SSD FW Test -- SN Error"                         
        record_time "HPRv3_Wedge400" end "SSD FW Test;SN Error" "OK" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "SSD FW Check" 3
    elif [[ $SSDFW_subnqn_len_log -lt "5" ]]; then
        show_fail_msg "Rack Module Test -- SSD FW Test -- Asset Error"                         
        record_time "HPRv3_Wedge400" end "SSD FW Test;Asset Error" "OK" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "SSD FW Check" 3     
    else
        show_pass_msg "Rack Module Test -- SSD FW Test"                         
        record_time "HPRv3_Wedge400" end "SSD FW Test;NA" "OK" "PASS" "${RackSN}" 
	update_status "$SN" "$folder" "$index" "$testitem" "SSD FW Check" 2
    fi

    #logResultCheck "LogCheck" "${key}" "PASS;NF" "${LOGPATH}/${RackSN}/Wedge400_NVME_SSD.log"
    #if [ ${PIPESTATUS[0]} -ne 0 ];then
    #    show_fail_msg "Syslog Check Test -- ${key}" 
    #    return 1
    #else
    #    show_pass_msg "Syslog Check Test -- ${key}" 
    #fi

    echo "Switch SW Version Check Test"
    SWInfo=("Diag Version" "OS Diag" "OS Version" "Kernel Version" "BMC Version" "BIOS Version" "FPGA1 Version" "FPGA2 Version" "SCM CPLD Version" "SMB CPLD Version" "I210 FW Version") 

    SW_DATA=("3.7.0" "2.1.4" "7.4.1708" "4.19.17" "4.76" "XG1_3A12" "1.12" "1.12" "4.1" "4.6" "3.25")

    echo "Product Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "Switch FW Check" 1
    executeCMDinDiagBMCOS "cd /usr/local/cls_diag/bin;./cel-version-test --show" "${wedge400IP}" "" | tee ${diagnosticLog}
    status=$(cat ${diagnosticLog} | grep "I210 FW Version" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
	update_status "$SN" "$folder" "$index" "$testitem" "Switch FW Check" 3
        return 1
    fi

    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${SW_DATA[@]}")
    for i in "${!SWInfo[@]}"; do
        logResultCheck "LogCheck" "^${SWInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"                 
        if [ ${PIPESTATUS[0]} -ne 0 ];then                         
            show_fail_msg "Rack Module Test -- Product_Information_Check Test -> ${SWInfo[$i]}"                         
            record_time "HPRv3_Wedge400" end "Product_Information_Check;${SWInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
            record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "Switch FW Check" 3
	    return 1
        else                         
            show_pass_msg "Rack Module Test -- Product_Information_Check Test -> ${SWInfo[$i]}"                         
            record_time "HPRv3_Wedge400" end "Product_Information_Check;${SWInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"               
	    update_status "$SN" "$folder" "$index" "$testitem" "Switch FW Check" 2  
        fi
    done


    echo "PSU Shelf Information Test"
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    exeucte_test "/usr/local/bin/presence_util.sh" "${wedge400IP}" | tee ${diagnosticLog}
    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 1	
    record_time "HPRv3_Wedge400" start "PSU1_Presence_Test;PSU1" "0" "NA" "${RackSN}"                         
    logResultCheck "LogCheck" "psu1" "NF;0" "${diagnosticLog}"                 
    if [ ${PIPESTATUS[0]} -ne 0 ];then                         
        show_fail_msg "Rack Module Test -- PSU Presence Test -> PSU1"                         
        record_time "HPRv3_Wedge400" end "PSU1_Presence_Test;PSU1" "0" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
	return 1
    else                         
        show_pass_msg "Rack Module Test -- PSU Presence Test -> PSU1"                         
        record_time "HPRv3_Wedge400" end "PSU1_Presence_Test;PSU1" "0" "PASS" "${RackSN}"   
	update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2              
    fi

    logResultCheck "LogCheck" "psu2" "NF;1" "${diagnosticLog}"   
    record_time "HPRv3_Wedge400" start "PSU2_Presence_Test;PSU1" "0" "NA" "${RackSN}"                                       
    if [ ${PIPESTATUS[0]} -ne 0 ];then                         
        show_fail_msg "Rack Module Test -- PSU Presence Test -> PSU2"                         
        record_time "HPRv3_Wedge400" end "PSU2_Presence_Test;PSU2" "1" "FAIL" "${RackSN}"                         
        record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
	    return 1
    else                         
        show_pass_msg "Rack Module Test -- PSU Presence Test -> PSU2"                         
        record_time "HPRv3_Wedge400" end "PSU2_Presence_Test;PSU2" "1" "PASS" "${RackSN}"     
	    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2            
    fi
}

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/diagnosticlog_wg400.txt
LOGFILE=${LOGFOLDER}/log.txt
finalSensorLog=${LOGPATH}/${RackSN}/sensor_test.log
SSDFWLog=${LOGPATH}/${RackSN}/ssd_test.log
folder=RUSW

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_Wedge400" initial "" "" "" "$RackSN"  
ssh-keygen -R "${wedge400IP}" > /dev/null

Normal_Function_Diagnostic_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "HPRv3 Wedge400 Standalone Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_WEDGE400_${switch_index}_${wedge400SN}_Function_FAIL_${startTime}.log
    record_time "HPRv3_Wedge400" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    #cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

show_pass_msg "HPRv3 Wedge400 Standalone Test" | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_WEDGE400_${switch_index}_${wedge400SN}_Function_PASS_${startTime}.log
record_time "HPRv3_Wedge400" total "HPRv3_Wedge400;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_Wedge400" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

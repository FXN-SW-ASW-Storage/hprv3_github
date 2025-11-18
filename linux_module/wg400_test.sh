#!/bin/bash

source ../commonlib

print_help(){

    cat <<EOF
    Usage: ./$(basename $0) -s RACK_SN -i Switch_Index
        s : Rack serial Number.
        i : WG400 location ID.Should be 1 only now.
    Example: ./$(basename $0) -s GD123456789 -i 1
EOF
}
disable_log=0
while getopts s:i:g OPT; do
    case "${OPT}" in
        "s")
            SN=${OPTARG}
            check_sn ${SN}
            ;;
        "i")
            index=${OPTARG}
            if [ -z "${index}" ];then
                print_help
                exit 1
            fi
            ;;
        "g")
            disable_log=1
            ;;
        *)
            echo "Wrong Parameter..."
            echo "Usage: $(basename $0) -s SN -p logpath"
            exit 1
            ;;
    esac
done


base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${SN}
JSONFILE=${LOGFOLDER}/${SN}.JSON
folder="RUSW"
LOGFILE=${LOGFOLDER}/${folder}/${index}/${filename}

if [ -z "${SN}" ] || [ -z "${index}" ];then
    print_help
    exit 1
fi

if [ -f "${LOGFOLDER}/${folder}/${index}/last_main_log_name.txt" ];then
    rm -rf "${LOGFOLDER}/${folder}/${index}/last_main_log_name.txt"
fi

Normal_Function_Diagnostic_test()
{
    res=0
    echo "-------------------"
    echo "Rack Module Information Test"
    exeucte_test "/usr/local/bin/rackmoninfo" "${sw_ip}"  | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log
    exeucte_test "/usr/local/bin/rackmoncli data" "${sw_ip}"  | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoncli_data.log

    echo "-------------------"
    echo "GPIO Signal Test"

    exeucte_test "cat /tmp/gpionames/RMON*/value" "${sw_ip}"  | grep -Ev "command" | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_GPIOsignal.log

    diff -bB "${LOGPATH}/${SN}/${folder}/${index}/wedge400_GPIOsignal.log" "${INIFILE}/Wedge400_GPIOsignal.ini" > "${LOGPATH}/${SN}/${folder}/${index}/wedge400_GPIOsignal_Diff.log"

    if [ $? -eq 0 ]; then
        show_pass_msg "GPIO Signal Test "
    else
        show_fail_msg "GPIO Signal Test "
        echo "CPLD Version ERROR:" 
        cat "${LOGPATH}/${SN}/${folder}/${index}/wedge400_GPIOsignal_Diff.log" 
        let res+=1
    fi

    echo "-------------------"
    echo "PSU address Test"
     
    PSU_address=(
        "Device Address: 0xe8"
        "Device Address: 0xe9"
        "Device Address: 0xea"
        "Device Address: 0xeb"
        "Device Address: 0xec"
        "Device Address: 0xed"
    )
   
    empty_PSU=() 
    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"

    for addr in "${PSU_address[@]}"; do
        if ! grep -q "$addr" "$logfile"; then
            empty_PSU+=("$addr")
        fi
    done

    if [[ ${#empty_PSU[@]} -eq 0 ]]; then
        for a in "${PSU_address[@]}"; do
            echo "$a"
        done
        show_pass_msg "PSU address Test"
    else
        show_fail_msg "PSU address Test"
        echo "missing PSU address"
        for m in "${missing[@]}"; do
            echo "$m"
        done
        let res+=1
    fi 
      
    echo "-------------------"
    echo "PSU FBPN match Test"

    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"
    
    FBPN_value="03-001166"

    values=$(awk -F'"' '/PSU_FBPN<0x0000>/ {print $2}' "$logfile")

    fail_flag=0
      
    device_addr=""
    current_FBPN=""
    current_SN=""

    while IFS= read -r line; do
        if [[ "$line" =~ Device\ Address:\ ([0-9a-zA-Z]+) ]];then
            device_addr="${BASH_REMATCH[1]}"
            current_FBPN=""
            current_SN=""
            continue
        fi

        if [[ "$line" =~ PSU_FBPN\<0x0000\>\ :\ \"([^\"]+)\" ]]; then
            current_FBPN=$(echo "${BASH_REMATCH[1]}" | xargs)
            continue
        fi

        if [[ "$line" =~ PSU_MFR_Serial\<0x0018\>\ :\ \"([^\"]+)\" ]]; then
            current_SN=$(echo "${BASH_REMATCH[1]}" | xargs)
            continue
        fi

        if [[ -n "$current_FBPN" && -n "$current_SN" ]]; then
            if [[ "$current_FBPN" == "$FBPN_value" ]]; then
              echo "Device Address: $device_addr | FBPN: $current_FBPN | Serial Number: $current_SN"
    #        current_FBPN=""
     #       current_SN=""
            else
                echo "Device Address: $device_addr | Serial Number: $current_SN"
                echo "FBPN is not match $FBPN_value"
            
              
                fail_flag=1
            fi        
            current_FBPN=""
            current_SN=""
        fi
    done < "$logfile"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU FBPN match Test"
    else
        show_fail_msg "PSU FBPN match Test"
    fi

    echo "-------------------"
    echo "PSU Supplier Check test"

    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"

    fail_flag=0

    device_addr=""
    current_MPN=""

    while IFS= read -r line; do
       
        #if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]];then
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
 
           if [[ -n $device_addr && -z $current_MPN ]]; then
                echo "Device Address: $device_addr | MPN is wrong or empty!"
                fail_flag=1
            fi 
            device_addr="${BASH_REMATCH[1]}"
            current_MPN=""
            continue
        fi

#        if [[ $line =~ [[:space:]]*PSU_MFR_Model<0x0008>[[:space:]]*:[[:space:]]*(ECD[0-9]{8})[[:space:]]* ]]; then
        if [[ $line =~ [[:space:]]*PSU_MFR_Model\<0x0008\>[[:space:]]*:[[:space:]]*\"(ECD[0-9]{8})[[:space:]]*\" ]]; then
 
            current_MPN="${BASH_REMATCH[1]}"
            if [[ -n "$device_addr" ]]; then
                echo "Device Address: $device_addr | MPN: $current_MPN | Supplier: DELTA"
            fi

            device_addr=""
            current_MPN=""
            continue
        fi
        
    done < "$logfile"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU Supplier Check test"
    else
        show_fail_msg "PSU Supplier Check test"
    fi

    echo "-------------------"
    echo "PSU Manufacturer Date Check test"

    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"

    fail_flag=0

    device_addr=""
    current_DATE=""

    while IFS= read -r line; do

        #if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]];then
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then

           if [[ -n $device_addr && -z $current_DATE ]]; then
                echo "Device Address: $device_addr | DATE is wrong or empty!"
                fail_flag=1
            fi
            device_addr="${BASH_REMATCH[1]}"
            current_DATE=""
            continue
        fi

#        if [[ $line =~ [[:space:]]*PSU_MFR_Model<0x0008>[[:space:]]*:[[:space:]]*(ECD[0-9]{8})[[:space:]]* ]]; then
        if [[ $line =~ [[:space:]]*PSU_MFR_Date\<0x0010\>[[:space:]]*:[[:space:]]*\"((0[1-9]|1[0-2])/20(24|25))[[:space:]]*\" ]]; then

            current_DATE="${BASH_REMATCH[1]}"
            if [[ -n "$device_addr" ]]; then
                echo "Device Address: $device_addr | Manufacturer Date: $current_DATE"
            fi

            device_addr=""
            current_DATE=""
            continue
        fi

    done < "$logfile"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU Manufacturer Date Check test"
    else
        show_fail_msg "PSU Manufacturer Date Check test"
    fi

    echo "-------------------"
    echo "PSU SN Check test"

    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"

    fail_flag=0

    device_addr=""
    current_SN=""

    while IFS= read -r line; do

        #if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]];then
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then

           if [[ -n $device_addr && -z $current_SN ]]; then
                echo "Device Address: $device_addr | DATE is wrong or empty!"
                fail_flag=1
            fi
            device_addr="${BASH_REMATCH[1]}"
            current_SN=""
            continue
        fi

#        if [[ $line =~ [[:space:]]*PSU_MFR_Model<0x0008>[[:space:]]*:[[:space:]]*(ECD[0-9]{8})[[:space:]]* ]]; then
        if [[ $line =~ [[:space:]]*PSU_MFR_Serial\<0x0018\>[[:space:]]*:[[:space:]]*\"((0[1-9]|1[0-2])(24|25)[A-Z][0-9][A-Z][0-9]DET[0-9]{5})[[:space:]]*\" ]]; then

            current_SN="${BASH_REMATCH[1]}"
            if [[ -n "$device_addr" ]]; then
                echo "Device Address: $device_addr | PSU SN: $current_SN"
            fi

            device_addr=""
            current_SN=""
            continue
        fi

    done < "$logfile"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU SN Check test"
    else
        show_fail_msg "PSU SN Check test"
    fi

    echo "-------------------"
    echo "PMM Address and Modbus Cabling Check Test"

    exeucte_test "/usr/local/bin/rackmoncli list" "${sw_ip}"  | grep -Ev "command" | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoncli_list.log

    invalid_addresses=($(awk -F '|' '{gsub(/ /, "", $3); if ($3 ~ /^[0-9]+$/ && $3 == 0) {print $3}}' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoncli_list.log"))

    if [[ ${#invalid_addresses[@]} -eq 0 ]]; then
        show_pass_msg "PMM Address and Modbus Cabling Check Test "
    else
        show_fail_msg "PMM Address and Modbus Cabling Check Test "
        echo "Address: ${invalid_addresses[*]}" 
        let res+=1
    fi

    echo "-------------------"
    echo "PSU_Input_Voltage_AC Check Test"
    echo "Check the value is between 200 & 300"
    
    PSU_Input_Voltage_AC=$(grep "0x0058" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" | awk -F ': ' '{print $2}' || echo "")

    fail_flag=0
    error_values=()

    while read -r value; do
        if [[ -n "$value" ]]; then
            if (( $(echo "$value < 200" | bc -l) || $(echo "$value > 300" | bc -l) )); then
                fail_flag=1
                error_values+=("$value")
            fi
        fi
    done <<< "$PSU_Input_Voltage_AC"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU_Input_Voltage_AC Check Test  Value: $PSU_Input_Voltage_AC"
    else
        show_fail_msg "PSU_Input_Voltage_AC Check Test  Value: $PSU_Input_Voltage_AC"
        let res+=1
    fi        
    
    echo "-------------------"
    echo "PSU_Output_Power Check Test"
    echo "Check the value is between 0 & 6600"
    
    PSU_Output_Power=$(grep "0x0052" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" | awk -F ': ' '{print $2}' || echo "")
    
    fail_flag=0
    error_values=()

    while read -r value; do
        if [[ -n "$value" ]]; then
            if (( $(echo "$value < 0" | bc -l) || $(echo "$value > 6600" | bc -l) )); then
                fail_flag=1
                error_values+=("$value")
            fi
        fi
    done <<< "$PSU_Output_Power"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU_Output_Power Check Test  Value: $PSU_Output_Power"
    else
        show_fail_msg "PSU_Output_Power Check Test  Value: $PSU_Output_Power"
        let res+=1
    fi


    echo "-------------------"
    echo "PSU_Output_Voltage Check Test"
    echo "Check the value is between 48 & 50.5"
    
    PSU_Output_Voltage=$(grep "0x004f" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" | awk -F ': ' '{print $2}' || echo "")
    
    fail_flag=0
    error_values=()

    while read -r value; do
        if [[ -n "$value" ]]; then
            if (( $(echo "$value < 48" | bc -l) || $(echo "$value > 51" | bc -l) )); then
                fail_flag=1
                error_values+=("$value")
            fi
        fi
    done <<< "$PSU_Output_Voltage"

    if [[ $fail_flag -eq 0 ]]; then
        show_pass_msg "PSU_Output_Voltage Check Test  Value: $PSU_Output_Voltage"
    else
        show_fail_msg "PSU_Output_Voltage Check Test  Value: $PSU_Output_Voltage"
        let res+=1
    fi

    echo "-------------------"
    echo "PSU General_Alarm_Status_Register Test"

    logfile="${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log"

    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi
        
        if [[ $line =~ [[:space:]]*General_Alarm_Status_Register\<0x003c\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alram_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | General register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | General register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\](.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"
            
                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alrm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"

    echo "-------------------"
    echo "General_Alarm_Status_Register Test"

    filtered_log="${LOGPATH}/${SN}/${folder}/${index}/wedge400_General_Alarm_Extracted.log"
    awk '
        /General_Alarm_Status_Register<0x003c>/ {inside=1; next}
        inside && /^[[:space:]]*\[[0-9]+\]/ {print}  
        inside && /_Alarm_Status_Register/ {inside=0}
    ' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" > "$filtered_log"

    declare -a failed_alarms

    err_file=${LOGPATH}/${SN}/${folder}/${index}/error_summary_gen.log
    rm -rf ${err_file}
    while read -r line; do
        echo "$line" | awk '
        {
            match($0, /\[([0-9]+)\] [^<]+<([0-3])>/, arr);
            if (arr[1] != "" && arr[2] != "" && arr[1] != "0") {
                print $0;
            }   
        }' >> "${err_file}" 
    done < "$filtered_log"

    if [[ -s "${err_file}" ]]; then
        show_fail_msg "General Alarm Status Register Check "
        cat ${err_file}
        let res+=1
    else
        show_pass_msg "General Alarm Status Register Check "
    fi

    echo "-------------------"
    echo "PFC Alarm Status Register Test"

    filtered_log="${LOGPATH}/${SN}/${folder}/${index}/wedge400_PFC_Alarm_Status_Register.log"
    awk '
        /PFC_Alarm_Status_Register<0x003d>/ {inside=1; next}
        inside && /^[[:space:]]*\[[0-9]+\]/ {print}  
        inside && /_Alarm_Status_Register/ {inside=0}
    ' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" > "$filtered_log"

    declare -a failed_alarms

    err_file=${LOGPATH}/${SN}/${folder}/${index}/error_summary_pfc.log
    rm -rf ${err_file}
    while read -r line; do
        echo "$line" | awk '
        {
            match($0, /\[([0-9]+)\] [^<]+<([11|12])>/, arr);
            if (arr[1] != "" && arr[2] != "" && arr[1] != "0") {
                print $0;
            }   
        }' >> "${err_file}" 
    done < "$filtered_log"

    if [[ -s "${err_file}" ]]; then
        show_fail_msg "PFC Alarm Status Register Check "
        cat ${err_file}
        let res+=1
    else
        show_pass_msg "PFC Alarm Status Register Check "
    fi


    echo "-------------------"
    echo "DCDC_Alarm_Status_Register Test"

    filtered_log="${LOGPATH}/${SN}/${folder}/${index}/wedge400_DCDC_Alarm_Status_Register.log"
    awk '
        /DCDC_Alarm_Status_Register<0x003e>/ {inside=1; next}
        inside && /^[[:space:]]*\[[0-9]+\]/ {print}  
        inside && /_Alarm_Status_Register/ {inside=0}
    ' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" > "$filtered_log"

    declare -a failed_alarms

    err_file=${LOGPATH}/${SN}/${folder}/${index}/error_summary_dcdc.log
    rm -rf ${err_file}
    while read -r line; do
        echo "$line" | awk '
        {
            match($0, /\[([0-9]+)\] [^<]+<([0-9]+)>/, arr);
            if (arr[1] != "" && arr[2] != "" && arr[1] != "0") {
                print $0;
            }   
        }' >> "${err_file}"
    done < "$filtered_log"

    if [[ -s "${err_file}" ]]; then
        show_fail_msg "DCDC Alarm Status Register Check "
        cat ${err_file}
        let res+=1
    else
        show_pass_msg "DCDC Alarm Status Register Check "
    fi



    echo "-------------------"
    echo "Temperature_Alarm_Status_Register Test"

    filtered_log="${LOGPATH}/${SN}/${folder}/${index}/wedge400_Temperature_Alarm_Status_Register.log"
    awk '
        /Temperature_Alarm_Status_Register<0x003f>/ {inside=1; next}
        inside && /^[[:space:]]*\[[0-9]+\]/ {print}  
        inside && /_Alarm_Status_Register/ {inside=0}
    ' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" > "$filtered_log"

    declare -a failed_alarms

    err_file=${LOGPATH}/${SN}/${folder}/${index}/error_summary_temp.log
    rm -rf ${err_file}
    while read -r line; do
        echo "$line" | awk '
        {
            match($0, /\[([0-9]+)\] [^<]+<([0|2|3|4|5|8])>/, arr);
            if (arr[1] != "" && arr[2] != "" && arr[1] != "0") {
                print $0;
            }   
        }' >> "${err_file}" 
    done < "$filtered_log"

    if [[ -s "${err_file}" ]]; then
        show_fail_msg "Temperature Alarm Status Register Check "
        cat ${err_file}
        let res+=1
    else
        show_pass_msg "Temperature Alarm Status Register Check "
    fi



    echo "-------------------"
    echo "Communication_Alarm_Status_Register Test"

    filtered_log="${LOGPATH}/${SN}/${folder}/${index}/wedge400_Communication_Alarm_Status_Register.log"
    awk '
        /Communication_Alarm_Status_Register<0x0040>/ {inside=1; next}
        inside && /^[[:space:]]*\[[0-9]+\]/ {print}  
        inside && /PSU_RPM_Fan/ {inside=0}
    ' "${LOGPATH}/${SN}/${folder}/${index}/wedge400_rackmoninfo.log" > "$filtered_log"

    declare -a failed_alarms

    err_file=${LOGPATH}/${SN}/${folder}/${index}/error_summary_com.log
    rm -rf ${err_file}
    while read -r line; do
        echo "$line" | awk '
        {
            match($0, /\[([0-9]+)\] [^<]+<([0])>/, arr);
            if (arr[1] != "" && arr[2] != "" && arr[1] != "0") {
                print $0;
            }   
        }' 
    done < "$filtered_log"

    if [[ -s "${err_file}" ]]; then
        show_fail_msg "Communication Alarm Status Register Check "
        cat ${err_file}
        let res+=1
    else
        show_pass_msg "Communication Alarm Status Register Check "
    fi

    echo "-------------------"
    echo "Product Information Test"
    exeucte_test "/usr/bin/weutil" "${sw_ip}"  | grep -Ev "command" | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log

    grep -Ev "Serial|MAC|Asset|Date|CRC8|Product Version|PCB Manufacturer" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" > "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_productinfo.log"
    grep -Ev "Serial|MAC|Asset|Date|CRC8|Product Version|PCB Manufacturer" "${INIFILE}/Wedge400_ProductInfo.ini" > "${LOGPATH}/${SN}/${folder}/${index}/Filtered_Wedge400_ProductInfo_standard.log"

    diff -bB "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_productinfo.log" "${LOGPATH}/${SN}/${folder}/${index}/Filtered_Wedge400_ProductInfo_standard.log" > "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo_Diff.log"

    Product_serial_log=$(grep "Product Serial Number" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" | awk -F ': ' '{print $2}' || echo "")
    Product_serial_ini=$(grep "Product Serial Number" "${INIFILE}/Wedge400_ProductInfo.ini" | awk -F ': ' '{print $2}' || echo "")
    
    Product_len_log=${#Product_serial_log}
    Product_len_ini=${#Product_serial_ini}

    PCBA_serial_log=$(grep "ODM PCBA Serial Number" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" | awk -F ': ' '{print $2}' || echo "")
    PCBA_serial_ini=$(grep "ODM PCBA Serial Number" "${INIFILE}/Wedge400_ProductInfo.ini" | awk -F ': ' '{print $2}' || echo "")

    PCBA_len_log=${#PCBA_serial_log}
    PCBA_len_ini=${#PCBA_serial_ini}

    Local_MAC_log=$(grep "Local MAC" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" | awk -F ': ' '{print $2}' || echo "")
    Local_MAC_ini=$(grep "Local MAC" "${INIFILE}/Wedge400_ProductInfo.ini" | awk -F ': ' '{print $2}' || echo "")

    Local_MAC_len_log=${#Local_MAC_log}
    Local_MAC_len_ini=${#Local_MAC_ini}

    Extended_MAC_log=$(grep "Extended MAC Base" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" | awk -F ': ' '{print $2}' || echo "")
    Extended_MAC_ini=$(grep "Extended MAC Base" "${INIFILE}/Wedge400_ProductInfo.ini" | awk -F ': ' '{print $2}' || echo "")

    Extended_MAC_len_log=${#Extended_MAC_log}
    Extended_MAC_len_ini=${#Extended_MAC_ini}

    Product_Asset_log=$(grep "Product Asset Tag" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo.log" | awk -F ': ' '{print $2}' || echo "")
    Product_Asset_ini=$(grep "Product Asset Tag" "${INIFILE}/Wedge400_ProductInfo.ini" | awk -F ': ' '{print $2}' || echo "")

    Product_Asset_len_log=${#Product_Asset_log}
    Product_Asset_len_ini=${#Product_Asset_ini}

    if [[ -s "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo_Diff.log" ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information ERROR:" 
        cat "${LOGPATH}/${SN}/${folder}/${index}/wedge400_productinfo_Diff.log" 
        let res+=1
    elif [[ $Product_len_log -ne $Product_len_ini ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information Product Serial Number Wrong Length: log($Product_len_log) vs ini($Product_len_ini)" 
        let res+=1
    elif [[ $PCBA_len_log -ne $PCBA_len_ini ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information PCBA Serial Number Wrong Length: log($PCBA_len_log) vs ini($PCBA_len_ini)" 
        let res+=1
    elif [[ $Local_MAC_len_log -ne $Local_MAC_len_ini ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information Local MAC Wrong Length: log($Local_MAC_len_log) vs ini($Local_MAC_len_ini)" 
        let res+=1
    elif [[ $Extended_MAC_len_log -ne $Extended_MAC_len_ini ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information Extended MAC Wrong Length: log($Extended_MAC_len_log) vs ini($Extended_MAC_len_ini)" 
        let res+=1
    elif [[ $Product_Asset_len_log -ne $Product_Asset_len_ini ]]; then
        show_fail_msg "Product Information Test "
        echo "Product Information Product Asset Wrong Length: log($Product_Asset_len_log) vs ini($Product_Asset_len_ini)" 
        let res+=1        
    else
        show_pass_msg "Product Information Test "
    fi

    echo "-------------------"
    echo "Sensor Check Test"
    exeucte_test "/usr/local/bin/sensor-util all" "${sw_ip}"  | grep -Ev "command" | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_Sensor.log

    SYSTEM_AIRFLOW_check_info=$(grep "SYSTEM_AIRFLOW" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_Sensor.log" | awk -F ' ' '{print $NF}' || echo "NA")
    if [[ "$SYSTEM_AIRFLOW" == "NA" ]]; then
        show_fail_msg "SYSTEM_AIRFLOW is empty, please check"
        let res+=1
    fi

    grep -Ev "^[a-zA-Z0-9_]+:|SYSTEM_AIRFLOW" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_Sensor.log" > "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_Sensor.log"

    failed_sensors=()
    while read -r line; do
        [[ -z "$line" ]] && continue
        if [[ ! "$line" =~ \|[[:space:]]\(ok\) ]]; then
            failed_sensors+=("$line")
        fi
    done < "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_Sensor.log"

    if [[ ${#failed_sensors[@]} -eq 0 ]]; then
        show_pass_msg "Sensor Check Test "
    else
        show_fail_msg "Sensor Check Test "
        echo "Sensor test ERROR!:" 
        printf "%s\n" "${failed_sensors[@]}" 
        let res+=1
    fi
    
    echo "-------------------"
    echo "SSD FW Check Test"
    executeCMDinDiagOS "nvme id-ctrl /dev/nvme0" ${sw_ip}  |tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW.log

    mn_pn=`cat ${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW.log | grep -w mn | awk '{print $3}'`

    cat "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW.log" | sed -n '/NVME Identify Controller/,/command finish/ p' | sed '$d' | grep -Ev "sn|wctemp|cctemp|subnqn" > "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_SSDFW.log" 

    echo "file=\"${INIFILE}/Wedge400_SSDFW_${mn_pn}.ini\""
    grep -Ev "sn|wctemp|cctemp|subnqn" "${INIFILE}/Wedge400_SSDFW_${mn_pn}.ini" > "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_SSDFW_Standard.log"

    diff -bB "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_SSDFW.log" "${LOGPATH}/${SN}/${folder}/${index}/Filtered_wedge400_SSDFW_Standard.log" > "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW_Diff.log"

    Serial_number_log=$(grep "sn" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW.log" | awk -F ': ' '{print $2}' || echo "")
    Serial_number_ini=$(grep "sn" "${INIFILE}/Wedge400_SSDFW_${mn_pn}.ini" | awk -F ': ' '{print $2}' || echo "")
    
    Serial_number_len_log=${#Serial_number_log}
    Serial_number_len_ini=${#Serial_number_ini}

    SSDFW_subnqn_log=$(grep "subnqn" "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW.log" | awk -F ': ' '{print $2}' || echo "")
    SSDFW_subnqn_ini=$(grep "subnqn" "${INIFILE}/Wedge400_SSDFW_${mn_pn}.ini" | awk -F ': ' '{print $2}' || echo "")

    SSDFW_subnqn_len_log=${#SSDFW_subnqn_log}
    SSDFW_subnqn_len_ini=${#SSDFW_subnqn_ini}

    if [[ -s "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW_Diff.log" ]]; then
        show_fail_msg "SSD FW Check Test "
        echo "SSD FW Check ERROR:" 
        cat "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SSDFW_Diff.log" 
        let res+=1
    elif [[ $Serial_number_len_log -lt "10" ]]; then
        show_fail_msg "SSD Serial Number "
        echo "SSD Serial Number Length is $Serial_number_len_log , less than 10" 
        let res+=1
    elif [[ $SSDFW_subnqn_len_log -lt "5" ]]; then
        show_fail_msg "SSD Product Asset Wrong Length "
        echo "SSD Product Asset Wrong Length is $SSDFW_subnqn_len_log , less than 5" 
        let res+=1        
    else
        show_pass_msg "SSD FW Check Test "
    fi

    echo "Switch SW Version Check Test"
    executeCMDinDiagOS "cd /usr/local/cls_diag/bin;./cel-version-test --show" ${sw_ip} | tee ${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo.log
   
    cat ${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo.log | sed -n '/Diag Version/,/I210 FW Version/ p' | grep -Ev "PIM presence"> ${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo_new.log
 
    diff -bB "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo_new.log" "${INIFILE}/Wedge400_SWInfo.ini" > "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo_Diff.log"

    if [ $? -eq 0 ]; then
        show_pass_msg "Switch SW Version Check "
    else
        show_fail_msg "Switch SW Version Check "
        echo "Switch SW Version ERROR:"
        cat "${LOGPATH}/${SN}/${folder}/${index}/wedge400_SWinfo_Diff.log"
        let res+=1
    fi
    return ${res}
}

main()
{
    echo "Current is checking WG400 switch index ${index}"
    SwitchSN=$(cat ${LOGPATH}/${folder}/${index}/serialnumber.txt)

    Normal_Function_Diagnostic_test ${index} ${sw_ip}
    ret=$?
    return "$ret"
}

if [ ! -d "${LOGFOLDER}/WG400_Test/PASS" ];then
    mkdir -p "${LOGFOLDER}/WG400_Test/PASS"
    mkdir -p "${LOGFOLDER}/WG400_Test/FAIL"
fi
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
cycle=0
retry=0
while ((1))
do
    sw_ip=`cat ${LOGFOLDER}/${folder}/${index}/mac_ip.txt`
    sw_sn=`cat ${LOGFOLDER}/${folder}/${index}/serialnumber.txt`
    chk_sw_ip | tee -a ${LOGFILE}
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        if [ "$cycle" -lt "$retry" ];then
            let cycle+=1
            echo "Wait 5s to check again"
            sleep 5
            continue
        else
            show_fail_msg "Ping switch IP ${sw_ip}"
            show_end_msg | tee -a ${LOGFILE}
            exit 1
        fi
    fi
    update_status "${SN}" "${folder}" "${index}" "${testitem}" "All" 1
    main | tee -a $LOGFILE
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        if [ "$cycle" -lt "$retry" ];then
            let cycle+=1
            exeucte_test "/usr/local/bin/wedge_power.sh reset -s" "${sw_ip}"
            echo "Wait 120s to check again"
            sleep 120
            show_title_msg "${testitem}" | tee ${LOGFILE}
            START=$(date)
            update_status "${SN}" "${folder}" "${index}" "${testitem}" "All" 4
            continue
        else
            show_fail_msg "WG400 Test"
            show_end_msg | tee -a ${LOGFILE}
            time=$(date "+%F_%T" | sed -e "s\:\-\g")
            file_name="${LOGFOLDER}/WG400_Test/FAIL/${SN}"_"Megazord"_"MP2"-${index}_${sw_sn}_WG400_Test_FAIL_"${time}".log
            if [ "${disable_log}" -eq "0" ];then
                cp -f ${LOGFILE} ${file_name}
                echo "Log file : ${file_name}"
            fi
            #echo ${file_name} > ${LOGFOLDER}/${folder}/${index}/last_main_log_name.txt
            update_status "${SN}" "${folder}" "${index}" "${testitem}" "" 3
            exit 1
        fi
    else
        show_pass_msg "WG400 Test"
        show_end_msg | tee -a ${LOGFILE}
        time=$(date "+%F_%T" | sed -e "s\:\-\g")
        file_name="${LOGFOLDER}/WG400_Test/PASS/${SN}"_"Megazord"_"MP2"-${index}_${sw_sn}_WG400_Test_PASS_"${time}".log
        if [ "${disable_log}" -eq "0" ];then
            cp -f ${LOGFILE} ${file_name}
            echo "Log file : ${file_name}"
        fi
        #echo ${file_name} > ${LOGFOLDER}/${folder}/${index}/last_main_log_name.txt
        update_status "${SN}" "${folder}" "${index}" "${testitem}" "All" 2
        exit 0
    fi
done


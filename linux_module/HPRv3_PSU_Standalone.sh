#!/bin/bash
# Version       : v1.0
# Function      : Execute Get bmc mac from node folder and ping if the IP is alive. 
# History       :
# 2024-10-30    | initial version
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

#set -x

switch_index=1

while getopts s:i: OPT; do
    case "${OPT}" in
        "s")
                RackSN=${OPTARG}
                check_sn ${RackSN}
                RackIPN=$(cat ${LOGPATH}/${RackSN}/rackipn.txt)
                RackAsset=$(cat ${LOGPATH}/${RackSN}/assetid.txt)
                wedge400IP=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/mac_ip.txt)
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

PSU_Update_Process()
{
    UpdateAddress=$1
    PSUType=$2
    PSUVendor=$3
    TargetVer=$4
    echo "Need updated address ${address} with PSU type : ${PSUType} and PSU vendor : ${PSUVendor}"

    PSUImage=$(ls $TOOL/${PSUType}/${PSUVendor}/)
    if [ ${PSUVendor^^} == "AEL" ] && [ ${PSUType} == "ORV3_HPR_PSU" ];then
        update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 1
        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${PSUType}/${PSUVendor}/${PSUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${PSUType}/${PSUVendor}/${PSUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/psu-update-aei.py --addr ${UpdateAddress} -–device hpr /tmp/${PSUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/psu-update-aei.py --addr ${UpdateAddress} --device hpr /tmp/${PSUImage}" "${wedge400IP}" | tee ${PSUUpdateLog} 
        Status=$(cat ${PSUUpdateLog} | grep -i "Upgrade success" | wc -l)
        newFWVer=$(cat ${PSUUpdateLog}  | grep -i -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ')
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${PSUVendor} for ${PSUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${PSUVendor} for ${PSUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${PSUVendor} for ${PSUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
            return 1
        fi
    elif ([ ${PSUVendor^^} == "DELTA" ] || [ ${PSUVendor^^} == "DET" ]) && [ ${PSUType} == "ORV3_HPR_PSU" ] ;then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${PSUType}/${PSUVendor}/${PSUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${PSUType}/${PSUVendor}/${PSUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/psu-update-delta-orv3.py --addr ${UpdateAddress} --key 0x06854137C758A5B6 /tmp/${PSUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/psu-update-delta-orv3.py --addr ${UpdateAddress} --key 0x06854137C758A5B6 /tmp/${PSUImage}" "${wedge400IP}" | tee ${PSUUpdateLog} 
        Status=$(cat ${PSUUpdateLog} | grep -i "Upgrade success" | wc -l)
        newFWVer=$(cat ${PSUUpdateLog}  | grep -i -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ')
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${PSUVendor} for ${PSUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${PSUVendor} for ${PSUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${PSUVendor} for ${PSUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
            return 1
        fi
    else
        echo "Can't get correct PSU vendor or PSU type, stop the test"
        update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 3
        return 1
    fi
    update_status "$SN" "$folder" "$index" "$testitem" "PSU Update" 2
}

Normal_HPRv3_PSU_Funtional_test()
{ 
    PSU_STDARR=("0x90;1" "0x91;2" "0x92;3" "0x93;4" "0x94;5" "0x95;6" "0x9a;7" "0x9b;8" "0x9c;9" "0x9d;10" "0x9e;11" "0x9f;12") 
    HPR_PSU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PSU" | grep "Device Address" | awk '{print$NF}'))

    echo "HPR PSU Address : ${HPR_PSU_AddressArr[@]}"
	local PMM_ID=""
	PSU_Array=()
    declare -a ARTESYN_PSU_INFO_ARRAY=("03-100049" "700-037147-0000" "^[0-9]{2}/[0-9]{4}$" "PSU3AEL" "A00" "009")
    #declare -a ARTESYN_PSU_INFO_ARRAY=("03-100049" "700-037147-0000" "[0-5][0-9]/202[4-5]" "PSU3AEL" "A00" "007")
    declare -a DELTA_PSU_INFO_ARRAY=("03-100038" "ECD17010021" "^[0-9]{2}/[0-9]{4}$" "P1HPDET" "09" "32214112")	
    #declare -a DELTA_PSU_INFO_ARRAY=("03-100038" "ECD17010021" "^[0-9]{2}/[0-9]{4}$" "P1HPDET" "8" "1.5.1.04111.3213")	

    for address in ${HPR_PSU_AddressArr[@]};do
        update_status "$SN" "$folder" "$index" "$testitem" "PSU Address Check" 1
        record_time "HPRv3_WG400_PSU_Standalone" start "PSU Address ${address} Check;${address}" "${address}" "NA" "${RackSN}"
        echo "PSU Address : ${address} Check Test"

        for i in "${!PSU_STDARR[@]}"; do
            IFS=';' read -r addr id <<< "${PSU_STDARR[i]}"
            if [[ "$addr" == "$input_addr" ]]; then
                addressFlg=1
                PMM_ID=${id}
            fi
        done

        if [[ ${addressFlg} -eq 1 ]]; then
            echo "${address} is in PSU_STDARR array, continue the test"
		else
            echo "${address} is not in PSU_STDARR array, stop the test and check the cable connection"
			record_time "HPRv3_WG400_PSU_Standalone" end "PSU_Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Address Test" 3
            return 1
		fi

        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address}" "${wedge400IP}" | tee ${PSULog} 
        logResultCheck "CheckResult" "Device Address;NF" "${address}" "${PSULog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Information Test -- ${address} PSU Address Check Test "
            record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Address Check" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- ${address} PSU Address Check Test "
            record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} Check;${address}" "${address}" "PASS" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Address Check" 2
        fi

        update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 1
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_MFR_Serial" "${wedge400IP}" | tee ${PSULog}
        PSUVendor=$(cat ${PSULog} | grep "PSU_MFR_Serial<" | awk '{print$NF}' | cut -c 10-12)
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${PSULog}
        PSUType=$(cat ${PSULog} | grep "Device Type:" | awk '{print$NF}')
        PSUPMMVendor=$(cat ${LOGFOLDER}/PMMVendor.txt)

        if [ ${PSUType} == "ORV3_HPR_PSU" ];then
            if [ ${PSUVendor} == "AEL" ];then
                PSUVendor_Full="ARTESYN"
                if [ ${PSUVendor_Full^^} == ${PSUPMMVendor} ];then
                    declare -a PSU_Array=("${ARTESYN_PSU_INFO_ARRAY[@]}")
                else
                    echo "The PSU Vendor : ${PSUPMMVendor^^} is not match as the PSU Vendor : ${PSUVendor_Full}, stop the test"
                    return 1
                fi
               
            elif [ ${PSUVendor} == "DET" ];then
                PSUVendor_Full="DELTA"
                if [ ${PSUVendor_Full^^} == ${PSUPMMVendor} ];then
                    declare -a PSU_Array=("${DELTA_PSU_INFO_ARRAY[@]}")
                else
                    echo "The PSU Vendor : ${PSUPMMVendor^^} is not match as the PSU Vendor : ${PSUVendor_Full}, stop the test"
                    return 1
                fi
            else
                echo "Can't get correct PSU vendor, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                return 1
            fi
        else
            echo "The address is not belongs to PSU, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
            return 1
        fi

        echo "PSU Module Infotmation Check for address : ${address}"
        PSUInfo=("PSU_FBPN" "PSU_MFR_Model" "PSU_MFR_Date" "PSU_MFR_Serial" "PSU_HW_Revision" "PSU_FW_Revision")

        for i in "${!PSUInfo[@]}"; do
            exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PSUInfo[$i]}" "${wedge400IP}" | tee ${PSULog}
            record_time "HPRv3_WG400_PSU_Standalone" start "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "NA" "${RackSN}"

            if [ ${PSUInfo[$i]} == "PSU_MFR_Date" ];then
                logResultCheck "CheckEGREPFormat" "${PSUInfo[$i]}<" "NF;${PSU_Array[$i]}" "${PSULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2
                fi
            elif [ ${PSUInfo[$i]} == "PSU_MFR_Serial" ];then
                logResultCheck "CheckEGREPValue" "${PSUInfo[$i]}<" "NF;${PSU_Array[$i]}" "${PSULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2
                fi

                echo "Double check the serial number with SFC data" 
                WG400_PSUSN=$(cat ${PSULog} | grep "PSU_MFR_Serial<0x0018>" | awk -F '"' '{print$2}' )
                SFC_PSUSN=$(cat ${LOGFOLDER}/${SN}_formatted.json | grep -w -A 75 "PSU" | grep -B 3 "\"index\": \"${id}\"" | grep "serialnumber" | awk -F '"' '{print$4}' )

                if [ "${WG400_PSUSN}" == "${SFC_PSUSN}" ];then
                    show_pass_msg "Rack Module Test -- PSU_${address}_Information_Check Test with SFC -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
			        update_status "$SN" "$folder" "$index" "$testitem" "PSU Information Test" 2
                else
                    show_fail_msg "Rack Module Test -- PSU_${address}_Information_Check Test with SFC -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
			        update_status "$SN" "$folder" "$index" "$testitem" "PSU Information Test" 3
                    return 1
                fi
            elif [ ${PSUInfo[$i]} == "PSU_FW_Revision" ];then                 
                logResultCheck "LogCheck" "${PSUInfo[$i]}<" "NF;${PSU_Array[$i]}" "${PSULog}"                 
                if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                    show_fail_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"                         
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "FAIL" "${RackSN}"                         
                    echo "Need to update the FW for PSU, continue the update process"
                    PSU_Update_Process "$address" "$PSUType" "$PSUVendor" "${PSU_Array[$i]}"
                    if [ ${PIPESTATUS[0]} -eq 0 ];then
                        echo "The PSU type ${PSUType} for vendor ${PSUVendor} already updated, check the FW again"
                        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PSUInfo[$i]}" "${wedge400IP}" | tee ${PSULog}
                        logResultCheck "LogCheck" "${PSUInfo[$i]}<" "NF;${PSU_Array[$i]}" "${PSULog}"
                        if [ ${PIPESTATUS[0]} -eq 0 ];then
                            echo "The PSU FW already update to ${PSU_Array[$i]}, continue the test"
                        else
                            echo "The PSU FW don't update to ${PSU_Array[$i]}, stop the test"
                            update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                            return 1
                        fi
                    else
                        echo "The PSU FW don't update to ${PSU_Array[$i]}, stop the test"
                        update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                        return 1
                    fi
                else                         
                    show_pass_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"                         
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "PASS" "${RackSN}"      
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2           
                fi 
            else
                logResultCheck "LogCheck" "${PSUInfo[$i]}<" "NF;${PSU_Array[$i]}" "${PSULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- PSU_${address}_Information_Check Test -> ${PSUInfo[$i]}"
                    record_time "HPRv3_WG400_PSU_Standalone" end "PSU_${address}_Information_Check;${PSUInfo[$i]}" "${PSU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$SN" "$folder" "$index" "$testitem" "PSU Info Check" 2
                fi
            fi
        done
        
         #update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 1
         #echo "PSU_Input_Power Check Test on address : ${address}"
         #echo "Check the value is large between 4800 and 5700"
         #record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} Functional Check;PSU_Input_Power" "5700 > Power > 4800" "NA" "${RackSN}"
         #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_Input_Power" "${wedge400IP}" | tee ${PSULog}
         #logResultCheck "ValueCheck" "PSU_Input_Power<0x0057>" "NF;>;4800" "${PSULog}"
         #if [ ${PIPESTATUS[0]} -eq 0 ];then
         #    echo "Check the value is less than 5700"
         #    logResultCheck "ValueCheck" "PSU_Input_Power<0x0057>" "NF;<;5700" "${PSULog}"
         #    if [ ${PIPESTATUS[0]} -eq 0 ];then
         #        show_pass_msg "Rack Module Information Test -- ${address} PSU_Input_Power"
         #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Power" "5700 > Power > 4800" "PASS" "${RackSN}"
         #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
         #    else
         #        show_fail_msg "Rack Module Information Test -- ${address} PSU_Input_Power "
         #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Power" "5700 > Power > 4800" "FAIL" "${RackSN}"
         #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
         #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
         #        return 1
         #    fi
         #else
         #    show_fail_msg "Rack Module Information Test -- ${address} PSU_Input_Power"
         #    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Power" "5700 > Power > 4800" "FAIL" "${RackSN}"
         #    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
         #    update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
         #    return 1
         #fi

         #echo "PSU_Output_Power Check Test on address : ${address}"
         #echo "Check the value is large than 4800W"        
       # #record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} Functional Check;PSU_Output_Power" "4800 < Power < 5700" "NA" "${RackSN}"
         #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_Output_Power" "${wedge400IP}" | tee ${PSULog}
         ##if [ ${address} == 0x90 ] || [ ${address} == 0x91 ] || [ ${address} == 0x92 ] || [ ${address} == 0x94 ] || [ ${address} == 0x9a ] || [ ${address} == 0x9d ] || [ ${address} == 0x9e ];then
         #logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;>;4800" "${PSULog}"
         #if [ ${PIPESTATUS[0]} -eq 0 ];then
         #    echo "Check the value is less than 5700W"
         #    logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;<;5700" "${PSULog}"
         #    if [ ${PIPESTATUS[0]} -eq 0 ];then
         #        show_pass_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
         #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "4800 < Power < 5700" "PASS" "${RackSN}"
         #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
         #    else
         #        show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
         #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "4800 < Power < 5700" "FAIL" "${RackSN}"
         #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
         #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
         #        return 1
         #    fi
         #else
         #    show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
         #    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "4800 < Power < 5700" "FAIL" "${RackSN}"
         #    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
         #    update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
         #    return 1
         #fi




        #echo "PSU_Input_Voltage_AC Check Test on address : ${address}"
        #echo "Check the value is large than 200"
        #record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} Functional Check;PSU_Input_Voltage_AC" "200 < Voltage < 300" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_Input_Voltage_AC" "${wedge400IP}" | tee ${PSULog} 
        #logResultCheck "ValueCheck" "PSU_Input_Voltage_AC<0x0058>" "NF;>;200" "${PSULog}"
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
        #    echo "Check the value is less than 300"
        #    logResultCheck "ValueCheck" "PSU_Input_Voltage_AC<0x0058>" "NF;<;300" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -eq 0 ];then
        #        show_pass_msg "Rack Module Information Test -- ${address} PSU_Input_Voltage_AC "
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Voltage_AC" "200 < Voltage < 300" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    else   
        #        show_fail_msg "Rack Module Information Test -- ${address} PSU_Input_Voltage_AC "
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Voltage_AC" "200 < Voltage < 300" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    fi
        #else   
        #    show_fail_msg "Rack Module Information Test -- ${address} PSU_Input_Voltage_AC"
        #    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Input_Voltage_AC" "200 < Voltage < 300" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #    update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #    return 1
        #fi

        #echo "PSU_Output_Power Check Test on address : ${address}"
        #echo "Check the value is large than 0W"
        #record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} Functional Check;PSU_Output_Power" "0 < Power < 6600" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_Output_Power" "${wedge400IP}" | tee ${PSULog} 
        ##if [ ${address} == 0x90 ] || [ ${address} == 0x91 ] || [ ${address} == 0x92 ] || [ ${address} == 0x94 ] || [ ${address} == 0x9a ] || [ ${address} == 0x9d ] || [ ${address} == 0x9e ];then
        #logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;>=;0" "${PSULog}"
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
        #    echo "Check the value is less than 6600W"
        #    logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;<;6600" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -eq 0 ];then
        #        show_pass_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "0 <= Power < 6600" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    else   
        #        show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "0 <= Power < 6600" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    fi
        #else   
        #    show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
        #    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Power" "0 <= Power < 6600" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #    update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #    return 1
        #fi
    #   #  else   
	## 	logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;>;0" "${PSULog}"
    #   #  	if [ ${PIPESTATUS[0]} -eq 0 ];then
    #   #      		echo "Check the value is less than 6600W"
    #   #      		logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;<;6600" "${PSULog}"
    #   #      		if [ ${PIPESTATUS[0]} -eq 0 ];then
    #   #          		show_pass_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
	## 			record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} PSU_Output_Power Check" "0 < Power < 6600" "PASS" "${RackSN}"
    #   #     		else   
    #   #         			show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
	## 			record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} PSU_Output_Power Check" "0 < Power < 6600" "FAIL" "${RackSN}"
    #   #          		return 1
    #   #      		fi
	## 	else   
    #   #                  show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Power"
	## 		record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} PSU_Output_Power Check" "0 < Power < 6600" "FAIL" "${RackSN}"
    #   #                  return 1
    #   #  	fi
	## fi

        #echo "PSU_Output_Voltage Check Test on address : ${address}"
        #echo "Check the value is large than 48V"
	#    record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} Functional Check;PSU_Output_Voltage" "48 < Voltage < 50.5" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PSU_Output_Voltage" "${wedge400IP}" | tee ${PSULog} 
        #logResultCheck "ValueCheck" "PSU_Output_Voltage<0x004f>" "NF;>;48" "${PSULog}"
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
        #    echo "Check the value is less than 50.5V"
        #    logResultCheck "ValueCheck" "PSU_Output_Voltage<0x004f>" "NF;<;50.5" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -eq 0 ];then
        #        show_pass_msg "Rack Module Information Test -- ${address} PSU_Output_Voltage"
	#		    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Voltage" "48 < Voltage < 50.5" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    else   
        #        show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Voltage"
	#		    record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Functional Check;PSU_Output_Voltage" "48 < Voltage < 50.5" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    fi
        #else   
        #    show_fail_msg "Rack Module Information Test -- ${address} PSU_Output_Voltage"
	#	    record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} PSU_Output_Voltage Check;PSU_Output_Voltage" "48 < Voltage < 50.5" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #    update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #    return 1
        #fi

	#    echo "General_Alarm_Status_Register Test for PSU address : ${address}"
        #Register=("DCDC <1>" "Temperature <2>" "Communication <3>")
        ##Register=("PFC <0>" "DCDC <1>" "Temperature <2>" "Communication <3>")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name General_Alarm_Status_Register" "${wedge400IP}" | tee ${PSULog}
        #for Reg in "${Register[@]}"; do
        #    record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} General_Alarm_Status_Register Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU Address ${address} General_Alarm_Status_Register Test -- ${Reg}"
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} General_Alarm_Status_Register Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU ${address} General_Alarm_Status_Register Test -- ${Reg}"
        #        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} General_Alarm_Status_Register Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    fi
        #done

        #echo "PFC_Alarm_Status_Register Test on address : ${address}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PFC_Alarm_Status_Register" "${wedge400IP}" | tee ${PSULog} 
        #Register=("PFC_Fail <11>" )
        ##Register=("PFC_Fail <11>" "AC_Loss_Single_Fault <12>")

        #for Reg in "${Register[@]}"; do
	#        record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} PFC_Alarm_Status_Register Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU Address ${address} PFC_Alarm_Status_Register Test ${Reg}" 
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} PFC_Alarm_Status_Register Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU Address ${address} PFC_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} PFC_Alarm_Status_Register Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    fi
        #done

        #echo "DCDC_Alarm_Status_Register Test on address : ${address}"
        #Register=("Main_UVP" "Main_OVP" "Main_OCP" "Main_SCKT" "DCDC_Fail" "Secondary_MCU_Fail" "Oring_Fail")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name DCDC_Alarm_Status_Register" "${wedge400IP}" | tee ${PSULog} 
        #for Reg in "${Register[@]}"; do
	#        record_time "HPRv3_WG400_PSU_Standalone" start "PSU ${address} DCDC_Alarm_Status_Register Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU Address ${address} DCDC_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} DCDC_Alarm_Status_Register Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU Address ${address} DCDC_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} DCDC_Alarm_Status_Register Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    fi
        #done

        #echo "Temperature_Alarm_Status_Register Test on address : ${address}"
        #Register=("Outlet_Temp_Alarm" "Oring_Temp_Alarm" "Sync_Temp_Alarm" "LLC_Temp_Alarm" "PFC_Temp_Alarm" "Bus_Clip_Temp_Alarm" "Fan_Failure")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Temperature_Alarm_Status_Register" "${wedge400IP}" | tee ${PSULog} 
        #for Reg in "${Register[@]}"; do
	#    record_time "HPRv3_WG400_PSU_Standalone" start "PSU Address ${address} Temperature_Alarm_Status_Register Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU Address ${address} Temperature_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Temperature_Alarm_Status_Register Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU Address ${address} Temperature_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU ${address} Temperature_Alarm_Status_Register Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    fi
        #done

        #echo "Communication_Alarm_Status_Register Test on address : ${address}"
        #Register=("Primary_Secondary_MCU_Fault")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Communication_Alarm_Status_Register" "${wedge400IP}" | tee ${PSULog} 
        #for Reg in "${Register[@]}"; do
	#        record_time "HPRv3_WG400_PSU_Standalone" start "PSU Address ${address} Communication_Alarm_Status_Register Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU Address ${address} Communication_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} Communication_Alarm_Status_Register Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU Address ${address} Communication_Alarm_Status_Register Test ${Reg}"
	#	        record_time "HPRv3_WG400_PSU_Standalone" end "PSU Address ${address} Communication_Alarm_Status_Register Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$SN" "$folder" "$index" "$testitem" "PSU Function Check" 2
        #    fi
        #done
	
    done

    
}
base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
PSULog=${LOGFOLDER}/PSULog.txt
RackmonLog=${LOGFOLDER}/RackMonLog.txt
LOGFILE=${LOGFOLDER}/log.txt
PSUUpdateLog=${LOGFOLDER}/PSUUpdate.txt
folder=RUSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_PSU_Standalone" initial "" "" "" "$RackSN"
ssh-keygen -R "${wedge400IP}" > /dev/null

Normal_HPRv3_PSU_Funtional_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 PSU Function Test" | tee -a ${LOGFILE}
        show_fail | tee -a ${LOGFILE}
        finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PSUSTANDALONE_FAIL_${startTime}.log
        record_time "HPRv3_WG400_PSU_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
        #cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
        cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
        cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
        exit 1
fi

echo "HPRv3 PSU Function Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PSUSTANDALONE_PASS_${startTime}.log
record_time "HPRv3_WG400_PSU_Standalone" total "HPRv3_WG400_PSU_Standalone;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_PSU_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0


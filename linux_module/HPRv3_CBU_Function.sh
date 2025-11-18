#!/bin/bash
# Version       : v1.0
# Function      : Execute Get bmc mac from node folder and ping if the IP is alive. 
# History       :
# 2024-10-30    | initial version
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

set -x

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
                        exit 1
                fi
            ;;
        *)
                print_help
                exit 1
            ;;
    esac
done

CBU_Update_Process()
{
    UpdateAddress=$1
    CBUType=$2
    CBUVendor=$3
    TargetVer=$4
    echo "Need updated address ${UpdateAddress} with CBU type : ${CBUType} and CBU vendor : ${CBUVendor^^}"

    CBUImage=$(ls $TOOL/${CBUType}/${CBUVendor^^}/)
    if [ ${CBUVendor} == "Panasonic" ] && [ ${CBUType} == "ORV3_HPR_CBU" ];then
        update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 1
        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${CBUType}/${CBUVendor^^}/${CBUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${CBUType}/${CBUVendor^^}/${CBUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor hpr_panasonic --addr ${UpdateAddress} /tmp/${CBUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor hpr_panasonic --addr ${UpdateAddress} /tmp/${CBUImage}" "${wedge400IP}" | tee ${CBUUpdateLog} 
        Status=$(cat ${CBUUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${CBUUpdateLog} | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$NF}' | tr -d ' ' )
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${CBUVendor^^} for ${CBUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${CBUVendor^^} for ${CBUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${CBUVendor^^} for ${CBUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
            return 1
        fi
    elif [ ${CBUVendor} == "Delta" ] && [ ${CBUType} == "ORV3_HPR_CBU" ] ;then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${CBUType}/${CBUVendor^^}/${CBUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${CBUType}/${CBUVendor^^}/${CBUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor delta --addr ${UpdateAddress} /tmp/${CBUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor delta --addr ${UpdateAddress} /tmp/${CBUImage}" "${wedge400IP}" | tee ${CBUUpdateLog} 
        Status=$(cat ${CBUUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${CBUUpdateLog}  | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ')
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${CBUVendor^^} for ${CBUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${CBUVendor^^} for ${CBUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${CBUVendor^^} for ${CBUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
            return 1
        fi
    else
        echo "Can't get correct CBU vendor or CBU type, stop the test"
        update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 3
        return 1
    fi
    update_status "$SN" "$folder" "$index" "$testitem" "CBU Update" 2
}

Normal_HPRv3_CBU_Funtional_test()
{
    STD_CBUARR=("0x36" "0x37" "0x38" "0x46" "0x47" "0x48" "0x56" "0x57" "0x58" "0x66" "0x67" "0x68" "0x76" "0x77" "0x78" "0x86" "0x87" "0x88" "0x96" "0x97" "0x98")
    HPR_CBU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_CBU" | grep "Device Address" | awk '{print$NF}'))
    if [ ${#HPR_CBU_AddressArr[@]} -eq 0 ];then
        echo "Can't get correct number of CBU, stop the test"
        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Check;${CBU_address}" "${CBU_address}" "FAIL" "${RackSN}"
        record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
        update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Address Check" 3
        return 1
    fi

    echo "HPR CBU Address : ${HPR_CBU_AddressArr[@]}"
      
    declare -a PANASONIC_CBU_Data_Array=("03-100046" "BJ-A3C0001A0001" "^[0-9]{2}/[0-9]{4}$" "B1V4PAJ" "01" "02.29.19" "23") 

    declare -a DELTA_CBU_Data_Array=("03-100043" "DPST-5500GXA" "^[0-9]{2}/[0-9]{4}$" "KGRDTW" "S1" "S1.04B03")

    for CBU_address in ${HPR_CBU_AddressArr[@]};do
        update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Address Check" 1
        record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} Check;${CBU_address}" "${CBU_address}" "NA" "${RackSN}"
        if [[ " ${STD_CBUARR[@]} " =~ " $address " ]]; then
    		echo "${CBU_address} is in STD_CBUARR array, continue the test"
            record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Check;${address}" "${CBU_address}" "PASS" "${RackSN}"
	    else
   		    echo "${CBU_address} is not in STD_CBUARR array, stop the test and check the cable connection"
    		record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Check;${address}" "${CBU_address}" "FAIL" "${RackSN}"
    		record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
    		update_status "$SN" "$folder" "$index" "$testitem" "CBU Address Check" 3
     		return 1
	    fi
        
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address}" "${wedge400IP}" | tee ${CBULog} 
        logResultCheck "LogCheck" "Device Address" "NF;${CBU_address}" "${CBULog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Information Test -- ${CBU_address} CBU Address"
		    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Check;${CBU_address}" "${CBU_address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
            update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Address Check" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- ${CBU_address} CBU Address"
		    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Check;${CBU_address}" "${CBU_address}" "PASS" "${RackSN}"
            update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Address Check" 2
        fi

        update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 1
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name Manufacture_Name" "${wedge400IP}" | tee ${CBULog}
        CBUVendor=$(cat ${CBULog} | grep "Manufacture_Name<" | awk '{print$NF}' | tr -d '"')
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${CBULog}
        CBUType=$(cat ${CBULog} | grep "Device Type:" | awk '{print$NF}')
	    CBUPMMVendor=$(cat ${LOGFOLDER}/CBUPMMVendor.txt)

        if [ ${CBUType} == "ORV3_HPR_CBU" ];then
            if [ ${CBUVendor^^} == "PANASONIC" ];then
                if [ ${CBUVendor^^} == ${CBUPMMVendor} ];then
                    declare -a CBU_Array=("${PANASONIC_CBU_Data_Array[@]}")
                else
                    echo "The CBU PMM Vendor : ${CBUPMMVendor^^} is not match as the CBU Vendor : ${CBUVendor}, stop the test"
                    return 1
                fi
            elif [ ${CBUVendor^^} == "DELTA" ];then
                if [ ${CBUVendor^^} == ${CBUPMMVendor} ];then
                    declare -a CBU_Array=("${DELTA_CBU_Data_Array[@]}")
                else
                    echo "The CBU PMM Vendor : ${CBUPMMVendor^^} is not match as the CBU Vendor : ${CBUVendor}, stop the test"
                    return 1
                fi
            else
                echo "Can't get correct CBU vendor, stop the test"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                return 1
            fi
        else
            echo "The address is not belongs to CBU, stop the test"
            update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
            return 1
        fi

        echo "CBU Module Infotmation Check for address : ${CBU_address}"
        if [ ${CBUVendor} == "Panasonic" ];then
            CBUInfo=("Facebook_Part_Number" "Manufacture_Model" "Manufacture_Date" "MFR_Serial" "HW_Revision" "FW_Revision" "Battery_Pack_FW_Revision")
        else
            CBUInfo=("Facebook_Part_Number" "Manufacture_Model" "Manufacture_Date" "MFR_Serial" "HW_Revision" "FW_Revision")
        fi

        for i in "${!CBUInfo[@]}"; do
            exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name ${CBUInfo[$i]}" "${wedge400IP}" | tee ${CBULog}
            record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "NA" "${RackSN}"

		    if [ ${CBUInfo[$i]} == "Manufacture_Date" ];then
                logResultCheck "CheckEGREPFormat" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 2
                fi
		    elif [ ${CBUInfo[$i]} == "MFR_Serial" ];then
                logResultCheck "CheckEGREPValue" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 2
                fi
		    elif [ ${CBUInfo[$i]} == "Manufacture_Model" ];then
                logResultCheck "CheckWholeResult" "${CBUInfo[$i]}<;NF" "${CBU_Array[$i]}" "${CBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 2
                fi
            elif [ ${CBUInfo[$i]} == "FW_Revision" ];then                 
                logResultCheck "LogCheck" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"                 
                if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                    show_warn_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"                          
                    echo "Need to update the FW for CBU, continue the update process"
                    CBU_Update_Process "$CBU_address" "$CBUType" "$CBUVendor" "${CBU_Array[$i]}"
                    if [ ${PIPESTATUS[0]} -eq 0 ];then
                        echo "The CBU type ${CBUType} for vendor ${CBUVendor} already updated, check the FW again"
                        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name ${CBUInfo[$i]}" "${wedge400IP}" | tee ${CBULog}
                        logResultCheck "LogCheck" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"
                        if [ ${PIPESTATUS[0]} -eq 0 ];then
                            echo "The CBU FW already update to ${CBU_Array[$i]}, continue the test"
                        else
                            echo "The CBU FW don't update to ${CBU_Array[$i]}, stop the test"
                            record_time "HPRv3_WG400_CBU" end "CBU_${CBU_address}_Information_Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                            record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                            update_status "$SN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                            return 1
                        fi
                    else
                        echo "The CBU FW don't update to ${CBU_Array[$i]}, stop the test"
                        update_status "$SN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                        return 1
                    fi
                else                         
                    show_pass_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"                         
                    record_time "HPRv3_WG400_CBU" end "CBU_${CBU_address}_Information_Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"   
                    update_status "$SN" "$folder" "$index" "$testitem" "CBU Info Check" 2              
                fi
            elif [ ${CBUInfo[$i]} == "FW_Revision" ];then                 
                logResultCheck "LogCheck" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"                 
                if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                    show_warn_msg "Rack Module Test -- CBU_${CBU_address}_Information_Check Test -> ${CBUInfo[$i]}"                          
                    echo "Need to update the FW for CBU, continue the update process"
                    CBU_Update_Process "$CBU_address" "$CBUType" "$CBUVendor" "${CBU_Array[$i]}"
                    if [ ${PIPESTATUS[0]} -eq 0 ];then
                        echo "The CBU type ${CBUType} for vendor ${CBUVendor} already updated, check the FW again"
                        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name ${CBUInfo[$i]}" "${wedge400IP}" | tee ${CBULog}
                        logResultCheck "LogCheck" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"
                        if [ ${PIPESTATUS[0]} -eq 0 ];then
                            echo "The CBU FW already update to ${CBU_Array[$i]}, continue the test"
                        else
                            echo "The CBU FW don't update to ${CBU_Array[$i]}, stop the test"
                            record_time "HPRv3_WG400_CBU" end "CBU_${address}_Information_Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                            record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                            return 1
                        fi
                    else
                        echo "The CBU FW don't update to ${CBU_Array[$i]}, stop the test"
                        return 1
                    fi
                else                         
                    show_pass_msg "Rack Module Test -- CBU_${address}_Information_Check Test -> ${CBUInfo[$i]}"                         
                    record_time "HPRv3_WG400_CBU" end "CBU_${address}_Information_Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"                 
                fi
            else
                logResultCheck "LogCheck" "${CBUInfo[$i]}<" "NF;${CBU_Array[$i]}" "${CBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- CBU_${address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- CBU_${address}_Information_Check Test -> ${CBUInfo[$i]}"
                    record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Info Check;${CBUInfo[$i]}" "${CBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Info Check" 2
                fi
            fi
        done

        echo "CBUs Status Check Test for address : ${CBU_address}"
        Register=("Charge_FET_Failure" "AFE_Failure" "Cell_Balancing_Failure" "Fan_Failure" "EOL" "Cell_Over_Voltage" "Pack_Under_Voltage" "Cell_Under_Voltage" "Pack_Over_Current" "Temperature_Failure")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} Status Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "CBUs Mode Check Test for address : ${CBU_address}"
        Register=("CANBUS_Communication_Failure" "SMBUS_Communication_Failure")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Mode" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Mode Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU Mode Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Mode Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU Mode Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Mode Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "Supercap Pack Status Check Test for address : ${CBU_address}"
        Register=("Over_Temperature_Alarm" "Terminate_Charge_Alarm" "Over_Charge_Alarm")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name Battery_Status" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU Status Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} Battery Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Battery Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} Battery Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} Battery Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "LED Status Check Test for address : ${CBU_address}"
        Register=("EOL_LED_On" "FAULT_LOC_LED_On")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name LED_Status" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU LED Status Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} LED Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU LED Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} LED Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU LED Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "CBU_Status_Word Status Check Test for address : ${CBU_address}"
        Register=("Temperature_Fault" "Power_Boost_Converter_Fault" "Buck_Converter_Fault" "Charger_Converter_Fault" "Fan_Fault")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status_Word" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Status_Word Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU_Status_Word Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Word Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU_Status_Word Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Word Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "CBU_Status_Power_Charger Status Check Test for address : ${CBU_address}"
        Register=("Power_Boost_SCP1" "Power_Boost_OCP" "Power_Boost_OVP" "Power_Boost_SCP2" "Power_Boost_UVP")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status_Power_Boost" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU_Status_Power_Boost Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU_Status_Power_Boost Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "CBU_Status_Power_DisCharger Status Check Test for address : ${CBU_address}"
        Register=("Power_Boost_SCP1" "Power_Boost_OCP" "Power_Boost_OVP" "Power_Boost_SCP2" "Power_Boost_UVP")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status_Power_Boost" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU_Status_Power_Boost Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU_Status_Power_Boost Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Power_Boost Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "CBU_Status_Buck_DisCharger Status Check Test for address : ${CBU_address}"
        Register=("Buck_Output_OVP")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status_Buck_Converter" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Status_Buck_Converter Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU_Status_Buck_Converter Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Buck_Converter Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU_Status_Buck_Converter Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Buck_Converter Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done
        
        echo "CBU_Status_Temperature Status Check Test for address : ${CBU_address}"
        Register=("Input_Ambient_OTP" "Output_Ambient_OTP" "Charger_OTP" "Buck_Converter_OTP" "Power_Boost_OTP" "Battery_Pack_OTP")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name CBU_Status_Temperature" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} CBU_Status_Temperature Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} CBU_Status_Temperature Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Temperature Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} CBU_Status_Temperature Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} CBU_Status_Temperature Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done

        echo "End_of_Life_Status Status Check Test for address : ${CBU_address}"
        Register=("CBU_EOL")
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${CBU_address} --reg-name End_of_Life_Status" "${wedge400IP}" | tee ${CBULog}
        for Reg in "${Register[@]}"; do
		    record_time "HPRv3_WG400_CBU" start "CBU ${CBU_address} End_of_Life_Status Check;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${CBULog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- ${CBU_address} End_of_Life_Status Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} End_of_Life_Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "FAIL" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 3
                return 1
            else
                show_pass_msg "Rack Module Test -- ${CBU_address} End_of_Life_Status Status Test ${Reg}"
		        record_time "HPRv3_WG400_CBU" end "CBU ${CBU_address} End_of_Life_Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
                update_status "$RackSN" "$folder" "$index" "$testitem" "CBU Function Check" 2
            fi
        done
   done
}

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
RackmonLog=${LOGFOLDER}/RackMonLog.txt
CBULog=${LOGFOLDER}/CBULog.txt
LOGFILE=${LOGFOLDER}/log.txt
CBUUpdateLog=${LOGFOLDER}/CBUUpdate.txt
folder=RUSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_CBU" initial "" "" "" "$RackSN"
ssh-keygen -R "${wedge400IP}" > /dev/null

Normal_HPRv3_CBU_Funtional_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 CBU Function Test" | tee -a ${LOGFILE}
        show_fail | tee -a ${LOGFILE}
   	finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_${wedge400SN}_CBUFUNC_FAIL_${startTime}.log
   	record_time "HPRv3_WG400_CBU" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
        cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
	cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
   	cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
   	exit 1
fi

show_pass_msg "HPRv3 CBU Function Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_${wedge400SN}_CBUFUNC_PASS_${startTime}.log
record_time "HPRv3_WG400_CBU" total "HPRv3_WG400_CBU;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_CBU" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

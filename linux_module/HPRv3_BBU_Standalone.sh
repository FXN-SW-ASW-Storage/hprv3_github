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

BBU_Update_Process()
{
    UpdateAddress=$1
    BBUType=$2
    BBUVendor=$3
    TargetVer=$4
    echo "Need updated address ${UpdateAddress} with BBU type : ${BBUType} and BBU vendor : ${BBUVendor^^}"

    BBUImage=$(ls $TOOL/${BBUType}/${BBUVendor^^}/)
    if [ ${BBUVendor} == "Panasonic" ] && [ ${BBUType} == "ORV3_HPR_BBU" ];then
        update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 1
        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${BBUType}/${BBUVendor^^}/${BBUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${BBUType}/${BBUVendor^^}/${BBUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor hpr_panasonic --addr ${UpdateAddress} /tmp/${BBUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor hpr_panasonic --addr ${UpdateAddress} /tmp/${BBUImage}" "${wedge400IP}" | tee ${BBUUpdateLog} 
        Status=$(cat ${BBUUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${BBUUpdateLog} | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$NF}' | tr -d ' ' )
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${BBUVendor^^} for ${BBUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${BBUVendor^^} for ${BBUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${BBUVendor^^} for ${BBUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
            return 1
        fi
    elif [ ${BBUVendor} == "Delta" ] && [ ${BBUType} == "ORV3_HPR_BBU" ] ;then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${BBUType}/${BBUVendor^^}/${BBUImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${BBUType}/${BBUVendor^^}/${BBUImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor delta --addr ${UpdateAddress} /tmp/${BBUImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --vendor delta --addr ${UpdateAddress} /tmp/${BBUImage}" "${wedge400IP}" | tee ${BBUUpdateLog} 
        Status=$(cat ${BBUUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${BBUUpdateLog}  | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ')
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${BBUVendor^^} for ${BBUType} already update to target version ${TargetVer}"
            else
                echo "The vendor ${BBUVendor^^} for ${BBUType} can't update to target version ${TargetVer}, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
                return 1
            fi
        else    
            echo "The vendor ${BBUVendor^^} for ${BBUType} can't update to target version ${TargetVer}, stop the test"
            update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
            return 1
        fi
    else
        echo "Can't get correct BBU vendor or BBU type, stop the test"
        update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
        return 1
    fi
    update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 2
}

Normal_HPRv3_BBU_Funtional_test()
{
    # echo "Syslog Check Test -- Before test"
    # exeucte_test "cel_syslog -l before_log -k" | tee ${diagnosticLog}

    # checkArr=("Save System Logs" "SEL has no entries" "Log check PCIe Bus Error" "Log check PCIe Error" "Log check Hardware Error" "Check (Un)Correctable Error" "Log check mcelog error")

    # for key in ${checkArr[@]}
    # do
    #     logResultCheck "LogCheck" "${key}" "PASS;NF" "before_log"
    #     if [ ${PIPESTATUS[0]} -ne 0 ];then
    #         show_fail_msg "Syslog Check Test -- ${key}" 
    #         return 1
    #     else
    #         show_pass_msg "Syslog Check Test -- ${key}" 
    #     fi
    # done

    #BBU_Address=("0x30" "0x31" "0x32" "0x33" "0x34" "0x35" "0x3A" "0x3B" "0x3C" "0x3D" "0x3E" "0x3F" "0x5A" "0x5B" "0x5C" "0x5D" "0x5E" "0x5F" "0x6A" "0x6B" "0x6C" "0x6D" "0x6E" "0x6F" "0x70" "0x71" "0x72" "0x73" "0x74" "0x75" "0x7A" "0x7B" "0x7C" "0x7D" "0x7E" "0x7F")
    
    ### 0224 Debug Using
    # BBU_Address=("0x30" "0x31" "0x32" "0x33" "0x34" "0x35" "0x3A" "0x3B" "0x3C" "0x3D" "0x3E" "0x3F" "0x5A" "0x5B" "0x5C" "0x5D" "0x5E" "0x5F" "0x6A" "0x6B" "0x6C" "0x6D" "0x6E" "0x6F" "0x70" "0x71" "0x72" "0x73" "0x74" "0x75" )
    HPR_BBU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_BBU" | grep "Device Address" | awk '{print$NF}'))
    echo "HPR BBU Address : ${HPR_BBU_AddressArr[@]}"
      
    declare -a PANASONIC_BBU_Data_Array=("03-100046" "BJ-A3C0001A0001" "^[0-9]{2}/[0-9]{4}$" "B1V4PAJ" "01" "02.29.19" "23") 

    declare -a DELTA_BBU_Data_Array=("03-100043" "DPST-5500GXA" "^[0-9]{2}/[0-9]{4}$" "KGRDTW" "S1" "S1.04B03")

    for bbu_address in ${HPR_BBU_AddressArr[@]};do
        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Address Check" 1
        record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} Check;${bbu_address}" "${bbu_address}" "NA" "${RackSN}"
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address}" "${wedge400IP}" | tee ${BBULog} 
        logResultCheck "LogCheck" "Device Address" "NF;${bbu_address}" "${BBULog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Information Test -- ${bbu_address} BBU Address"
		    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Check;${bbu_address}" "${bbu_address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Address Check" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- ${bbu_address} BBU Address"
		    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Check;${bbu_address}" "${bbu_address}" "PASS" "${RackSN}"
            update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Address Check" 2
        fi

        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 1
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name Manufacture_Name" "${wedge400IP}" | tee ${BBULog}
        BBUVendor=$(cat ${BBULog} | grep "Manufacture_Name<" | awk '{print$NF}' | tr -d '"')
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${BBULog}
        BBUType=$(cat ${BBULog} | grep "Device Type:" | awk '{print$NF}')
	BBUPMMVendor=$(cat ${LOGFOLDER}/BBUPMMVendor.txt)

        if [ ${BBUType} == "ORV3_HPR_BBU" ];then
            if [ ${BBUVendor^^} == "PANASONIC" ];then
                if [ ${BBUVendor^^} == ${BBUPMMVendor} ];then
                    declare -a BBU_Array=("${PANASONIC_BBU_Data_Array[@]}")
                else
                    echo "The BBU PMM Vendor : ${BBUPMMVendor^^} is not match as the BBU Vendor : ${BBUVendor}, stop the test"
                    return 1
                fi
            elif [ ${BBUVendor^^} == "DELTA" ];then
                if [ ${BBUVendor^^} == ${BBUPMMVendor} ];then
                    declare -a BBU_Array=("${DELTA_BBU_Data_Array[@]}")
                else
                    echo "The BBU PMM Vendor : ${BBUPMMVendor^^} is not match as the BBU Vendor : ${BBUVendor}, stop the test"
                    return 1
                fi
            else
                echo "Can't get correct BBU vendor, stop the test"
                update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                return 1
            fi
        else
            echo "The address is not belongs to BBU, stop the test"
            update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
            return 1
        fi

        echo "BBU Module Infotmation Check for address : ${bbu_address}"
        if [ ${BBUVendor} == "Panasonic" ];then
            BBUInfo=("Facebook_Part_Number" "Manufacture_Model" "Manufacture_Date" "MFR_Serial" "HW_Revision" "FW_Revision" "Battery_Pack_FW_Revision")
        else
            BBUInfo=("Facebook_Part_Number" "Manufacture_Model" "Manufacture_Date" "MFR_Serial" "HW_Revision" "FW_Revision")
        fi

        for i in "${!BBUInfo[@]}"; do
            exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name ${BBUInfo[$i]}" "${wedge400IP}" | tee ${BBULog}
            record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "NA" "${RackSN}"

		    if [ ${BBUInfo[$i]} == "Manufacture_Date" ];then
                logResultCheck "CheckEGREPFormat" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 2
                fi
		    elif [ ${BBUInfo[$i]} == "MFR_Serial" ];then
                logResultCheck "CheckEGREPValue" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 2
                fi
		    elif [ ${BBUInfo[$i]} == "Manufacture_Model" ];then
                logResultCheck "CheckWholeResult" "${BBUInfo[$i]}<;NF" "${BBU_Array[$i]}" "${BBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 2
                fi
            elif [ ${BBUInfo[$i]} == "FW_Revision" ];then                 
                logResultCheck "LogCheck" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"                 
                if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                    show_warn_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"                          
                    echo "Need to update the FW for BBU, continue the update process"
                    BBU_Update_Process "$bbu_address" "$BBUType" "$BBUVendor" "${BBU_Array[$i]}"
                    if [ ${PIPESTATUS[0]} -eq 0 ];then
                        echo "The BBU type ${BBUType} for vendor ${BBUVendor} already updated, check the FW again"
                        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name ${BBUInfo[$i]}" "${wedge400IP}" | tee ${BBULog}
                        logResultCheck "LogCheck" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"
                        if [ ${PIPESTATUS[0]} -eq 0 ];then
                            echo "The BBU FW already update to ${BBU_Array[$i]}, continue the test"
                        else
                            echo "The BBU FW don't update to ${BBU_Array[$i]}, stop the test"
                            record_time "HPRv3_WG400_BBU_Standalone" end "BBU_${bbu_address}_Information_Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
                            record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                            update_status "$SN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                            return 1
                        fi
                    else
                        echo "The BBU FW don't update to ${BBU_Array[$i]}, stop the test"
                        update_status "$SN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                        return 1
                    fi
                else                         
                    show_pass_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"                         
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU_${bbu_address}_Information_Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"   
                    update_status "$SN" "$folder" "$index" "$testitem" "BBU Info Check" 2              
                fi
            # elif [ ${BBUInfo[$i]} == "FW_Revision" ];then                 
            #     logResultCheck "LogCheck" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"                 
            #     if [ ${PIPESTATUS[0]} -ne 0 ];then                         
            #         show_warn_msg "Rack Module Test -- BBU_${bbu_address}_Information_Check Test -> ${BBUInfo[$i]}"                          
            #         echo "Need to update the FW for BBU, continue the update process"
            #         BBU_Update_Process "$bbu_address" "$BBUType" "$BBUVendor" "${BBU_Array[$i]}"
            #         if [ ${PIPESTATUS[0]} -eq 0 ];then
            #             echo "The BBU type ${BBUType} for vendor ${BBUVendor} already updated, check the FW again"
            #             exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name ${BBUInfo[$i]}" "${wedge400IP}" | tee ${BBULog}
            #             logResultCheck "LogCheck" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"
            #             if [ ${PIPESTATUS[0]} -eq 0 ];then
            #                 echo "The BBU FW already update to ${BBU_Array[$i]}, continue the test"
            #             else
            #                 echo "The BBU FW don't update to ${BBU_Array[$i]}, stop the test"
            #                 record_time "HPRv3_WG400_BBU_Standalone" end "BBU_${address}_Information_Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
            #                 record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
            #                 return 1
            #             fi
            #         else
            #             echo "The BBU FW don't update to ${BBU_Array[$i]}, stop the test"
            #             return 1
            #         fi
            #     else                         
            #         show_pass_msg "Rack Module Test -- BBU_${address}_Information_Check Test -> ${BBUInfo[$i]}"                         
            #         record_time "HPRv3_WG400_BBU_Standalone" end "BBU_${address}_Information_Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"                 
            #     fi
            else
                logResultCheck "LogCheck" "${BBUInfo[$i]}<" "NF;${BBU_Array[$i]}" "${BBULog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_Information_Check Test -> ${BBUInfo[$i]}"
                    record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Info Check;${BBUInfo[$i]}" "${BBU_Array[$i]}" "PASS" "${RackSN}"
                    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Info Check" 2
                fi
            fi
        done

        #update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 1
        #echo "PSU_Input_Power Check Test on address : ${bbu_address}"
        #echo "Check the value is large between 4500 and 5500"
        #record_time "HPRv3_WG400_BBU_Standalone" start "PSU Address ${bbu_address} PSU_Input_Power Check;PSU_Input_Power" "5500 > Power > 4500" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name PSU_Input_Power" "${wedge400IP}" | tee ${PSULog}
        #logResultCheck "ValueCheck" "PSU_Input_Power<0x0057>" "NF;>;4500" "${PSULog}"
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
        #    echo "Check the value is less than 5500"
        #    logResultCheck "ValueCheck" "PSU_Input_Power<0x0057>" "NF;<;5500" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -eq 0 ];then
        #        show_pass_msg "Rack Module Information Test -- ${bbu_address} PSU_Input_Power"
        #        record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Input_Power Check;PSU_Input_Power" "5500 > Power > 4500" "PASS" "${RackSN}"
        #           update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    else
        #        show_fail_msg "Rack Module Information Test -- ${bbu_address} PSU_Input_Power "
        #        record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Input_Power Check;PSU_Input_Power" "5500 > Power > 4500" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    fi
        #else
        #    show_fail_msg "Rack Module Information Test -- ${bbu_address} PSU_Input_Power"
        #    record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Input_Power Check;PSU_Input_Power" "5500 > Power > 4500" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #    return 1
        #fi

        #echo "PSU_Output_Power Check Test on address : ${bbu_address}"
        #echo "Check the value is large than 4500W"        record_time "HPRv3_WG400_BBU_Standalone" start "PSU Address ${bbu_address} PSU_Output_Power Check;PSU_Output_Power" "4500 < Power < 5500" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name PSU_Output_Power" "${wedge400IP}" | tee ${PSULog}
        #if [ ${bbu_address} == 0x90 ] || [ ${bbu_address} == 0x91 ] || [ ${bbu_address} == 0x92 ] || [ ${bbu_address} == 0x94 ] || [ ${bbu_address} == 0x9a ] || [ ${bbu_address} == 0x9d ] || [ ${bbu_address} == 0x9e ];then
        #logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;>;4500" "${PSULog}"
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
        #    echo "Check the value is less than 5500W"
        #    logResultCheck "ValueCheck" "PSU_Output_Power<0x0052>" "NF;<;5500" "${PSULog}"
        #    if [ ${PIPESTATUS[0]} -eq 0 ];then
        #        show_pass_msg "Rack Module Information Test -- ${bbu_address} PSU_Output_Power"
        #        record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Output_Power Check;PSU_Output_Power" "4500 < Power < 5500" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    else
        #        show_fail_msg "Rack Module Information Test -- ${bbu_address} PSU_Output_Power"
        #        record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Output_Power Check;PSU_Output_Power" "4500 < Power < 5500" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    fi
        #else
        #    show_fail_msg "Rack Module Information Test -- ${bbu_address} PSU_Output_Power"
        #    record_time "HPRv3_WG400_BBU_Standalone" end "PSU Address ${bbu_address} PSU_Output_Power Check;PSU_Output_Power" "4500 < Power < 5500" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #    update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #    return 1
        #fi

        #echo "BBUs Status Check Test for address : ${bbu_address}"
        #Register=("Charge_FET_Failure" "AFE_Failure" "Cell_Balancing_Failure" "Fan_Failure" "EOL" "Cell_Over_Voltage" "Pack_Under_Voltage" "Cell_Under_Voltage" "Pack_Over_Current" "Temperature_Failure")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} Status Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBUs Mode Check Test for address : ${bbu_address}"
        #Register=("CANBUS_Communication_Failure" "SMBUS_Communication_Failure")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Mode" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Mode Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU Mode Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Mode Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU Mode Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Mode Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "Battery Status Check Test for address : ${bbu_address}"
        #Register=("Over_Temperature_Alarm" "Terminate_Charge_Alarm" "Over_Charge_Alarm")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name Battery_Status" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU Status Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} Battery Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Battery Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} Battery Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} Battery Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "Permanent_Failures Status Check Test for address : ${bbu_address}"
        #Register=("Cell_Over_Voltage" "Cell_Under_Voltage" "Cell_Over_Temperature" "Cell_Balancing_Failure" "Charge_FET_Failure" "Discharge_FET_failure" "AFE_Failure" "Fan_Failure" "Fuse_Failure" "Micro_Failure" "Charge_Timeout" "Temp_Sensor_Failure")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name Permanent_Failures" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU Permanent_Failures Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} Permanent_Failures Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU Permanent_Failures Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} Permanent_Failures Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU Permanent_Failures Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "LED Status Check Test for address : ${bbu_address}"
        #Register=("EOL_LED_On" "FAULT_LOC_LED_On")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name LED_Status" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU LED Status Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} LED Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU LED Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} LED Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU LED Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBU_Status_Word Status Check Test for address : ${bbu_address}"
        #Register=("Temperature_Fault" "Power_Boost_Converter_Fault" "Buck_Converter_Fault" "Charger_Converter_Fault" "Fan_Fault")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status_Word" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Status_Word Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU_Status_Word Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Word Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU_Status_Word Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Word Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBU_Status_Power_Boost Status Check Test for address : ${bbu_address}"
        #Register=("Power_Boost_SCP1" "Power_Boost_OCP" "Power_Boost_OVP" "Power_Boost_SCP2" "Power_Boost_UVP")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status_Power_Boost" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Status_Power_Boost Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU_Status_Power_Boost Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Power_Boost Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU_Status_Power_Boost Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Power_Boost Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBU_Status_Buck_Converter Status Check Test for address : ${bbu_address}"
        #Register=("Buck_Output_OVP")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status_Buck_Converter" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Status_Buck_Converter Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU_Status_Buck_Converter Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Buck_Converter Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU_Status_Buck_Converter Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Buck_Converter Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBU_Status_Charger Status Check Test for address : ${bbu_address}"
        #Register=("Charger_Input_OVP" "Charger_Input_UVP" "Charger_Output_OVP" "Charger_Output_OCP" "Charger_Timeout")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status_Charger" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Status_Charger Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Charger Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Charger Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "BBU_Status_Temperature Status Check Test for address : ${bbu_address}"
        #Register=("Input_Ambient_OTP" "Output_Ambient_OTP" "Charger_OTP" "Buck_Converter_OTP" "Power_Boost_OTP" "Battery_Pack_OTP")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name BBU_Status_Temperature" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} BBU_Status_Temperature Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} BBU_Status_Temperature Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Temperature Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} BBU_Status_Temperature Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} BBU_Status_Temperature Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done

        #echo "End_of_Life_Status Status Check Test for address : ${bbu_address}"
        #Register=("BBU_EOL")
	#    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${bbu_address} --reg-name End_of_Life_Status" "${wedge400IP}" | tee ${BBULog}
        #for Reg in "${Register[@]}"; do
	#	    record_time "HPRv3_WG400_BBU_Standalone" start "BBU ${bbu_address} End_of_Life_Status Check;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBULog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- ${bbu_address} End_of_Life_Status Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} End_of_Life_Status Check;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "FAIL" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- ${bbu_address} End_of_Life_Status Status Test ${Reg}"
	#	        record_time "HPRv3_WG400_BBU_Standalone" end "BBU ${bbu_address} End_of_Life_Status Check;${Reg}" "[0]" "PASS" "${RackSN}"
        #        update_status "$RackSN" "$folder" "$index" "$testitem" "BBU Function Check" 2
        #    fi
        #done
   done
}

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
RackmonLog=${LOGFOLDER}/RackMonLog.txt
BBULog=${LOGFOLDER}/BBULog.txt
LOGFILE=${LOGFOLDER}/log.txt
BBUUpdateLog=${LOGFOLDER}/BBUUpdate.txt
folder=RUSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_BBU_Standalone" initial "" "" "" "$RackSN"
ssh-keygen -R "${wedge400IP}" > /dev/null

Normal_HPRv3_BBU_Funtional_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 BBU Function Test" | tee -a ${LOGFILE}
        show_fail | tee -a ${LOGFILE}
   	finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_BBUSTANDALONE_FAIL_${startTime}.log
   	record_time "HPRv3_WG400_BBU_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
        cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
	cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
   	cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
   	exit 1
fi

show_pass_msg "HPRv3 BBU Function Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_BBUSTANDALONE_PASS_${startTime}.log
record_time "HPRv3_WG400_BBU_Standalone" total "HPRv3_WG400_BBU_Standalone;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_BBU_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

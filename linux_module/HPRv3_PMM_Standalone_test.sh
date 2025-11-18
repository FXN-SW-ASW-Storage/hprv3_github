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
                    exit 1
            fi
        ;;
        *)
            print_help
            exit 1
        ;;
    esac
done

PMM_Update_Process()
{
    UpdateAddress=$1
    PMMType=$2
    PMMVendor=$3
    TargetVer=$4
    echo "Need updated address ${address} with PMM type : ${PMMType} and PMM vendor : ${PMMVendor}"

    PMMImage=$(ls $TOOL/${PMMType}/${PMMVendor}/)
    if [ ${PMMVendor^^} == "ARTESYN" ] && [ ${PMMType} == "ORV3_HPR_PMM_PSU" ];then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_aei /tmp/${PMMImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_aei /tmp/${PMMImage}" "${wedge400IP}" | tee ${PMMUpdateLog} 
        Status=$(cat ${PMMUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${PMMUpdateLog} | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ' )
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${PMMVendor} for ${PMMType} PMM already update to target version ${TargetVer}"
            else
                echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
                return 1
            fi
        else    
            echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
            return 1
        fi

    elif [ ${PMMVendor^^} == "PANASONIC" ] && [ ${PMMType} == "ORV3_HPR_PMM_BBU" ];then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi

        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_panasonic /tmp/${PMMImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_panasonic /tmp/${PMMImage}" "${wedge400IP}" | tee ${PMMUpdateLog} 
        Status=$(cat ${PMMUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${PMMUpdateLog} | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ' )
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${PMMVendor} for ${PMMType} PMM already update to target version ${TargetVer}"
            else
                echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
                return 1
            fi
        else    
            echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
            return 1
        fi
    elif ([ ${PMMVendor^^} == "DELTA" ] || [ ${PMMVendor^^} == "Delta" ]) && ([ ${PMMType} == "ORV3_HPR_PMM_PSU" ] || [ ${PMMType} == "ORV3_HPR_PMM_BBU" ]) ;then

        echo "Send the update image to Wedge400"
        echo "Command : sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp"
        sshpass -p "0penBmc" sshpass -p "0penBmc" scp $TOOL/${PMMType}/${PMMVendor}/${PMMImage} ${wedge400IP}:/tmp
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            echo "Can't send the update image into Wedge400"
            show_fail_msg "Rack Module Information Test -- SCP Image"
            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- SCP Image"
        fi
        echo "Update command : flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_delta /tmp/${PMMImage}"
        exeucte_test "flock /tmp/modbus_dynamo_solitonbeam.lock /usr/local/bin/orv3-device-update-mailbox.py --addr ${UpdateAddress} --vendor hpr_pmm_delta /tmp/${PMMImage}" "${wedge400IP}" | tee ${PMMUpdateLog} 
        Status=$(cat ${PMMUpdateLog} | grep "Upgrade success" | wc -l)
        newFWVer=$(cat ${PMMUpdateLog}  | grep -A 4 "Upgrade success" | grep Version | awk -F ':' '{print$2}' | tr -d ' ')
        if [ ${Status} -eq 1 ];then
            if [ ${newFWVer} == "$TargetVer" ];then
                echo "The vendor ${PMMVendor} for ${PMMType} PMM already update to target version ${TargetVer}"
            else
                echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
                return 1
            fi
        else    
            echo "The vendor ${PMMVendor} for ${PMMType} PMM can't update to target version ${TargetVer}, stop the test"
            return 1
        fi
    else
        echo "Can't get correct PMM vendor or PMM type, stop the test"
        return 1
    fi
}

Normal_HPRv3_GPIO_test()
{
    record_time "HPRv3_WG400_PMM_Standalone" start "Wedge400_GPIO_Test;NA" "6" "NA" "${RackSN}"
    update_status "$SN" "$folder" "$index" "$testitem" "GPIO Test" 1
    echo "Rack Module Information Test - Wedge400 GPIO Test"
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    exeucte_test "cat /tmp/gpionames/RMON*/value" "${wedge400IP}" | tee ${GPIOLog}
    GPIONum=$(cat $GPIOLog | egrep "1" | grep -v "*1*" | wc -l)
	if [ ${GPIONum} -ne 6 ];then
        show_fail_msg "Rack Module Information Test -- Wedge400 GPIO Test"
        record_time "HPRv3_WG400_PMM_Standalone" end "Wedge400_GPIO_Test;NA" "6" "FAIL" "${RackSN}"
        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "GPIO Test" 3
        return 1
    else
        show_pass_msg "Rack Module Information Test -- Wedge400 GPIO Test"
        record_time "HPRv3_WG400_PMM_Standalone" end "Wedge400_GPIO_Test;NA" "6" "PASS" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "GPIO Test" 2
    fi
}


Normal_Wedge400_Gen_Whole_Log()
{
	record_time "HPRv3_WG400_PMM_Standalone" start "Wedge400_Whole_Log;NA" "NA" "NA" "${RackSN}"
	echo "Rack Module Information Test - Generate Whole Log"
	update_status "$SN" "$folder" "$index" "$testitem" "Get Whole Log Test" 1
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    exeucte_test "/usr/local/bin/rackmoninfo" "${wedge400IP}" | tee ${RackmonLog} 
    #logResultCheck "ShowOnly" "NA" "NA" "${RackmonLog}"
    sleep 10
    rackmonlogCount=$(cat ${RackmonLog} | wc -l)
    if [ ${rackmonlogCount} -lt 900 ];then
        echo "Can not generate all rackmoninfo log or the content is less than 1000 line"
        show_fail_msg "Rack Module Information Test -- Generate Log"
        record_time "HPRv3_WG400_PMM_Standalone" end "Wedge400_Whole_Log;NA" "1000" "FAIL" "${RackSN}"
        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "Get Whole Log Test" 3
        return 1
    else
        echo "Can generate all rackmoninfo log and the content is more than 1000 line"
        show_pass_msg "Rack Module Information Test -- Generate Log"
	update_status "$SN" "$folder" "$index" "$testitem" "Get Whole Log Test" 2
        record_time "HPRv3_WG400_PMM_Standalone" end "Wedge400_Whole_Log;NA" "1000" "PASS" "${RackSN}"
    fi    


}



Normal_HPRv3_PMM_Funtional_test()
{
    HPR_PMM_PSU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PMM_PSU" | grep "Device Address" | awk '{print$NF}'))
    HPR_PMM_BBU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PMM_BBU" | grep "Device Address" | awk '{print$NF}'))
    echo "HPR PSU PMM Address : ${HPR_PMM_PSU_AddressArr[@]}"
    echo "HPR BBU PMM Address : ${HPR_PMM_BBU_AddressArr[@]}"
    	
	declare -a ARTESYN_PSUPMM_Data_Array=("03-100050" "700-043397-0000" "^[0-9]{2}/[0-9]{4}$" "PMM1AEL" "A00" "0006")
	declare -a DELTA_PSUPMM_Data_Array=("03-100037" "ECD90000111" "^[0-9]{2}/[0-9]{4}$" "M2HPDET" "04" "1140")
	declare -a DELTA_BBUPMM_Data_Array=("03-100037" "ECD90000111" "^[0-9]{2}/[0-9]{4}$" "M2HPDET" "04" "1140")
	declare -a PANA_BBUPMM_Data_Array=("03-100048" "BJ-BPM102A;0001" "^[0-9]{2}/[0-9]{4}$" "M1V4PAM" "M01" "00.01.1F")

	for address in ${HPR_PMM_PSU_AddressArr[@]};do
		update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Address Test" 1
		record_time "HPRv3_WG400_PMM_Standalone" start "PSU_PMM_Check;${address}" "${address}" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address}" "${wedge400IP}" | tee ${PSUPMMLog} 
        echo "PSU PMM Address and Modbus Address : ${address} Check Test"	
        logResultCheck "CheckResult" "Device Address;NF" "${address}" "${PSUPMMLog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM_Standalone" end "PSU_PMM_Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Address Test" 3
            return 1
        else
            show_pass_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM_Standalone" end "PSU_PMM_Check;${address}" "${address}" "PASS" "${RackSN}"
        	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Address Test" 2
	fi
		update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 1
		exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PMM_MFR_Name" "${wedge400IP}" | tee ${PSUPMMLog}  
		PMMVendor=$(cat ${PSUPMMLog} | grep "PMM_MFR_Name<0x0008>" | awk '{print$NF}' | tr -d '"')  
		exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${PSUPMMLog} 
		PMMType=$(cat ${PSUPMMLog} | grep "Device Type:" | awk '{print$NF}')  
		if [ ${PMMType} == "ORV3_HPR_PMM_PSU" ];then     
			if [ ${PMMVendor} == "ARTESYN" ];then         
				declare -a PMM_Array=("${ARTESYN_PSUPMM_Data_Array[@]}")   
			elif [ ${PMMVendor} == "DELTA" ] || [ ${PMMVendor} == "Delta" ];then         
				declare -a PMM_Array=("${DELTA_PSUPMM_Data_Array[@]}")   
			else         
				echo "Can't get correct PSU PMM vendor, stop the test"         
				 update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
				return 1     
			fi 
            echo ${PMMVendor^^} > ${PSUPMMVendorLog}
		else     
			echo "The address is not belongs to PSU PMM, stop the test"     
			 update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
			return 1 
		fi
	
		echo "PMM Module Inforamtion Check for address : ${address}"         
		PMMInfo=("PMM_FBPN" "PMM_MFR_Model" "PMM_MFR_Date" "PMM_MFR_Serial" "PMM_HW_Revision" "PMM_FW_Revision")          
		for i in "${!PMMInfo[@]}"; do             
			exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PMMInfo[$i]}" "${wedge400IP}" | tee ${PSUPMMLog}             
			record_time "HPRv3_WG400_PMM_Standalone" start "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "NA" "${RackSN}"              
			if [ ${PMMInfo[$i]} == "PMM_MFR_Date" ];then                 
				logResultCheck "CheckEGREPFormat" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"                         
					update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
					update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 2
				fi             
			elif [ ${PMMInfo[$i]} == "PMM_MFR_Serial" ];then                 
				logResultCheck "CheckEGREPValue" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"                         
					update_status "$SN" "$folder" "$index" "$testitem" "PMM Test" 3
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"                 
					update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 2
				fi            
            elif [ ${PMMInfo[$i]} == "PMM_FW_Revision" ];then                 
                logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
                if [ ${PIPESTATUS[0]} -ne 0 ];then                         
                    echo "Need to update the FW for PMM, continue the update process"
                    PMM_Update_Process "$address" "$PMMType" "$PMMVendor" "${PMM_Array[$i]}"
                    if [ ${PIPESTATUS[0]} -eq 0 ];then
                        echo "The PMM type ${PMMType} for vendor ${PMMVendor} already updated, check the FW again"
                        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PMMInfo[$i]}" "${wedge400IP}" | tee ${PSUPMMLog}
                        logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"
                        if [ ${PIPESTATUS[0]} -eq 0 ];then
                            echo "The PMM FW already update to ${PMM_Array[$i]}, continue the test"
				record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 2
                        else
                            echo "The PMM FW don't update to ${PMM_Array[$i]}, stop the test"
				record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                                        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
                            return 1
                        fi
                    else
                        echo "The PMM FW don't update to ${PMM_Array[$i]}, stop the test"
				record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                                        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
                        return 1
                    fi
                else                         
                    show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
                    record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"                 
			update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 2
                fi



  
			else                 
				logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"                       
				update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 3
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"    
					update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Information Test" 2
				fi              
			fi         
		done

				
    	#update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM ISHARE Test" 1
        #echo "ISHARE Cable Connection Test on Address : ${address}"
        #record_time "HPRv3_WG400_PMM_Standalone" start "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ISHARE_Cable_Connected" "${wedge400IP}" | tee ${PSUPMMLog}
        #if [ ${address} == "0x20" ];then
        #    logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "0" "${PSUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
	#	        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM ISHARE Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
	#	        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM ISHARE Test" 2
        #    fi
        #else
        #    logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "1" "${PSUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
	#	        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_ISHARE_Check;${address}" "1" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM ISHARE Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
	#	        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_ISHARE_Check;${address}" "1" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM ISHARE Test" 2
        #    fi
        #fi
	#
	#update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Present Test" 1
	#    echo "6 PSU PMM Module Present for address : ${address}" 
        #PSUPresent=("Module1_Present" "Module2_Present" "Module3_Present" "Module4_Present" "Module5_Present" "Module6_Present")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Present" "${wedge400IP}" | tee ${PSUPMMLog}
        #for PSU in "${PSUPresent[@]}"; do
        #    record_time "HPRv3_WG400_PMM_Standalone" start "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${PSU}" "1;[1]" "${PSUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- PSU ${PSU} PMM Present Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Present Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- PSU ${PSU} PMM Present Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Present Test" 2
        #    fi
        #done

        ##0408 Only for debug
	#update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Alert Test" 1
        #echo "6 PSU PMM Module Alert for address : ${address}"
        #PSUAlert=("Module1_Alert" "Module2_Alert" "Module3_Alert" "Module4_Alert" "Module5_Alert" "Module6_Alert")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Alert" "${wedge400IP}" | tee ${PSUPMMLog}
        #for PSU in "${PSUAlert[@]}"; do
        #   #record_time "HPRv3_WG400_PMM_Standalone" start "PSU_${address}_PMM_Alert_Check;${PSU}" "[1]" "NA" "${RackSN}"
        #   record_time "HPRv3_WG400_PMM_Standalone" start "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "NA" "${RackSN}"
        #  #logResultCheck "LogCheck" "${PSU}" "1;[1]" "${PSUPMMLog}"
        #  logResultCheck "LogCheck" "${PSU}" "1;[0]" "${PSUPMMLog}"
        #   if [ ${PIPESTATUS[0]} -ne 0 ];then
        #       show_fail_msg "Rack Module Test -- PSU ${PSU} PMM Alert Test"
        #       #record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Alert_Check;${PSU}" "[1]" "FAIL" "${RackSN}"
        #       record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "FAIL" "${RackSN}"
        #       record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Alert Test" 3
        #       return 1
        #   else
        #       show_pass_msg "Rack Module Test -- PSU ${PSU} PMM Alert Test"
        #       record_time "HPRv3_WG400_PMM_Standalone" end "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM Alert Test" 2
        #   fi
        #done
	#
	#update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM General_Alarm_Status_Register Test" 1
	#    echo "General_Alarm_Status_Register Test for PSU PMM address : ${address}"
        #Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault")
        ##Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault" "Module_Alerts")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name General_Alarm_Status_Register" "${wedge400IP}" | tee ${PSUPMMLog}
        #for Reg in "${Register[@]}"; do
        #    record_time "HPRv3_WG400_PMM_Standalone" start "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "NA" "${RackSN}"
        #    logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM General_Alarm_Status_Register Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "PSU PMM General_Alarm_Status_Register Test" 2
        #    fi
        #done
    done

    for address in ${HPR_PMM_BBU_AddressArr[@]};do
	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Address Test" 1
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address}" "${wedge400IP}" | tee ${BBUPMMLog} 
        echo "BBU PMM Address and Modbus Address : ${address} Check Test"
	    record_time "HPRv3_WG400_PMM_Standalone" start "BBU_PMM_Check;${address}" "${address}" "NA" "${RackSN}"
        logResultCheck "CheckResult" "Device Address;NF" "${address}" "${BBUPMMLog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
	        show_fail_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
		    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_PMM_Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
            		update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Address Test" 3
		return 1
        else
            show_pass_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM_Standalone" end "BBU_PMM_Check;${address}" "${address}" "PASS" "${RackSN}"
		update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Address Test" 2
        fi
    
	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 1
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PMM_MFR_Name" "${wedge400IP}" | tee ${BBUPMMLog}
        PMMVendor=$(cat ${BBUPMMLog} | grep "PMM_MFR_Name<0x0008>" | awk '{print$NF}' | tr -d '"')

        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${BBUPMMLog}
        PMMType=$(cat ${BBUPMMLog} | grep "Device Type:" | awk '{print$NF}')

        if [ ${PMMType} == "ORV3_HPR_PMM_BBU" ];then
            if [ ${PMMVendor} == "Panasonic" ];then
		        declare -a PMM_Array=("${PANA_BBUPMM_Data_Array[@]}")
            elif [ ${PMMVendor} == "Delta" ];then
                declare -a PMM_Array=("${DELTA_BBUPMM_Data_Array[@]}")
            else
                echo "Can't get correct BBU PMM vendor, stop the test"
		update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                return 1
            fi
            echo "${PMMVendor^^}" > ${BBUPMMVendorLog}
        else
            echo "The address is not belongs to BBU PMM, stop the test"
		update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
            return 1
        fi

	    echo "PMM Module Inforamtion Check for address : ${address}" 
        PMMInfo=("PMM_FBPN" "PMM_MFR_Model" "PMM_MFR_Date" "PMM_MFR_Serial" "PMM_HW_Revision" "PMM_FW_Revision")

        for i in "${!PMMInfo[@]}"; do
            exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PMMInfo[$i]}" "${wedge400IP}" | tee ${BBUPMMLog}
            record_time "HPRv3_WG400_PMM_Standalone" start "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "NA" "${RackSN}"

            if [ ${PMMInfo[$i]} == "PMM_MFR_Date" ];then
		        logResultCheck "CheckEGREPFormat" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 2
                fi
            elif [ ${PMMInfo[$i]} == "PMM_MFR_Serial" ];then
                logResultCheck "CheckEGREPValue" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 2
                fi
          elif [ ${PMMInfo[$i]} == "PMM_FW_Revision" ];then                 
		if [ ${PMMVendor} == "Delta" ];then
		    logResultCheck "CheckWholeResult" "${PMMInfo[$i]}<;NF" "${PMM_Array[$i]}" "${BBUPMMLog}"
              	    if [ ${PIPESTATUS[0]} -ne 0 ];then
			echo "necesita update"
                    	PMM_Update_Process "$address" "$PMMType" "$PMMVendor" "${PMM_Array[$i]}"
		    fi
		fi
	  elif [ ${PMMInfo[$i]} == "PMM_MFR_Model" ];then
		if [ ${PMMVendor} == "Panasonic" ];then
			totalPassWord_Str1=$(echo ${PMM_Array[$i]} | awk -F ';' '{print$1}' | tr -d '\r\n')
			totalPassWord_Str2=$(echo ${PMM_Array[$i]} | awk -F ';' '{print$2}' | tr -d '\r\n')
             		echo "Check the part1 Model Name" 
			logResultCheck "LogCheck" "${PMMInfo[$i]}<" "3;${totalPassWord_Str1}" "${BBUPMMLog}"
                        if [ ${PIPESTATUS[0]} -ne 0 ];then
                            show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                            record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                            record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                            return 1
                        else
			    echo "Check the part2 Model Name"
			    	
			    logResultCheck "LogCheck" "${PMMInfo[$i]}<" "4;${totalPassWord_Str2}" "${BBUPMMLog}"
                            if [ ${PIPESTATUS[0]} -eq 0 ];then
			    	show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                            	record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 2
			    else
				record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"			
			        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
		                return 1
		   	    fi
                        fi
		else

			logResultCheck "CheckWholeResult" "${PMMInfo[$i]}<;NF" "${PMM_Array[$i]}" "${BBUPMMLog}"
              		if [ ${PIPESTATUS[0]} -ne 0 ];then
                	  	show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                  		record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                  		record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                  		return 1
              		else
                  		show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                  		record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
				update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 2
              		fi
		fi



	        else
                logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 3
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Information Test" 2
                fi
            fi
        done

	#update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM ISHARE Test" 1
        #echo "ISHARE Cable Connection Test on Address : ${address}"
        #record_time "HPRv3_WG400_PMM_Standalone" start "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "NA" "${RackSN}"
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ISHARE_Cable_Connected" "${wedge400IP}" | tee ${BBUPMMLog}
        #if [ ${address} == "0x10" ];then
        #    logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "0" "${BBUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#		update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM ISHARE Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM ISHARE Test" 2
        #    fi
        #else
        #    logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "1" "${BBUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_ISHARE_Check;${address}" "1" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM ISHARE Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM ISHARE Test" 2
        #    fi
        #fi

	#update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Present Test" 1
        #echo "6 BBU PMM Module Present for address : ${address}" 
        #BBUPresent=("Module1_Present" "Module2_Present" "Module3_Present" "Module4_Present" "Module5_Present" "Module6_Present")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Present" "${wedge400IP}" | tee ${BBUPMMLog}
        #for BBU in "${BBUPresent[@]}"; do
        #    record_time "HPRv3_WG400_PMM_Standalone" start "BBU_${address}_PMM_Present_Check;${address}" "[1]" "NA" "${RackSN}"	
        #    logResultCheck "LogCheck" "${BBU}" "1;[1]" "${BBUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- BBU ${BBU} PMM Present Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Present_Check;${address}" "[1]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Present Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- BBU ${BBU} PMM Present Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Present_Check;${address}" "[1]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Present Test" 2
        #    fi
        #done

	#update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Alert Test" 1
        #echo "6 BBU PMM Module Alert for address : ${address}"
        #BBUAlert=("Module1_Alert" "Module2_Alert" "Module3_Alert" "Module4_Alert" "Module5_Alert" "Module6_Alert")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Alert" "${wedge400IP}" | tee ${BBUPMMLog}
        #for BBU in "${BBUAlert[@]}"; do
        #    record_time "HPRv3_WG400_PMM_Standalone" start "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "NA" "${RackSN}"	
        #    logResultCheck "LogCheck" "${BBU}" "1;[0]" "${BBUPMMLog}"
        #    if [ ${PIPESTATUS[0]} -ne 0 ];then
        #        show_fail_msg "Rack Module Test -- BBU ${BBU} PMM Alert Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "FAIL" "${RackSN}"
        #        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Alert Test" 3
        #        return 1
        #    else
        #        show_pass_msg "Rack Module Test -- BBU ${BBU} PMM Alert Test"
        #        record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM Alert Test" 2
        #    fi
        #done

	#update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM General_Alarm_Status_Register Test" 1
        #echo "General_Alarm_Status_Register Test for address : ${address}"
        #Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault" "Module_Alerts")
        #exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name General_Alarm_Status_Register" "${wedge400IP}" | tee ${BBUPMMLog}
        #for Reg in "${Register[@]}"; do
        #record_time "HPRv3_WG400_PMM_Standalone" start "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "NA" "${RackSN}"
        #logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBUPMMLog}"
        #if [ ${PIPESTATUS[0]} -ne 0 ];then
        #    show_fail_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
        #    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "FAIL" "${RackSN}"
        #    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM General_Alarm_Status_Register Test" 3
        #    return 1
        #else
        #    show_pass_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
        #    record_time "HPRv3_WG400_PMM_Standalone" end "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "PASS" "${RackSN}"
	#	update_status "$SN" "$folder" "$index" "$testitem" "BBU PMM General_Alarm_Status_Register Test" 2
        #    fi
        #done
    done
}

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
PSUPMMLog=${LOGFOLDER}/PSUPMMLog.txt
BBUPMMLog=${LOGFOLDER}/BBUPMMLog.txt
GPIOLog=${LOGFOLDER}/GPIOLog.txt
RackmonLog=${LOGFOLDER}/RackMonLog.txt
PSUPMMVendorLog=${LOGFOLDER}/PMMVendor.txt
BBUPMMVendorLog=${LOGFOLDER}/BBUPMMVendor.txt
LOGFILE=${LOGFOLDER}/log.txt
PMMUpdateLog=${LOGFOLDER}/PMMUpdate.txt
folder=RUSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_PMM_Standalone" initial "" "" "" "$RackSN" 

Normal_HPRv3_GPIO_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
        show_fail | tee -a ${LOGFILE}    
    	finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMSTANDALONE_FAIL_${startTime}.log
        record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
   	record_time "HPRv3_WG400_PMM_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    	cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    	cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    	cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    	exit 1
fi

Normal_Wedge400_Gen_Whole_Log | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}    	
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMSTANDALONE_FAIL_${startTime}.log
    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
    record_time "HPRv3_WG400_PMM_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

Normal_HPRv3_PMM_Funtional_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}    
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMSTANDALONE_FAIL_${startTime}.log
    record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "FAIL" "${RackSN}"
    record_time "HPRv3_WG400_PMM_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

echo "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMSTANDALONE_PASS_${startTime}.log
record_time "HPRv3_WG400_PMM_Standalone" total "HPRv3_WG400_PMM_Standalone;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_PMM_Standalone" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

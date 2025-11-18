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

Normal_HPRv3_GPIO_test()
{
    record_time "HPRv3_WG400_PMM" start "Wedge400_GPIO_Test;NA" "6" "NA" "${RackSN}"
    echo "Rack Module Information Test - Wedge400 GPIO Test"
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    exeucte_test "cat /tmp/gpionames/RMON*/value" "${wedge400IP}" | tee ${GPIOLog}
    GPIONum=$(cat $GPIOLog | egrep "1" | grep -v "*1*" | wc -l)
	if [ ${GPIONum} -ne 6 ];then
        show_fail_msg "Rack Module Information Test -- Wedge400 GPIO Test"
        record_time "HPRv3_WG400_PMM" end "Wedge400_GPIO_Test;NA" "6" "FAIL" "${RackSN}"
        record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
        return 1
    else
        show_pass_msg "Rack Module Information Test -- Wedge400 GPIO Test"
        record_time "HPRv3_WG400_PMM" end "Wedge400_GPIO_Test;NA" "6" "PASS" "${RackSN}"
    fi
}


Normal_Wedge400_Gen_Whole_Log()
{
	record_time "HPRv3_WG400_PMM" start "Wedge400_Whole_Log;NA" "NA" "NA" "${RackSN}"
	echo "Rack Module Information Test - Generate Whole Log"
    #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
    #cat ./log/Execution_console.log >> ${LOGFILE}
    exeucte_test "/usr/local/bin/rackmoninfo" "${wedge400IP}" | tee ${RackmonLog} 
    logResultCheck "ShowOnly" "NA" "NA" "${RackmonLog}"
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        show_fail_msg "Rack Module Information Test -- Generate Log"
        record_time "HPRv3_WG400_PMM" end "Wedge400_Whole_Log;NA" "NA" "FAIL" "${RackSN}"
        record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
        return 1
    else
        show_pass_msg "Rack Module Information Test -- Generate Log"
        record_time "HPRv3_WG400_PMM" end "Wedge400_Whole_Log;NA" "NA" "PASS" "${RackSN}"
    fi   
}



Normal_HPRv3_PMM_Funtional_test()
{
    HPR_PMM_PSU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PMM_PSU" | grep "Device Address" | awk '{print$NF}'))
    HPR_PMM_BBU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PMM_BBU" | grep "Device Address" | awk '{print$NF}'))
    echo "HPR PSU PMM Address : ${HPR_PMM_PSU_AddressArr[@]}"
    echo "HPR BBU PMM Address : ${HPR_PMM_BBU_AddressArr[@]}"
    	
	declare -a ARTESYN_PSUPMM_Data_Array=("03-100050" "700-043397-0000" "^[0-9]{2}/[0-9]{4}$" "PMM1AEL" "A00" "0006")
	declare -a DELTA_PSUPMM_Data_Array=("03-100037" "ECD90000111" "^[0-9]{2}/[0-9]{4}$" "M2HPDET" "4" "1.1.4.0")
	declare -a DELTA_BBUPMM_Data_Array=("03-100037" "ECD90000111" "^[0-9]{2}/[0-9]{4}$" "M2HPDET" "4" "1.1.4.0")
	declare -a PANA_BBUPMM_Data_Array=("03-100048" "BJ-BPM102A" "^[0-9]{2}/[0-9]{4}$" "M1V4PAM" "M01" "00.01.1F")

	for address in ${HPR_PMM_PSU_AddressArr[@]};do
		record_time "HPRv3_WG400_PMM" start "PSU_PMM_Check;${address}" "${address}" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address}" "${wedge400IP}" | tee ${PSUPMMLog} 
        echo "PSU PMM Address and Modbus Address : ${address} Check Test"	
        logResultCheck "CheckResult" "Device Address;NF" "${address}" "${PSUPMMLog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM" end "PSU_PMM_Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM" end "PSU_PMM_Check;${address}" "${address}" "PASS" "${RackSN}"
        fi

		exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PMM_MFR_Name" "${wedge400IP}" | tee ${PSUPMMLog}  
		PMMVendor=$(cat ${PSUPMMLog} | grep "PMM_MFR_Name<0x0008>" | awk '{print$NF}' | tr -d '"')  
		exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${PSUPMMLog} 
		PMMType=$(cat ${PSUPMMLog} | grep "Device Type:" | awk '{print$NF}')  
		if [ ${PMMType} == "ORV3_HPR_PMM_PSU" ];then     
			if [ ${PMMVendor} == "ARTESYN" ];then         
				declare -a PMM_Array=("${ARTESYN_PSUPMM_Data_Array[@]}")     
			elif [ ${PMMVendor} == "DELTA" ];then         
				declare -a PMM_Array=("${DELTA_PSUPMM_Data_Array[@]}")     
			else         
				echo "Can't get correct PSU PMM vendor, stop the test"         
				return 1     
			fi 
		else     
			echo "The address is not belongs to PSU PMM, stop the test"     
			return 1 
		fi
	
		echo "PMM Module Inforamtion Check for address : ${address}"         
		PMMInfo=("PMM_FBPN" "PMM_MFR_Model" "PMM_MFR_Date" "PMM_MFR_Serial" "PMM_HW_Revision" "PMM_FW_Revision")          
		for i in "${!PMMInfo[@]}"; do             
			exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PMMInfo[$i]}" "${wedge400IP}" | tee ${PSUPMMLog}             
			record_time "HPRv3_WG400_PMM" start "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "NA" "${RackSN}"              
			if [ ${PMMInfo[$i]} == "PMM_MFR_Date" ];then                 
				logResultCheck "CheckEGREPFormat" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"                         
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"                 
				fi             
			elif [ ${PMMInfo[$i]} == "PMM_MFR_Serial" ];then                 
				logResultCheck "CheckEGREPValue" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"                         
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"                 
				fi            
			else                 
				logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${PSUPMMLog}"                 
				if [ ${PIPESTATUS[0]} -ne 0 ];then                         
					show_fail_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"                         
					record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"                         
					return 1                 
				else                         
					show_pass_msg "Rack Module Test -- PSU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"                         
					record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"                 
				fi              
			fi         
		done

				
    
        echo "ISHARE Cable Connection Test on Address : ${address}"
        record_time "HPRv3_WG400_PMM" start "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ISHARE_Cable_Connected" "${wedge400IP}" | tee ${PSUPMMLog}
        if [ ${address} == "0x20" ];then
            logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "0" "${PSUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
		        record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
		        record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
            fi
        else
            logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "1" "${PSUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
		        record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_ISHARE_Check;${address}" "1" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
		        record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_ISHARE_Check;${address}" "1" "PASS" "${RackSN}"
            fi
        fi
	
	    echo "6 PSU PMM Module Present for address : ${address}" 
        PSUPresent=("Module1_Present" "Module2_Present" "Module3_Present" "Module4_Present" "Module5_Present" "Module6_Present")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Present" "${wedge400IP}" | tee ${PSUPMMLog}
        for PSU in "${PSUPresent[@]}"; do
            record_time "HPRv3_WG400_PMM" start "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${PSU}" "1;[1]" "${PSUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- PSU ${PSU} PMM Present Test"
                record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Test -- PSU ${PSU} PMM Present Test"
                record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Present_Check;${PSU}" "[1]" "PASS" "${RackSN}"
            fi
        done

        # 0408 Only for debug
        echo "6 PSU PMM Module Alert for address : ${address}"
        PSUAlert=("Module1_Alert" "Module2_Alert" "Module3_Alert" "Module4_Alert" "Module5_Alert" "Module6_Alert")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Alert" "${wedge400IP}" | tee ${PSUPMMLog}
        for PSU in "${PSUAlert[@]}"; do
           record_time "HPRv3_WG400_PMM" start "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "NA" "${RackSN}"
          logResultCheck "LogCheck" "${PSU}" "1;[0]" "${PSUPMMLog}"
           if [ ${PIPESTATUS[0]} -ne 0 ];then
               show_fail_msg "Rack Module Test -- PSU ${PSU} PMM Alert Test"
               record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "FAIL" "${RackSN}"
               record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
               return 1
           else
               show_pass_msg "Rack Module Test -- PSU ${PSU} PMM Alert Test"
               record_time "HPRv3_WG400_PMM" end "PSU_${address}_PMM_Alert_Check;${PSU}" "[0]" "PASS" "${RackSN}"
           fi
        done
	
	    echo "General_Alarm_Status_Register Test for PSU PMM address : ${address}"
        Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault")
        #Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault" "Module_Alerts")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name General_Alarm_Status_Register" "${wedge400IP}" | tee ${PSUPMMLog}
        for Reg in "${Register[@]}"; do
            record_time "HPRv3_WG400_PMM" start "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "NA" "${RackSN}"
            logResultCheck "LogCheck" "${Reg}" "1;[0]" "${PSUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
                record_time "HPRv3_WG400_PMM" end "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
                record_time "HPRv3_WG400_PMM" end "PSU_PMM_${address}_General_Alarm_Status_Register;${Reg}" "[0]" "PASS" "${RackSN}"
            fi
        done
    done

    for address in ${HPR_PMM_BBU_AddressArr[@]};do

        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address}" "${wedge400IP}" | tee ${BBUPMMLog} 
        echo "BBU PMM Address and Modbus Address : ${address} Check Test"
	    record_time "HPRv3_WG400_PMM" start "BBU_PMM_Check;${address}" "${address}" "NA" "${RackSN}"
        logResultCheck "CheckResult" "Device Address;NF" "${address}" "${BBUPMMLog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
	        show_fail_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
		    record_time "HPRv3_WG400_PMM" end "BBU_PMM_Check;${address}" "${address}" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Information Test -- PMM Address and Modbus Check Test -- Address ${address} "
            record_time "HPRv3_WG400_PMM" end "BBU_PMM_Check;${address}" "${address}" "PASS" "${RackSN}"
        fi
    
	    exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name PMM_MFR_Name" "${wedge400IP}" | tee ${BBUPMMLog}
        PMMVendor=$(cat ${BBUPMMLog} | grep "PMM_MFR_Name<0x0008>" | awk '{print$NF}' | tr -d '"')

        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name \"Device Type\"" "${wedge400IP}" | tee ${BBUPMMLog}
        PMMType=$(cat ${BBUPMMLog} | grep "Device Type:" | awk '{print$NF}')

        if [ ${PMMType} == "ORV3_HPR_PMM_BBU" ];then
            if [ ${PMMVendor} == "Panasonic" ];then
		        declare -a PMM_Array=("${PANA_BBUPMM_Data_Array[@]}")
            elif [ ${PMMVendor} == "DELTA" ];then
                declare -a PMM_Array=("${DELTA_BBUPMM_Data_Array[@]}")
            else
                echo "Can't get correct BBU PMM vendor, stop the test"
                return 1
            fi
        else
            echo "The address is not belongs to BBU PMM, stop the test"
            return 1
        fi

	    echo "PMM Module Inforamtion Check for address : ${address}" 
        PMMInfo=("PMM_FBPN" "PMM_MFR_Model" "PMM_MFR_Date" "PMM_MFR_Serial" "PMM_HW_Revision" "PMM_FW_Revision")

        for i in "${!PMMInfo[@]}"; do
            exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ${PMMInfo[$i]}" "${wedge400IP}" | tee ${BBUPMMLog}
            record_time "HPRv3_WG400_PMM" start "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "NA" "${RackSN}"

            if [ ${PMMInfo[$i]} == "PMM_MFR_Date" ];then
		        logResultCheck "CheckEGREPFormat" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
                fi
            elif [ ${PMMInfo[$i]} == "PMM_MFR_Serial" ];then
                logResultCheck "CheckEGREPValue" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
                fi
	        else
                logResultCheck "LogCheck" "${PMMInfo[$i]}<" "NF;${PMM_Array[$i]}" "${BBUPMMLog}"
                if [ ${PIPESTATUS[0]} -ne 0 ];then
                    show_fail_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "FAIL" "${RackSN}"
                    record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                    return 1
                else
                    show_pass_msg "Rack Module Test -- BBU_${address}_PMM_Information_Check Test -> ${PMMInfo[$i]}"
                    record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Information_Check;${PMMInfo[$i]}" "${PMM_Array[$i]}" "PASS" "${RackSN}"
                fi
            fi
        done

        echo "ISHARE Cable Connection Test on Address : ${address}"
        record_time "HPRv3_WG400_PMM" start "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name ISHARE_Cable_Connected" "${wedge400IP}" | tee ${BBUPMMLog}
        if [ ${address} == "0x10" ];then
            logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "0" "${BBUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
            fi
        else
            logResultCheck "CheckResult" "ISHARE_Cable_Connected<0x0056>;NF" "1" "${BBUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_ISHARE_Check;${address}" "1" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Information Test -- ISHARE Cable Connection -- Address ${address} "
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_ISHARE_Check;${address}" "0" "PASS" "${RackSN}"
            fi
        fi

        echo "6 BBU PMM Module Present for address : ${address}" 
        BBUPresent=("Module1_Present" "Module2_Present" "Module3_Present" "Module4_Present" "Module5_Present" "Module6_Present")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Present" "${wedge400IP}" | tee ${BBUPMMLog}
        for BBU in "${BBUPresent[@]}"; do
            record_time "HPRv3_WG400_PMM" start "BBU_${address}_PMM_Present_Check;${address}" "[1]" "NA" "${RackSN}"	
            logResultCheck "LogCheck" "${BBU}" "1;[1]" "${BBUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- BBU ${BBU} PMM Present Test"
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Present_Check;${address}" "[1]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Test -- BBU ${BBU} PMM Present Test"
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Present_Check;${address}" "[1]" "PASS" "${RackSN}"
            fi
        done

        echo "6 BBU PMM Module Alert for address : ${address}"
        BBUAlert=("Module1_Alert" "Module2_Alert" "Module3_Alert" "Module4_Alert" "Module5_Alert" "Module6_Alert")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name Module_Alert" "${wedge400IP}" | tee ${BBUPMMLog}
       
        for BBU in "${BBUAlert[@]}"; do
            record_time "HPRv3_WG400_PMM" start "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "NA" "${RackSN}"	
            logResultCheck "LogCheck" "${BBU}" "1;[0]" "${BBUPMMLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                show_fail_msg "Rack Module Test -- BBU ${BBU} PMM Alert Test"
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
                return 1
            else
                show_pass_msg "Rack Module Test -- BBU ${BBU} PMM Alert Test"
                record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_Alert_Check;${address}" "[0]" "PASS" "${RackSN}"
            fi
        done

        echo "General_Alarm_Status_Register Test for address : ${address}"
        Register=("Missing_Modules" "Shelf_EEPROM_Fault" "Module_Modbus_Communication_Error" "PMM_Modbus_Communication_Error" "Serial_Link_Fault" "Module_Alerts")
        exeucte_test "/usr/local/bin/rackmoncli data --dev-addr ${address} --reg-name General_Alarm_Status_Register" "${wedge400IP}" | tee ${BBUPMMLog}
        for Reg in "${Register[@]}"; do
        record_time "HPRv3_WG400_PMM" start "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "NA" "${RackSN}"
        logResultCheck "LogCheck" "${Reg}" "1;[0]" "${BBUPMMLog}"
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            show_fail_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
            record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
            return 1
        else
            show_pass_msg "Rack Module Test -- General_Alarm_Status_Register Test -- ${Reg}"
            record_time "HPRv3_WG400_PMM" end "BBU_${address}_PMM_General_Alarm_Status_Register;${Reg}" "[0]" "PASS" "${RackSN}"
            fi
        done
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
LOGFILE=${LOGFOLDER}/log.txt


show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_PMM" initial "" "" "" "$RackSN" 

Normal_HPRv3_GPIO_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
        show_fail | tee -a ${LOGFILE}    
    	finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMFUNC_FAIL_${startTime}.log
        record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
   	record_time "HPRv3_WG400_PMM" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    	cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    	cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    	cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    	exit 1
fi

Normal_Wedge400_Gen_Whole_Log | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}    	
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMFUNC_FAIL_${startTime}.log
    record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
    record_time "HPRv3_WG400_PMM" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

Normal_HPRv3_PMM_Funtional_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}    
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMFUNC_FAIL_${startTime}.log
    record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "FAIL" "${RackSN}"
    record_time "HPRv3_WG400_PMM" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

echo "HPRv3 PMM Functional Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_PMMFUNC_PASS_${startTime}.log
record_time "HPRv3_WG400_PMM" total "HPRv3_WG400_PMM;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_PMM" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

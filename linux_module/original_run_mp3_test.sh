#!/bin/bash
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

#set -x

#switch_index=1

while getopts s:i: OPT; do
    case "${OPT}" in
        "s")
            RackSN=${OPTARG}
           	check_sn ${RackSN}
		    RackIPN=$(cat ${LOGPATH}/${RackSN}/rackipn.txt)
            RackAsset=$(cat ${LOGPATH}/${RackSN}/assetid.txt)
            sw_ip=$(cat ${LOGPATH}/${RackSN}/FSW/${index}/mac_ip.txt)
            sw_sn=$(cat ${LOGPATH}/${RackSN}/FSW/${index}/serialnumber.txt)
            ;;
        "i")
            index=${OPTARG}
            if [ -z "${index}" ];then
                print_help
                return 1
            fi 
	    session="HPRv3_MP3_Standalone_${index}"
        ;;
        *)
            print_help
            exit 1
        ;;
    esac
done

MP3_Function_Diagnostic_test()
{
    res=0
    echo "-------------------"
    
    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "System version Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 System Info Test" 1
    record_time "$session" start "System version Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 System Info Test" 3
        return 1
    fi
    
    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    if [ "${Resultstatus}" == "PASS" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> System version Information Test"
        record_time "$session" end "System version Check;NA" "NA" "PASS" "${RackSN}"
        #update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> System version Information Test"
        record_time "$session" end "System version Check;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        #update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        return 1
    fi
    
    TypeARR=("BIOS" "SDK" "BSP" "OS")
    for checktype in ${TypeARR[@]};
    do
    	currentValue=$(cat ${diagnosticLog} | tr -d ' ' | grep "^${checktype}:" | uniq | awk -F ':' '{print$NF}' | tr -d ' ' | tr -d '\r\n')
    	STDValue=$(cat $CFGPATH/mp3_config | grep "^${checktype}" | awk -F ":" '{print$NF}' | tr -d '\r\n')
    	if [ "${currentValue}" == "${STDValue}" ];then
    	    echo "The System info check -- ${checktype} is pass, continue the test"
    	    show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> System version Information Test : ${checktype}"
    	    record_time "$session" end "System version Check;${checktype}" "${STDValue}" "PASS" "${RackSN}"
    	    update_status "$SN" "$folder" "$index" "$testitem" "MP3 System Info Test" 2
    	else
    	    echo "The System info check -- ${checktype} is fail, stop the test"
    	    show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> System version Information Test : ${checktypee}"
    	    record_time "$session" end "System version Check;${checktype}" "${STDValue}" "FAIL" "${RackSN}"
    	    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    	    update_status "$SN" "$folder" "$index" "$testitem" "MP3 System Info Test" 3
    	    return 1
    	fi
    done

    record_time "$session" start "Sensor Check;NA" "NA" "NA" "${RackSN}"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 1

    echo "Sensor Status Test"
    executeCMDinMP3DiagOS "sensors" "$sw_ip" | tee ${diagnosticLog}
    if [ ${PIPESTATUS[0]} -eq 0 ];then
        echo "The switch already finish the sensor test"
    else
        echo "The switch can't finish the sensor test"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 3
        return 1
    fi

    alarmstatus=$(cat ${diagnosticLog} | grep -i "alarm" | wc -l)
    if [ $alarmstatus -ge 1 ];then
        echo "The system report ALARM sensors"
        cat ${diagnosticLog} | grep -i "alarm"
        echo "Found ALARM sensors, need to check with META"
        show_warn_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sensor Status Test -- ALARM"
        record_time "$session" end "Sensor Check;NA" "NA" "WARNING" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 5
    else
        echo "The switch don't report any ALARM sensors"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sensor Status Test -- ALARM"
        record_time "$session" end "Sensor Check;NA" "NA" "PASS" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 2
    fi

    criticalstatus=$(cat ${diagnosticLog} | grep -i "critical" | wc -l)
    if [ $criticalstatus -ge 1 ];then
        echo "The system report critical sensors"
        cat ${diagnosticLog} | grep -i "critical"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sensor Status Test -- CRITICAL"
        record_time "$session" end "Sensor Check;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 3
        return 1
    else
        echo "The switch don't report any critical sensors"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sensor Status Test -- CRITICAL"
        record_time "$session" end "Sensor Check;NA" "NA" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sensor Test" 2
    fi

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "IOB FPGA version Information Test"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 IOB FPGA Test" 1
    record_time "$session" start "IOB FPGA Check:NA" "v0.51" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "d;b;b" | tee ${diagnosticLog} 
	status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 IOB FPGA Test" 2
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog}| grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep "iob_ver_show" | awk '{print$7}' | tr -d ',' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v0.51" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> IOB FPGA Status Test"
        record_time "$session" end "IOB FPGA Check;NA" "v0.51" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 IOB FPGA Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> IOB FPGA Status Test"
        record_time "$session" end "IOB FPGA Check;NA" "v0.51" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 IOB FPGA Test" 3
        return 1
    fi

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "DOM1 FPGA Information Test"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 DOM1 FPGA Test" 1
    record_time "$session" start "DOM1 FPGA Check;NA" "v0.42" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "d;c;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep dom1_ver_show | awk '{print$7}' | tr -d ',' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v0.42" ];then
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> DOM1 FPGA Status Test"
        echo "The System info check is pass, continue the test"
        record_time "$session" end "DOM1 FPGA Check;NA" "v0.42" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> DOM1 FPGA Status Test"
        record_time "$session" end "DOM1 FPGA Check;NA" "v0.42" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        return 1
    fi

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "DOM2 FPGA Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 DOM2 FPGA Test" 1
    record_time "$session" start "DOM2 FPGA Check;NA" "v0.42" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "d;d;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)    
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 DOM2 FPGA Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep dom2_ver_show | awk '{print$7}' | tr -d ',' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v0.42" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> DOM2 FPGA Status Test"
        record_time "$session" end "DOM2 FPGA Check;NA" "v0.42" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 DOM2 FPGA Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> DOM2 FPGA Status Test"
        record_time "$session" end "DOM2 FPGA Check;NA" "v0.42" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 DOM2 FPGA Test" 3
        return 1
    fi
 
    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "MCB CPLD Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB CPLD Test" 1
    record_time "$session" start "MCB CPLD Check;NA" "v2.5.0" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "e;b;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)    
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB CPLD Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep mcb_ver_show | awk '{print$NF}' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v2.5.0" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> MCB CPLD Status Test"
        record_time "$session" end "MCB CPLD Check;NA" "v2.5.0" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB CPLD Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> MCB CPLD Status Test"
        record_time "$session" end "MCB CPLD Check;NA" "v2.5.0" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB CPLD Test" 3
        return 1
    fi

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "SMB CPLD Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB CPLD Test" 1
    record_time "$session" start "SMB CPLD Check;NA" "v2.5.0" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "e;c;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB CPLD Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep smb_ver_show | awk '{print$NF}' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v2.5.0" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> SMB CPLD Status Test"
        record_time "$session" end "SMB CPLD Check;NA" "v2.5.0" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB CPLD Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> SMB CPLD Status Test"
        record_time "$session" end "SMB CPLD Check;NA" "v2.5.0" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB CPLD Test" 3
        return 1
    fi

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "SCM CPLD Information Test" 
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM CPLD Test" 1
    record_time "$session" start "SCM CPLD Check;NA" "v2.3.0" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "e;d;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)    
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM CPLD Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    version=$(cat ${diagnosticLog}| grep scm_ver_show | awk '{print$NF}' | tr -d '\r')
    if [ ${Resultstatus} == "PASS" ] && [ $version == "v2.3.0" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> SCM CPLD Status Test"
        record_time "$session" end "SCM CPLD Check;NA" "v2.3.0" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM CPLD Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> SCM CPLD Status Test"
        record_time "$session" end "SCM CPLD Check;NA" "v2.3.0" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM CPLD Test" 3
        return 1
    fi

    FRUInfo=("Magic Word" "Format Version" "Product Name" "Product Part Number" "System Assembly Part Number" "Meta PCBA Part Number" "Meta PCB Part Number" "ODM/JDM PCBA Part Number" "ODM/JDM PCBA Serial Number" "Product Production State" "Product Version" "Product Sub-Version" "Product Serial Number" "System Manufacturer" "System Manufacturing Date" "PCB Manufacturer" "Assembled at" "EEPROM location on Fabric" "CRC16") 

    SCMFRUInfo=("Magic Word" "Format Version" "Product Name" "Product Part Number" "System Assembly Part Number" "Meta PCBA Part Number" "Meta PCB Part Number" "ODM/JDM PCBA Part Number" "ODM/JDM PCBA Serial Number" "Product Production State" "Product Version" "Product Sub-Version" "Product Serial Number" "System Manufacturer" "System Manufacturing Date" "PCB Manufacturer" "Assembled at" "EEPROM location on Fabric" "X86 CPU MAC Base" "X86 CPU MAC Address Size" "CRC16") 

    MCBFRU_DATA=("0xFBFB" "0x[5-6]" "MINIPACK3_MCB" "" "" "132100094" "131100034" "R3214G000204" "A[0-9]{12}" "[2-4]" "[2-4]" "0" "" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "ZFP" "CTH" "MCB" "0x[0-9a-z]+")
    #MCBFRU2_DATA=("0xFBFB" "0x5" "MINIPACK3_MCB" "" "" "132100094" "131100034" "R3214G000204" "A[0-9]{12}" "3" "4" "0" "" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "ZFP" "CTH" "MCB" "0x[0-9a-z]")

    SMBFRU_DATA=("0xFBFB" "0x[5-6]" "MINIPACK3_SMB" "20100187" "" "132100093" "131100033" "R3214G000104" "A[0-9]{12}" "[2-3]" "[2-4]" "20" "M[0-9]{12}" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "WUS" "CTH" "SMB" "0x[0-9a-z]+")
    #SMBFRU2_DATA=("0xFBFB" "0x5" "MINIPACK3_SMB" "20100187" "" "132100093" "131100033" "R3214G000104" "A[0-9]{12}" "3" "4" "20" "M[0-9]{12}" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "WUS" "CTH" "SMB" "0x[0-9a-z]")

    SCMFRU_DATA=("0xFBFB" "0x[5-6]" "MINIPACK3_SCM" "20100188" "" "132100049" "131100035" "R3214G000304" "A[0-9]{12}" "[2-4]" "[2-4]" "10" "M[0-9]{12}" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "ZFP" "CTH" "SCM" "[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}" "1" "0x[0-9a-z]+")
    #SCMFRU2_DATA=("0xFBFB" "0x5" "MINIPACK3_SCM" "20100188" "" "132100049" "131100035" "R3214G000304" "A[0-9]{12}" "3" "4" "10" "M[0-9]{12}" "CLS" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "ZFP" "CTH" "SCM" "[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}" "1" "0x[0-9a-z]")

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 1
    echo "MCB FRU Test Information Test"
    #record_time "$session" start "MCB FRU Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;o;b;c" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)    
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 3
        return 1
    fi
    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${MCBFRU_DATA[@]}")
    for i in "${!FRUInfo[@]}"; do
        #echo ${FRUInfo[$i]}
        record_time "$session" start "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
        if [ "${FRUInfo[$i]}" == "ODM/JDM PCBA Serial Number" ]  || [ "${FRUInfo[$i]}" == "System Manufacturing Date" ] || [ "${FRUInfo[$i]}" == "CRC16" ] || [ "${FRUInfo[$i]}" == "Format Version" ] || [ "${FRUInfo[$i]}" == "Product Production State" ] || [ "${FRUInfo[$i]}" == "Product Version" ];then
            logResultCheck "CheckEGREPFormat" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
		echo "Select another FRU data to check again"
		declare -a FRU_FinalArr=("${MCBFRU2_DATA[@]}")
		logResultCheck "CheckEGREPFormat" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then
                	show_fail_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
               		record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
			record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
			echo "Roll back the original Array"
			declare -a FRU_FinalArr=("${MCBFRU_DATA[@]}")
		fi
            else
                show_pass_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 2
            fi
        elif [ "${FRUInfo[$i]}" == "Product Part Number" ] || [ "${FRUInfo[$i]}" == "System Assembly Part Number" ] || [ "${FRUInfo[$i]}" == "Product Serial Number" ] ;then                 
            logResultCheck "ZeroValueCheck" "${FRUInfo[$i]}" "NF;NF" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then                     
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${MCBFRU2_DATA[@]}")
		logResultCheck "ZeroValueCheck" "${FRUInfo[$i]}" "NF;NF" "${diagnosticLog}"    
                if [ ${PIPESTATUS[0]} -ne 0 ];then
			show_fail_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                	record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 3
                	return 1
		else
                        show_pass_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${MCBFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}" 
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 2                
            fi
        else
            logResultCheck "LogCheck" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then   
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${MCBFRU2_DATA[@]}")
		logResultCheck "LogCheck" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then                      
                	show_fail_msg "Rack Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                	record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${MCBFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- MCB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                record_time "$session" end "MCB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"         
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 MCB FRU Test" 2        
            fi
        fi
    done

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "SMB FRU Test Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 1 
    record_time "$session" start "SMB FRU Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;o;b;e" | tee ${diagnosticLog} 

    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 3
        return 1
    fi

    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${SMBFRU_DATA[@]}")
    for i in "${!FRUInfo[@]}"; do
        record_time "$session" start "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
        if [ "${FRUInfo[$i]}" == "ODM/JDM PCBA Serial Number" ] || [ "${FRUInfo[$i]}" == "Product Serial Number" ] || [ "${FRUInfo[$i]}" == "System Manufacturing Date" ] || [ "${FRUInfo[$i]}" == "CRC16" ] || [ "${FRUInfo[$i]}" == "Format Version" ] || [ "${FRUInfo[$i]}" == "Product Production State" ]|| [ "${FRUInfo[$i]}" == "Product Version" ];then
            logResultCheck "CheckEGREPFormat" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SMBFRU2_DATA[@]}")
		logResultCheck "CheckEGREPFormat" "${FRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then
                	show_fail_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                	record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SMBFRU_DATA[@]}")
                fi
            else
                show_pass_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 2
            fi
        elif [ "${FRUInfo[$i]}" == "System Assembly Part Number" ];then                 
            logResultCheck "ZeroValueCheck" "${FRUInfo[$i]}" "NF;NF" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then         
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SMBFRU2_DATA[@]}") 
		logResultCheck "ZeroValueCheck" "${FRUInfo[$i]}" "NF;NF" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then               
                	show_fail_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                	record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SMBFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"   
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 2              
            fi
        else
            logResultCheck "LogCheck" "${FRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then  
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SMBFRU2_DATA[@]}")
		logResultCheck "LogCheck" "${FRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then                       
                	show_fail_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                	record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 3
                	return 1
		else
                        show_pass_msg "MP3 Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SMBFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- SMB_FRU_Information_Check Test -> ${FRUInfo[$i]}"                         
                record_time "$session" end "SMB FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"  
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SMB FRU Test" 2               
            fi
        fi
    done
  
    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "SCM FRU Test Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 1
    record_time "$session" start "SCM FRU Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;o;b;d" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 2
        return 1
    fi

    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${SCMFRU_DATA[@]}")
    for i in "${!SCMFRUInfo[@]}"; do
        record_time "$session" start "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
        if [ "${SCMFRUInfo[$i]}" == "ODM/JDM PCBA Serial Number" ] || [ "${SCMFRUInfo[$i]}" == "Product Serial Number" ] || [ "${SCMFRUInfo[$i]}" == "System Manufacturing Date" ] || [ "${SCMFRUInfo[$i]}" == "X86 CPU MAC Base" ] || [ "${SCMFRUInfo[$i]}" == "X86 CPU MAC Address Size" ] || [ "${SCMFRUInfo[$i]}" == "CRC16" ] || [ "${SCMFRUInfo[$i]}" == "Product Production State" ] || [ "${SCMFRUInfo[$i]}" == "Product Version" ]|| [ "${SCMFRUInfo[$i]}" == "Format Version" ];then
            logResultCheck "CheckEGREPFormat" "${SCMFRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SCMFRU2_DATA[@]}")
		logResultCheck "CheckEGREPFormat" "${SCMFRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then
                	show_fail_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"
                	record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
			update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SCM FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SCMFRU_DATA[@]}")
                fi
            else
                show_pass_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"
                record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 2
            fi
        elif [ "${SCMFRUInfo[$i]}" == "System Assembly Part Number" ];then                  
            logResultCheck "ZeroValueCheck" "${SCMFRUInfo[$i]}" "NF;NF" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then         
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SCMFRU2_DATA[@]}")
		logResultCheck "ZeroValueCheck" "${SCMFRUInfo[$i]}" "NF;NF" "${diagnosticLog}"
            	if [ ${PIPESTATUS[0]} -ne 0 ];then                
                	show_fail_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"                         
                	record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 3
               		return 1
		else
			show_pass_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SCM FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SCMFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"                         
                record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"      
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 2           
            fi
        else
            logResultCheck "LogCheck" "${SCMFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then   
		echo "Select another FRU data to check again"
                declare -a FRU_FinalArr=("${SCMFRU2_DATA[@]}")
		logResultCheck "LogCheck" "${SCMFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"
            	if [ ${PIPESTATUS[0]} -ne 0 ];then                      
                	show_fail_msg "Rack Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"                         
                	record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- SCM_FRU_Information_Check Test -> ${FRUInfo[$i]}"
                        record_time "$session" end "SCM FRU Check;${FRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        echo "Roll back the original Array"
                        declare -a FRU_FinalArr=("${SCMFRU_DATA[@]}")
                fi
            else                         
                show_pass_msg "Rack Module Test -- SCM_FRU_Information_Check Test -> ${SCMFRUInfo[$i]}"                         
                record_time "$session" end "SCM FRU Check;${SCMFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"   
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 SCM FRU Test" 2              
            fi
        fi
    done

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "PSU1 FRU Test Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU1 FRU Test" 1
    record_time "$session" start "PSU1 FRU Check;NA" "Missing" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;o;b;n" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU1 FRU Test" 2
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    if [ ${Resultstatus} == "FAIL" ];then
        echo "The System info check is fail as expect since the PSU1 is missing, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> PSU1 FRU Status Test"
        record_time "$session" end "PSU1 FRU Check;NA" "Missing" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU1 FRU Test" 2
    else
        echo "The System info check is pass, but the PSU1 should be missing. Stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> PSU1 FRU Status Test"
        record_time "$session" end "PSU1 FRU Check;NA" "Missing" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU1 FRU Test" 3
        return 1
    fi

    PSUFRUInfo=("Magic Word" "Format Version" "Product Name" "Product Part Number" "System Assembly Part Number" "Meta PCBA Part Number" "Meta PCB Part Number" "ODM/JDM PCBA Part Number" "ODM/JDM PCBA Serial Number" "Product Production State" "Product Version" "Product Sub-Version" "Product Serial Number" "System Manufacturer" "System Manufacturing Date" "PCB Manufacturer" "Assembled at" "EEPROM location on Fabric" "CRC16") 

    PSUFRU_DATA=("0xFBFB" "0x[5-6]" "DC3K12V_M_L" "00000000" "03001202" "000000000000" "000000000000" "DD-2302-1L" "[0-9]{1}[A-Z]{2}[0-9]+" "[2-3]" "[0-1]" "0" "[0-9]{1}[A-Z]{2}[0-9A-Z]+" "Liteon" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "LaiHe" "Liteon" "PSU" "0x[0-9a-z]+")
    #PSUFRU2_DATA=("0xFBFB" "0x5" "DC3K12V_M_L" "00000000" "03001202" "000000000000" "000000000000" "DD-2302-1L" "[0-9]{1}[A-Z]{2}[0-9A-Z]{10}" "3" "0" "0" "[0-9]{1}[A-Z]{2}[0-9A-Z]{10}" "Liteon" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "LaiHe" "Liteon" "PSU" "0x[0-9a-z]{3}")
    PSUFRU2_DATA=("0xFBFB" "0x5" "DC3K12V_M_L" "00000000" "03001202" "000000000000" "000000000000" "DD-2302-1L" "[0-9]{1}[A-Z]{2}[0-9A-Z]{10}" "2" "0" "0" "[0-9]{1}[A-Z]{2}[0-9A-Z]{10}" "Liteon" "202[4-5](0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])" "LaiHe" "Liteon" "PSU" "0x[0-9a-z]{3}")

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "PSU2 FRU Test Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 1
    record_time "$session" start "PSU2 FRU Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;o;b;o" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 3
        return 1
    fi

    FRU_FinalArr=()
    declare -a FRU_FinalArr=("${PSUFRU_DATA[@]}")
    for i in "${!PSUFRUInfo[@]}"; do
        record_time "$session" start "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
        if [ "${PSUFRUInfo[$i]}" == "ODM/JDM PCBA Serial Number" ] || [ "${PSUFRUInfo[$i]}" == "Product Serial Number" ] || [ "${PSUFRUInfo[$i]}" == "System Manufacturing Date" ] || [ "${PSUFRUInfo[$i]}" == "CRC16" ] || [ "${PSUFRUInfo[$i]}" == "Format Version" ] || [ "${PSUFRUInfo[$i]}" == "Product Production State" ] || [ "${PSUFRUInfo[$i]}" == "Product Version" ];then
            logResultCheck "CheckEGREPFormat" "${PSUFRUInfo[$i]}" "NF;${FRU_FinalArr[$i]}" "${diagnosticLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
                echo "Change to another PSU2 FRU"
		declare -a FRU_FinalArr=("${PSUFRU2_DATA[@]}")
		record_time "$session" start "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "NA" "${RackSN}"
		if [ ${PIPESTATUS[0]} -ne 0 ];then
			show_fail_msg "MP3 Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"
                	record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"
               		record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"
                	record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 2
			echo "Roll back to original FRU"
			declare -a FRU_FinalArr=("${PSUFRU_DATA[@]}")
		fi
            else
                show_pass_msg "MP3 Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"
                record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 2
            fi
        else
            logResultCheck "LogCheck" "${PSUFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"                 
            if [ ${PIPESTATUS[0]} -ne 0 ];then   
		echo "Change to another PSU2 FRU"
                declare -a FRU_FinalArr=("${PSUFRU2_DATA[@]}")
		logResultCheck "LogCheck" "${PSUFRUInfo[$i]}" "NF;"${FRU_FinalArr[$i]}"" "${diagnosticLog}"
	        if [ ${PIPESTATUS[0]} -ne 0 ];then              
                	show_fail_msg "Rack Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"                         
                	record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "FAIL" "${RackSN}"                         
                	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                	update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 3
                	return 1
		else
			show_pass_msg "MP3 Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"
                        record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"
                        update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRU Test" 2
                        echo "Roll back to original FRU"
                        declare -a FRU_FinalArr=("${PSUFRU_DATA[@]}")
		fi
            else                         
                show_pass_msg "Rack Module Test -- PSU2_FRU_Information_Check Test -> ${PSUFRUInfo[$i]}"                         
                record_time "$session" end "PSU2_FRU_Information_Check;${PSUFRUInfo[$i]}" "${FRU_FinalArr[$i]}" "PASS" "${RackSN}"     
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 PSU2 FRUTest" 2            
            fi
        fi
    done

    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    echo "Sanity Test Information Test"
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sanity Test" 1
    record_time "$session" start "Sanity Check;NA" "PASS" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "h" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sanity Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    if [ ${Resultstatus} == "FAIL" ];then
        echo "The System info check is fail, but some items still under dicsussion. Continue the test"
        record_time "$session" end "Sanity Check;NA" "PASS" "WARNING" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sanity Test" 5
    elif [ ${Resultstatus} == "PASS" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sanity Status Test"
        record_time "$session" end "Sanity Check;NA" "PASS" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sanity Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> Sanity Status Test"
        record_time "$session" end "Sanity Check;NA" "PASS" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Sanity Test" 3
        return 1
    fi

    echo "FAN Test Information Test"
	update_status "$SN" "$folder" "$index" "$testitem" "MP3 FAN Speed Test" 1
    FanSensorInfo=("PSU2_FAN_F_RPM" "PSU2_FAN_R_RPM" "FAN_1_F_RPM" "FAN_1_R_RPM" "FAN_2_F_RPM" "FAN_2_R_RPM" "FAN_3_F_RPM" "FAN_3_R_RPM" "FAN_4_F_RPM" "FAN_4_R_RPM" "FAN_5_F_RPM" "FAN_5_R_RPM" "FAN_6_F_RPM" "FAN_6_R_RPM" "FAN_7_F_RPM" "FAN_7_R_RPM" "FAN_8_F_RPM" "FAN_8_R_RPM")
    for FAN in "${FanSensorInfo[@]}"; do
        record_time "$session" start "FAN Status Check;${FAN}" "1000" "NA" "${RackSN}" 
        RPMStatus=$(cat ${diagnosticLog} | grep "${FAN}" | awk -F ':' '{print$2}' | tr -d "RPM" | tr -d ' ' | tr -d '\r')
        if [ ${RPMStatus} != "" ];then
            if [ ${RPMStatus} -gt 1000 ];then
                echo "The FAN ${FAN} check is non-zero and the RPM ${RPMStatus} larger than minimum RPM 1000, continue the rest sensors"
                show_pass_msg "Rack Module Test -- MP3_Standalone_Check Test -> FAN Status Test"
                record_time "$session" end "FAN Status Check;${FAN}" "1000" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 Fan Speed Test" 2
            else
                echo "The FAN ${FAN} RPM ${RPMStatus} less than RPM 1000, stop the test"
                show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> FAN Status Test"
                record_time "$session" end "FAN Status Check;${FAN}" "1000" "FAIL" "${RackSN}"
                record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "MP3 Fan Speed Test" 3
                return 1
            fi
        else
            echo "The FAN ${FAN} RPM ${RPMStatus} is empty or zero, stop the test"
            show_fail_msg "Rack Module Test -- MP3_Standalone_Check Test -> FAN Status Test"
            record_time "$session" end "FAN Status Check;${FAN}" "1000" "FAIL" "${RackSN}"
            record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "MP3 Fan Speed Test" 3
            return 1
        fi
    done
}


base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/FSW/${index}/diagnosticlog_mp3.txt
LOGFILE=${LOGFOLDER}/FSW/${index}/log.txt
folder=FSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "$session" initial "" "" "" "$RackSN"  
ssh-keygen -R "$sw_ip" > /dev/null
MP3_Function_Diagnostic_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
   show_fail_msg "MP3 Standalone Function Test Fail"  | tee -a ${LOGFILE}
   finalLog=${RackIPN}_${RackSN}_${RackAsset}_MP3_${index}_${sw_sn}_Function_FAIL_${startTime}.log
   cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
   cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
   exit 1
fi

echo "MP3 Standalone Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_MP3_${index}_${sw_sn}_Function_PASS_$startTime.log
cat $LOGFILE > $LOGPATH/${RackSN}/FSW/$index/${finalLog}
cp $LOGPATH/$RackSN/FSW/$index/$finalLog /log/hprv3 > /dev/null

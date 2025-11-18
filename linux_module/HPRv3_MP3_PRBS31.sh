#!/bin/bash
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

#set -x

#index=1

while getopts s:i: OPT; do
    case "${OPT}" in
        "s")
            RackSN=${OPTARG}
           	check_sn ${RackSN}
		    RackIPN=$(cat ${LOGPATH}/${RackSN}/rackipn.txt)
            RackAsset=$(cat ${LOGPATH}/${RackSN}/assetid.txt)
            sw_ip=$(cat ${LOGPATH}/${RackSN}/FSW/${index}/mac_ip.txt)
            ;;
        "i")
            index=${OPTARG}
            if [ -z "${index}" ];then
                print_help
                return 1
            fi
	        session="HPRv3_MP3_PRBS31_${index}" 
        ;;
        *)
            print_help
            return 1
        ;;
    esac
done

MP3_Init_test()
{
    res=0
    echo "-------------------"
    echo "Check already exit BCM mode"
    executeCMDinMP3DiagOS "exit" "$sw_ip" 

    echo "Enable OSFP PORT Test"
    record_time "$session" start "OSFP/QSFP PORTS Enable;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;m;c;l;e" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "enable_all_ports" | awk -F ':' '{print$NF}' | tr -d '\r\n' | tr -d ' ' | tr -d "\'")
    if [ "${Resultstatus}" == "Allportsresetsignalsarereleased." ];then
        echo "The Enable OSFP PORT is pass, continue the test"
        show_pass_msg "Rack Module Test -- $session Test -> Enable OSFP PORT Test"
        record_time "$session" end "OSFP/QSFP PORTS Enable;NA" "NA" "PASS" "${RackSN}"
    else
        echo "The Enable OSFP PORT is fail, stop the test"
        show_fail_msg "Rack Module Test -- $session Test -> Enable OSFP PORT Test"
        record_time "$session" end "OSFP/QSFP PORTS Enable;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        return 1
    fi

    #sleep 5
    echo "Enable OSFP PORT HPMODE Test"
    record_time "$session" start "Enable OSFP PORT HPMODE Check;NA" "NA" "NA" "${RackSN}"
    #executeCMDinDiagOS "unidiag" "$sw_ip" "b;m;l" | tee ${diagnosticLog} 
    #status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    #if [ $status -eq 1 ];then
    #    echo "The switch already finish the test program"
    #else
    #    echo "The switch can't finish the test program"
    #    return 1
    #fi

    Resultstatus=$(cat ${diagnosticLog} | grep "set_all_port_high_lpmode_status" | awk -F ':' '{print$NF}' | tr -d '\r\n' | tr -d ' ')
    if [ "${Resultstatus}" == "AllportshavecancelledLPmode." ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test -- $session Test -> Enable OSFP PORT HPMODE Test"
        record_time "$session" end "Enable OSFP PORT HPMODE;NA" "NA" "PASS" "${RackSN}"
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test -- $session Test -> Enable OSFP PORT HPMODE Test"
        record_time "$session" end "Enable OSFP PORT HPMODE;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        return 1
    fi

    #sleep 5
    #echo "Check OSFP PORT Status Test"
    #record_time "$session" start "Check OSFP PORT Status Check;NA" "NA" "NA" "${RackSN}"
    #executeCMDinDiagOS "unidiag" "$sw_ip" "b;m;e" | tee ${diagnosticLog} 
    #status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    #if [ $status -eq 1 ];then
    #    echo "The switch already finish the test program"
    #else
    #    echo "The switch can't finish the test program"
    #    return 1
    #fi

    #Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    #if [ "${Resultstatus}" == "PASS" ];then
    #    echo "Check OSFP PORT Status is pass, continue the test"
    #    show_pass_msg "Rack Module Test -- $session Test -> Check OSFP PORT Status Test"
    #    record_time "$session" end "Check OSFP PORT Status;NA" "NA" "PASS" "${RackSN}"
    #else
    #    echo "Check OSFP PORT Status is fail, stop the test"
    #    show_fail_msg "Rack Module Test -- $session Test -> Check OSFP PORT Status Test"
    #    record_time "$session" end "Check OSFP PORT Status;NA" "NA" "FAIL" "${RackSN}"
    #    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    #    return 1
    #fi

    #sleep 5
    #echo "Enable BCM mode with HPR config"
    #record_time "$session" start "Enable BCM mode with HPR config;NA" "NA" "NA" "${RackSN}"
    #executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "${sw_ip}" | tee ${diagnosticLog}
    #Resultstatus=$(cat ${diagnosticLog} | grep "SDK init done" | wc -l)
    #if [ "${Resultstatus}" -eq 1 ];then
    #    echo "Enable BCM mode with HPR config is pass, continue the test"
    #    show_pass_msg "Rack Module Test -- $session Test -> Enable BCM mode with HPR config Test"
    #    record_time "$session" end "Enable BCM mode with HPR config;NA" "NA" "PASS" "${RackSN}"
    #else
    #    echo "Enable BCM mode with HPR config is fail, stop the test"
    #    show_fail_msg "Rack Module Test -- $session Test -> Enable BCM mode with HPR config Test"
    #    record_time "$session" end "Enable BCM mode with HPR config;NA" "NA" "FAIL" "${RackSN}"
    #    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    #    return 1
    #fi
}

check_port_initial()
{
	record_time "$session" start "Check Init Port Status;NA" "NA" "NA" "${RackSN}"
    PortResultLog=${LOGFOLDER}/FSW/$index/PRBS31_portResult.log 
    executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "$sw_ip" "portdump status all;exit" | tee ${PortResultLog}
    #executeCMDinDiagBMCOS "portdump status all" "${sw_ip}"  | tee ${PortResultLog}
    TotalPortNum=$1
    res=0
    for ((port=0;port < ${TotalPortNum}; port++))
    do
   	 
        PortResult=$(cat ${PortResultLog} | grep "cd${port} " | awk '{print$NF}' | tr -d '\r\n')
        if [ "${PortResult}" == "passed" ];then
	        #echo "${PortIndex} ports already setup" 
		    let DisPort=${port}+1
	        show_pass_msg "Port ${DisPort} port Initial pass, continue to other ports" 
        else
	        show_fail_msg "Port ${DisPort} port Initial fail, continue to other ports"
            let res+=1  
        fi
    done
    
    if [ $res -eq 0 ];then
        echo "All ${TotalPortNum} are already inited, continue the test"
	    record_time "$session" end "Check Init Port Status;NA" "NA" "PASS" "${RackSN}"
    else
        echo "Some ports are not inited correctly, shown as below"
        cat ${PortResultLog} | grep 400G | grep failed 
	    record_time "$session" end "Check Init Port Status;NA" "NA" "FAIL" "${RackSN}"
        return 1
    fi   
}   

MP3_Function_PRBS31_test()
{
	record_time "$session" start "PRBS31 Test;NA" "NA" "NA" "${RackSN}"

    res=0
    echo "-------------------"
    echo "PRBS31 Test"
    record_time "$session" start "System version Check;NA" "NA" "NA" "${RackSN}"
    PRBS31ResultLog=${LOGFOLDER}/FSW/$index/PRBS31ResultLog.log
    #executeCMDinDiagBMCOS "bertest;exit" "${sw_ip}" | tee ${PRBS31ResultLog}
    executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "$sw_ip" "bertest;exit" | tee ${PRBS31ResultLog}
    ./prbs31_log_parser.sh -s DVT -p 24 -f ${PRBS31ResultLog}
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        show_fail_msg "PRBS31 Test on FSW-${index}"
	    record_time "$session" end "PRBS31 Test;NA" "NA" "FAIL" "${RackSN}"
        return 1
    else
        show_pass_msg "PRBS31 Test on FSW-${index}"
	    record_time "$session" end "PRBS31 Test;NA" "NA" "PASS" "${RackSN}"
        return 0
    fi
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
ssh-keygen -R "${sw_ip}" > /dev/null
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 1
MP3_Init_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
   show_fail_msg "HPRv3 PRBS31 Init Function Test Fail"  | tee -a ${LOGFILE}
   finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_PRBS31_FAIL_${startTime}.log
   cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
   cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
   update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 3
   exit 1
else
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 2
fi
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 1
check_port_initial "48" | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
   show_fail_msg "HPRv3 PRBS31 Check Port Test Fail"  | tee -a ${LOGFILE}
   finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_PRBS31_FAIL_${startTime}.log
   cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
   cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
   update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 3
   exit 1
else
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 2
fi
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 PRBS31 Test" 1
MP3_Function_PRBS31_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
   show_fail_msg "HPRv3 PRBS31 Function Test Fail"  | tee -a ${LOGFILE}
   finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_PRBS31_FAIL_${startTime}.log
   cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
   cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
   update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 PRBS31 Test" 3
   exit 1
else

update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 PRBS31 Test" 2
fi
echo "HPRv3 MP3 PRBS31 Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_PRBS31_PASS_${startTime}.log
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/${index}/${finalLog}
cp ${LOGPATH}/${RackSN}/FSW/${index}/${finalLog} /log/hprv3

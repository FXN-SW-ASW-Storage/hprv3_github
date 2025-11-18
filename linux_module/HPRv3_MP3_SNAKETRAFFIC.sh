#!/bin/bash
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

#set -x

#switch_index=1
HPRPort=48

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
	    session="HPRv3_MP3_SNAKETRAFFIC_${index}" 
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
}

check_port_initial()
{
    record_time "$session" start "Check PORTS Init;All" "passed" "NA" "${RackSN}"
	PortResultLog=${LOGFOLDER}/FSW/$index/SNAKETEST_portResult.log
    executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "$sw_ip" "portdump status all;exit" | tee ${PortResultLog}
    #executeCMDinDiagBMCOS "portdump status all" "${sw_ip}"  | tee ${PortResultLog}
    TotalPortNum=$1
    res=0
    for ((port=0;port < ${TotalPortNum}; port++))
    do
	record_time "$session" start "Check PORTS Init;${port}" "passed" "NA" "${RackSN}"
        PortResult=$(cat ${PortResultLog} | grep "cd${port} " | awk '{print$NF}' | tr -d '\r\n')
        if [ "${PortResult}" == "passed" ];then
                #echo "${PortIndex} ports already setup" 
                let DisPort=port+1
                show_pass_msg "Port ${DisPort} port Initial pass, continue to other ports"
		record_time "$session" end "Check PORTS Init;${port}" "passed" "PASS" "${RackSN}"
        else
                show_fail_msg "Port ${DisPort} port Initial fail, continue to other ports"
		record_time "$session" end "Check PORTS Init;${port}" "passed" "FAIL" "${RackSN}"
            let res+=1
        fi
    done

    if [ $res -eq 0 ];then
        echo "All ${TotalPortNum} are already inited, continue the test"
	record_time "$session" end "Check PORTS Init;All" "passed" "PASS" "${RackSN}"
    else
        echo "Some ports are not inited correctly, shown as below"
        cat ${PortResultLog} | grep 400G | grep failed
	record_time "$session" end "Check PORTS Init;All" "passed" "FAIL" "${RackSN}"
	record_time "$session" total "$session;All" "NA" "FAIL" "${RackSN}"
	return 1
    fi
}

MP3_Function_Snake_Traffic_test()
{
    res=0
    echo "-------------------"
    echo "Snake Traffic Test"

    SnakeTrafficResultLog=${LOGFOLDER}/FSW/$index/SnakeTrafficResultLog.log
    executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "$sw_ip" "traffictest 1-48 600;sleep 30;portdump counters 1-48;exit" "${sw_ip}" | tee ${SnakeTrafficResultLog}
    flg=0
    echo "Output the total status before checking"
    cat ${SnakeTrafficResultLog}

    #for ((port=0;port < ${TotalPortNum}; port++))
    for ((port=1;port <= ${HPRPort}; port++))
    do
        echo "Current is checking the port : ${port}"


	record_time "$session" start "Snake Traffic Test;${port}" "passed" "NA" "${RackSN}"


	if [ $(cat ${SnakeTrafficResultLog} | grep "^Port${port} " | grep "bcm0_0:" | wc -l) -eq 1 ];then
		portStatus=$(cat ${SnakeTrafficResultLog} | grep -A 1 "^Port${port} " | sed -n 2p | awk '{print$NF}' | tr -d '\r\n')
        	if [ ${portStatus} == "passed" ];then
            		echo "The port $port result : ${portStatus} is passed, continue to check other port"
            		show_pass_msg "Port ${port} snake traffic test"
			record_time "$session" end "Snake Traffic Test;${port}" "passed" "PASS" "${RackSN}"
        	else
            		echo "The port $port result : ${portStatus} is failed, continue to check other port"
            		show_fail_msg "Port ${port} snake traffic test"
			record_time "$session" end "Snake Traffic Test;${port}" "passed" "FAIL" "${RackSN}"
            		let flg+=1
        	fi	
	else

        	portStatus=$(cat ${SnakeTrafficResultLog} | grep "^Port${port} " | awk '{print$NF}' | tr -d '\r\n')
        	if [ ${portStatus} == "passed" ];then
            		echo "The port $port result : ${portStatus} is passed, continue to check other port"
            		show_pass_msg "Port ${port} snake traffic test"
			record_time "$session" end "Snake Traffic Test;${port}" "passed" "PASS" "${RackSN}"
			
        	else
            		echo "The port $port result : ${portStatus} is failed, continue to check other port"
            		show_fail_msg "Port ${port} snake traffic test"
			
			record_time "$session" end "Snake Traffic Test;${port}" "passed" "FAIL" "${RackSN}"


            		let flg+=1
        	fi
	fi
    done

    if [ ${flg} -eq 0 ];then
        echo "Already check every port and result is pass"

	record_time "$session" end "Snake Traffic Test;All" "passed" "PASS" "${RackSN}"

    else
        echo "Some ports are failed, stop the test"

	record_time "$session" end "Snake Traffic Test;All" "passed" "FAIL" "${RackSN}"
		
	record_time "$session" total "$session;All" "NA" "FAIL" "${RackSN}"	
        return 1
    fi
}


base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/FSW/$index/snakeTraffic_mp3.txt
LOGFILE=${LOGFOLDER}/FSW/$index/snaketrafficlog.txt
folder=FSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "$session" initial "" "" "" "$RackSN"  
ssh-keygen -R "${sw_ip}" > /dev/null

update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 1

MP3_Init_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 Snake Traffic Init Function Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 3
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_SNAKETRAFFIC_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    exit 1
else
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 2
fi	
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 1
check_port_initial "$HPRPort" | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 Snake Traffic Check Port Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 3
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_SNAKETRAFFIC_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    exit 1
else
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 2
fi
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 SnakeTraffic Test" 1
MP3_Function_Snake_Traffic_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 Snake Traffic Function Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 SnakeTraffic Test" 3
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_SNAKETRAFFIC_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    exit 1
else
update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 SnakeTraffic Test" 2
fi
echo "HPRv3 MP3 Snake Traffic Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_SNAKETRAFFIC_PASS_${startTime}.log
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null

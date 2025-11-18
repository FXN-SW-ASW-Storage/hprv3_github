#!/bin/bash
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

#set -x

#switch_index=1
#HPRPort=48
portNum=128
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
            session="HPRv3_MP3_INSERTIONLOSS_${index}"
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

    echo "Check MP3 DiagOS Eth0 IP"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;i;b" | tee ${diagnosticLog}
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        #update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        exit 1
    fi

    OSMac=$(cat ${diagnosticLog} | grep NIC | awk '{print$NF}' | tr -d '\r\n')
    OSIP=$(cat /var/lib/dhcpd/dhcpd.leases | grep -i -B 8 ${OSMac} | grep lease | awk '{print$2}' | tail -1)
    ping_test ${OSIP} > ${LOGFOLDER}/FSW/$index/ping_test.txt
    if [ "$?" -ne "0" ];then
        #show_fail_msg "Ping ${test_ip}"
        #cat ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt
        mv -f ${LOGFOLDER}/FSW/$index/ping_test.txt ${LOGFOLDER}/FSW/$index/ping_test_fail.txt
        continue
    else
        #show_pass_msg "Ping ${test_ip}"
        mv -f ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt ${LOGFOLDER}/FSW/$index/ping_test_pass.txt
        echo ${OSIP} > ${LOGFOLDER}/FSW/$index/mp3_os_ip.txt
        echo "FSW-${index} OS IP : ${OSIP}"
    fi

    echo "Send the OSFP file into MP3 switch"
    echo "Command : sshpass -p "0penBmc" scp -r $TOOL/INSERTION_LOSS ${OSIP}:/tmp"
    sshpass -p "0penBmc" sshpass -p "0penBmc" scp -r $TOOL/INSERTION_LOSS ${OSIP}:/tmp
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        echo "Can't send the Insertion Loss package into MP3"
        show_fail_msg "Rack Module Information Test -- SCP Insertion Loss Package"
        record_time "$session" end "Send Insertion Loss Package;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        #update_status "$SN" "$folder" "$index" "$testitem" "BBU Update" 3
        exit 1
    else
        show_pass_msg "Rack Module Information Test -- SCP Insertion Loss Package"
    fi


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
        record_time "$session" start "Check Init Port Status;NA" "NA" "NA" "${RackSN}"
        PortResultLog=${LOGFOLDER}/FSW/$index/INSERTIONLOSS_portResult.log
        executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./bcm.user -y Minipack3_128x400_DVT.config.yml" "$sw_ip" "portdump status all;exit" | tee ${PortResultLog}
    #executeCMDinDiagBMCOS "portdump status all" "${sw_ip}"  | tee ${PortResultLog}
    TotalPortNum=$1
    res=0
    for ((port=0;port < ${TotalPortNum}; port++))
    do
        if [ $port -lt 100 ];then
                PortResult=$(cat ${PortResultLog} | grep "cd${port} " | awk '{print$NF}' | tr -d '\r\n')
        else
        #       
                PortResult=$(cat ${PortResultLog} | grep "cd${port}" | awk '{print$NF}' | tr -d '\r\n')
        fi
        if [ $port -lt 64 ];then
                if [[ $(($port % 8)) -eq 6 ]] || [[ $(($port % 8)) -eq 7 ]]; then
                        echo "The $port should not insert the cable"
                        if [ "${PortResult}" == "failed" ];then
                #echo "${PortIndex} ports already setup" 
                                let DisPort=${port}+1
                                show_pass_msg "Port ${DisPort} port Initial pass, continue to other ports"
                        else
                                show_fail_msg "Port ${DisPort} port Initial fail, continue to other ports"
                                let res+=1
                        fi
                else
                        echo "The $port should insert the cable"
                        if [ "${PortResult}" == "passed" ];then
                #echo "${PortIndex} ports already setup" 
                                let DisPort=${port}+1
                                show_pass_msg "Port ${DisPort} port Initial pass, continue to other ports"
                        else
                                show_fail_msg "Port ${DisPort} port Initial fail, continue to other ports"
                                let res+=1
                        fi
                fi
        else
                echo "The $port should not insert the cable"
                if [ "${PortResult}" == "failed" ];then
                #echo "${PortIndex} ports already setup" 
                        let DisPort=${port}+1
                        show_pass_msg "Port ${DisPort} port Initial pass, continue to other ports"
                else
                        show_fail_msg "Port ${DisPort} port Initial fail, continue to other ports"
                        let res+=1
                fi
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

MP3_Function_Insertion_Loss_test()
{
    res=0
    echo "-------------------"
    echo "Insertion Loss Test"
    totalILLog=${LOGFOLDER}/FSW/$index/ILTotalLog.log
    rm -rf $totalILLog > /dev/null
    executeCMDinDiagOS "cd /tmp/INSERTION_LOSS;python osfp.py set enable;python osfp.py test scan;exit" "$sw_ip"
    executeCMDinMP3DiagOS "exit" "$sw_ip"
    for port  in {1..3} {5..7} {9..11} {13..15} {17..19} {21..23} {25..27} {29..31}
    do
        ILResultLog=${LOGFOLDER}/FSW/$index/ILResultLog_${port}.log
        executeCMDinDiagOS "cd /tmp/INSERTION_LOSS;python osfp.py cmis power ${port} > /tmp/insert_loss.txt" "$sw_ip"
        executeCMDinMP3DiagOS "exit" "$sw_ip"
        flg=0
        echo "Output the total status before checking" 
        echo "Port${port}:" | tee ${ILResultLog}
        executeCMDinDiagOS "cat /tmp/insert_loss.txt" "$sw_ip" | tee -a ${ILResultLog}
        cat ${ILResultLog} >> ${totalILLog}
    done
 

    	RXLog=${LOGFOLDER}/${folder}/${index}/${RackSN}_MP3-${index}_IL_RX_dBm_log.txt
    	echo "Rack SN : ${SN}" > ${RXLog}
    	echo "Switch SKU : MINIPACK3" >> ${RXLog}
    	echo "Date Time : $(date "+%F_%T" | sed -e "s\:\-\g")"  >> ${RXLog}
    	parser_log=${LOGFOLDER}/${folder}/${index}/insertion_loss_parser_result.log
    	./mp3_IL_log_parser.sh -f ${totalILLog} -i ${index} -r ${RXLog} | tee ${parser_log}
    	res=${PIPESTATUS[0]}
    	cat ${parser_log} | grep -i "type 1"
    	#cat ${parser_log} | grep -i "type 2"
    	cat ${parser_log} | grep -i "type 3"
    	return ${res}      
}


print_help(){

    cat <<EOF
    Usage: ./$(basename $0) -s RACK_SN -i Switch_Index [ -l ]
        s : Rack serial Number.
        i : Switch location ID.Should be 1 to 8.
        [Option]
        l : Create individual test log name with date time.
    Example: ./$(basename $0) -s GD123456789 -i 1 -l
EOF
}

disable_log=0
create_log=0
while getopts s:i:p:lg OPT; do
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
        "l")
            create_log=1
            ;;
        *)
            echo "Wrong Parameter..."
            print_help
            exit 1
            ;;
    esac
done

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/FSW/$index/insertionloss_mp3.txt
LOGFILE=${LOGFOLDER}/FSW/$index/insertionlosslog.txt
folder=FSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "$session" initial "" "" "" "$RackSN"
ssh-keygen -R "${sw_ip}" > /dev/null

update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 1

MP3_Init_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 Insertion Loss Init Function Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 3
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_INSERTIONLOSS_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    exit 1
else
	update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Init Test" 2
fi

update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 1
check_port_initial "$portNum" | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_fail_msg "HPRv3 Insertion Loss Check Port Test Fail"  | tee -a ${LOGFILE}
    	record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
   	record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    	update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 3
    	show_fail | tee -a ${LOGFILE}
    	finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_INSERTIONLOSS_FAIL_${startTime}.log
    	cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    	cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    	exit 1
else
	update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Check Port" 2
fi


update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 Insertion Loss Test" 1
MP3_Function_Insertion_Loss_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 Insertion Loss Function Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 InsertionLoss Test" 3
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_INSERTIONLOSS_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
    cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null
    exit 1
else
	update_status "$RackSN" "$folder" "$index" "$testitem" "MP3 InsertinoLoss Test" 2
fi
echo "HPRv3 MP3 Insertion Loss Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_INSERTIONLOSS_PASS_${startTime}.log
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/$index/${finalLog}
cp ${LOGPATH}/${RackSN}/FSW/$index/${finalLog} /log/hprv3 > /dev/null

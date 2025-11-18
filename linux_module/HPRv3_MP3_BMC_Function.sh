#!/bin/bash
. ../commandTool.sh
. ../record_time

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
	    session="HPRv3_MP3_BMC_${index}"
        ;;
        *)
            print_help
            return 1
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
    update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 1
    record_time "$session" start "System version Check;NA" "NA" "NA" "${RackSN}"
    executeCMDinDiagOS "unidiag" "$sw_ip" "b;b" | tee ${diagnosticLog} 
    status=$(cat ${diagnosticLog} | grep "total cost" | wc -l)
    if [ $status -eq 1 ];then
        echo "The switch already finish the test program"
    else
        echo "The switch can't finish the test program"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        return 1
    fi

    Resultstatus=$(cat ${diagnosticLog} | grep "total_funcs" | awk '{print$NF}' | tr -d '\r\n' | tr -d '[' | tr -d ']')
    BMCVer=$(cat ${diagnosticLog} | grep -A 5 show_version | grep BMC | awk -F ':' '{print$NF}' | tr -d ' '| tr -d '\r\n')
    if [ "${Resultstatus}" == "PASS" ] && [ ${BMCVer} == "montblanc-v3.01(master)" ];then
        echo "The System info check is pass, continue the test"
        show_pass_msg "Rack Module Test --> BMC version Information Test"
        record_time "$session" end "System version Check;NA" "NA" "PASS" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 2
    else
        echo "The System info check is fail, stop the test"
        show_fail_msg "Rack Module Test --> BMC version Information Test"
        record_time "$session" end "System version Check;NA" "NA" "FAIL" "${RackSN}"
        record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "MP3 Test" 3
        return 1
    fi

}


base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/FSW/${index}/diagnosticlog_mp3.txt
LOGFILE=${LOGFOLDER}/FSW/${Index}/log.txt

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "$session" initial "" "" "" "$RackSN"  
ssh-keygen -R "$sw_ip" > /dev/null
MP3_Function_Diagnostic_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
   show_fail_msg "MP3 Standalone Function Test Fail"  | tee -a ${LOGFILE}
   finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_BMC_FAIL_${startTime}.log
   cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
   cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
   exit 1
fi

echo "MP3 Standalone Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${index}_${sw_sn}_BMC_PASS_$startTime.log
cat $LOGFILE > $LOGPATH/${RackSN}/FSW/$index/${finalLog}
cp $LOGPATH/$RackSN/FSW/$index/$finalLog /log/hprv3 > /dev/null

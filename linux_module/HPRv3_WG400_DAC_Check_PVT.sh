#!/bin/bash
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
            sw_ip=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/mac_ip.txt)
            sw_sn=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/serialnumber.txt)
            ;;
        "i")
            index=${OPTARG}
            if [ -z "${index}" ];then
                print_help
                return 1
            fi
	        session="HPRv3_WG400_DAC_CHECK_${index}" 
        ;;
        *)
            print_help
            return 1
        ;;
    esac
done

check_DAC_status()
{
	PortResultLog=${LOGFOLDER}/RUSW/$switch_index/DAC_Check_portResult.log
    executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./auto_load_user.sh" "$sw_ip" "ps;exit" | tee ${PortResultLog}
    #executeCMDinDiagBMCOS "portdump status all" "${sw_ip}"  | tee ${PortResultLog}
    TotalPortNum=$1
    res=0
    for port in {37,41,45}
    #for ((port=0;port < ${TotalPortNum}; port++))
    do
	    record_time "$session" start "DAC PORTS;${port}" "passed" "NA" "${RackSN}"
        PortResult=$(cat ${PortResultLog} | grep "ce${port}" | awk '{print$2}')
        if [ "${PortResult}" == "up" ];then
                #echo "${PortIndex} ports already setup" 
                #let DisPort=port+1
            show_pass_msg "Port ${port} port already connect DAC cable, continue to other ports"
		    record_time "$session" end "DAC PORTS;${port}" "passed" "PASS" "${RackSN}"
        else
            show_fail_msg "Port ${port} port don't have DAC cable connected, continue to other ports"
		    record_time "$session" end "DAC PORTS;${port}" "passed" "FAIL" "${RackSN}"
            let res+=1
        fi
    done

    if [ $res -eq 0 ];then
        echo "All 3 DAC ports are already checked"
	    record_time "$session" total "$session;All" "NA" "PASS" "${RackSN}"
    else
        echo "Some DAC ports are not enabled correctly, shown as below"
        cat ${PortResultLog} | grep "ce37\|ce41\|ce45"
	    record_time "$session" total "$session;All" "NA" "FAIL" "${RackSN}"
	return 1
    fi
}


base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
diagnosticLog=${LOGFOLDER}/RUSW/$switch_index/dac_diagnostic_wg400.txt
LOGFILE=${LOGFOLDER}/RUSW/$switch_index/daclog.txt

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "$session" initial "" "" "" "$RackSN"  
ssh-keygen -R "${sw_ip}" > /dev/null

check_DAC_status "$HPRPort" | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_fail_msg "HPRv3 WG400 DAC Check Port Test Fail"  | tee -a ${LOGFILE}
    record_time "$session" total "$session;NA" "NA" "FAIL" "${RackSN}"
    record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_WG400_${switch_index}_${sw_sn}_DACCHECK_FAIL_${startTime}.log
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/RUSW/$switch_index/${finalLog}
    cp ${LOGPATH}/${RackSN}/RUSW/$switch_index/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

echo "HPRv3 WG400 DAC Check Function finish the testing, close the test" | tee -a ${LOGFILE}
record_time "$session" total "$session;NA" "NA" "PASS" "${RackSN}"
record_time "$session" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_WG400_${switch_index}_${sw_sn}_DACCHECK_PASS_${startTime}.log
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/RUSW/$switch_index/${finalLog}
cp ${LOGPATH}/${RackSN}/RUSW/$switch_index/${finalLog} /log/hprv3 > /dev/null

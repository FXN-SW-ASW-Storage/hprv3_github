#!/bin/bash
# Version       : v1.0
# Function      : Execute BMC Function and check/update BMC FW. 
# History       :
# 2024-10-30    | initial version
source ../commonlib
source ../record_time

execscript=$(basename $BASH_SOURCE)
echo "Current use script : ${execscript}"

set -x

#switch_index=1

while getopts s:i: OPT; do
    case "${OPT}" in
        "s")
			RackSN=${OPTARG}
			check_sn ${RackSN}
			RackIPN=$(cat ${LOGPATH}/${RackSN}/rackipn.txt)
			RackAsset=$(cat ${LOGPATH}/${RackSN}/assetid.txt)
		;;
        "i")
            switch_index=${OPTARG}
            if [ -z "${switch_index}" ];then
				print_help
				return 1
			fi
        ;;
        *)
			print_help
			return 1
		;;
    esac
done

BMCFW_Check()
{
        #for ((index=1;index <= ${switch_index};index++))
        #do
            record_time "${SessionName}" start "${SessionName};NA" "montblanc-v3.01" "NA" "${RackSN}"
            echo "Start to check the MP3 ${switch_index} BMC FW"
    	    #update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Check" 1
            MP3IP=$(cat ${LOGPATH}/${RackSN}/FSW/${switch_index}/mac_ip.txt)
            echo "Update switch index : ${switch_index} SSH Key and login the switch"
            echo "ssh-keygen -R ${MP3IP}"
            exeucte_test "cat /etc/issue" "${MP3IP}" | tee ${BMCLog}
            logResultCheck "LogCheck" "OpenBMC" "NF;montblanc-v3.01" "${BMCLog}"
            if [ ${PIPESTATUS[0]} -ne 0 ];then
            #echo "The BMC FW is not match the target version, need to update BMC FW"
            #show_warn_msg "Rack Module Information Test -- BMC FW (Before Update)"
            #BMCFW_Update
        #if [ ${PIPESTATUS[0]} -eq 0 ];then
                #echo "The Wedge400 BMC already update, check again the BMC FW" | tee -a ${LOGFILE}
                #logResultCheck "LogCheck" "OpenBMC" "NF;wedge400-33b5fae6640" "${BMCLog}"
                #if [ ${PIPESTATUS[0]}-eq 0 ];then
                        #echo "BMC FW is alreay match to target version"
                        #show_pass_msg "Rack Module Information Test -- BMC FW"
                        #record_time "HPRv3_MP3_BMC" end "BMCFW_Check;NA" "wedge400-33b5fae6640" "PASS" "${RackSN}"
			##update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Check" 2
                #else

                echo "Index : ${switch_index} BMC FW is mismatch to target version"
                show_fail_msg "Rack Module Information Test -- BMC FW"
                record_time "${SessionName}" end "${SessionName};NA" "montblanc-v3.01" "FAIL" "${RackSN}"
			    #update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Check" 3
                return 1
                #fi
        #else
                #echo "BMC FW can't updated"
                #show_fail_msg "Rack Module Information Test -- BMC Update"
                #record_time "HPRv3_MP3_BMC" end "BMCFW_Check;NA" "wedge400-33b5fae6640" "FAIL" "${RackSN}"        
		        ##update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Check" 3 
                #return 1
        #fi
            else
                echo "Index : ${switch_index} BMC FW is match to target version"
                show_pass_msg "Rack Module Information Test -- BMC FW"
                record_time "${SessionName}" end "${SessionName};NA" "montblanc-v3.01" "PASS" "${RackSN}"
	            #update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Check" 2
            fi
        #done
}

BMCFW_Update()
{
    BMCUpdateFlg=1
    record_time "${SessionName}" start "BMCFW_Update;NA" "montblanc-v3.01" "NA" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Update" 1
    echo "Start to update the BMC FW"
    echo "Step 1. Check flash0 location"
    echo "${WG400BMCPATH}"
    IMGName="flash-wedge400-20250227181258"
    exeucte_test "cat /proc/mtd" "${MP3IP}" | tee ${BMCLog}
    mtdlocation=$(cat ${BMCLog} | grep "flash0" | awk '{print$1}' | tr -d ':')
    echo "The flash0 location : ${mtdlocation}"
    echo "Step 2. Send the update image to Wedge400"
    echo "Command : sshpass -p "0penBmc" scp ${WG400BMCPATH}/${IMGName} ${MP3IP}:/tmp"
        sshpass -p "0penBmc" scp ${WG400BMCPATH}/${IMGName} ${MP3IP}:/tmp
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        echo "Can't send the BMC image into Wedge400"
        show_fail_msg "Rack Module Information Test -- BMC Image"
        record_time "${SessionName}" end "BMCFW_Update;NA" "wedge400-33b5fae6640" "FAIL" "${RackSN}"
	update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Update" 3
        return 1
    else
        show_pass_msg "Rack Module Information Test -- BMC Image"
    fi
    echo "Step 3. Update the BMC and wait for 400 seconds"
    #exeucte_test "cd /tmp" "${MP3IP}" 
    Command="flashcp -v /tmp/${IMGName} /dev/${mtdlocation}"
    exeucte_test "${Command}" "${MP3IP}" | tee ${BMCLog}
    #exeucte_test "/usr/local/bin/wedge_power.sh reset -s" "${MP3IP}" &
    exeucte_test "reboot" "${MP3IP}" &
    sleep 400
    echo "Step 3. Check BMC FW again after BMC update"
    exeucte_test "cat /etc/issue" "${MP3IP}" | tee ${BMCLog}
    logResultCheck "LogCheck" "OpenBMC" "NF;wedge400-33b5fae6640" "${BMCLog}"
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        echo "The BMC FW is not match the target version, need to update BMC FW"
        show_fail_msg "Rack Module Information Test -- BMC FW (After Update)"
        record_time "${SessionName}" end "BMCFW_Update;NA" "wedge400-33b5fae6640" "FAIL" "${RackSN}"
        update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Update" 3
	return 1
    else
        show_pass_msg "Rack Module Information Test -- BMC FW (After Update)"
	update_status "$SN" "$folder" "$index" "$testitem" "BMC FW Update" 2
    fi
        record_time "${SessionName}" end "BMCFW_Update;NA" "wedge400-33b5fae6640" "PASS" "${RackSN}"
}



base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
BMCLog=${LOGPATH}/${RackSN}/FSW/${switch_index}/BMCLog.txt
LOGFILE=${LOGPATH}/${RackSN}/FSW/${switch_index}/log.txt
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
SessionName="HPRv3_MP3_BMC_${switch_index}"

record_time "${SessionName}" initial "" "" "" "$RackSN" 
ssh-keygen -R "${MP3IP}" > /dev/null

#Scan | tee -a ${LOGFILE}
#if [ "${PIPESTATUS[0]}" -ne "0" ];then
#	show_error_message "Can't get correct information" | tee -a ${LOGFILE}
#    record_time "HPRv3_MP3_BMC" end "Scan_Information" "NA" "FAIL" "${RackSN}" | tee -a ${LOGFILE}
#    record_time "HPRv3_MP3_BMC" total "HPRv3_MP3_BMC;NA" "NA" "FAIL" "${RackSN}"
#    record_time "HPRv3_WG400" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
#    cat ${WG400LOGPATH}/summary_table_${station}.conf | tee -a ${LOGFILE}
#    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
#    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
#    return 1
#fi
echo "Start the BMC Function Check" | tee ${LOGFILE}
BMCFW_Check | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
    show_error_msg "BMC FW Check" | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${switch_index}_BMCFUNC_FAIL_${startTime}.log
    record_time "${SessionName}" total "$SessionName;NA" "NA" "FAIL" "${RackSN}"
    record_time "${SessionName}" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    return 1
fi

echo "Wedge400 BMC finish the testing, close the test" | tee -a ${LOGFILE}
record_time "${SessionName}" total "${SessionName};NA" "NA" "PASS" "${RackSN}"
#record_time "${SessionName}" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_MP3_${switch_index}_BMCFUNC_PASS_${startTime}.log
cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
show_pass | tee -a $LOGFILE
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/FSW/${switch_index}/${finalLog}
cp ${LOGPATH}/${RackSN}/FSW/${switch_index}/${finalLog} /log/hprv3 > /dev/null
exit 0


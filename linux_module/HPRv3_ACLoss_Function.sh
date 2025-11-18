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
                wedge400SN=$(cat ${LOGPATH}/${RackSN}/RUSW/${switch_index}/serialnumber.txt)
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

ACLoss_Function_Diagnostic_test()
{
    HPR_BBU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_BBU" | grep "Device Address" | awk '{print$NF}'))
    echo "HPR BBU Address : ${HPR_BBU_AddressArr[@]}"
    rm -rf ${ACLBeforeLog} ${ACLAfterLog} > /dev/null
    for bbu_address in ${HPR_BBU_AddressArr[@]};do
        update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Count" 1
        echo "Rack Module Information Test - Precheck with rackmoninfo for AC_Loss_1_Count_Requested and AC_Loss_2_Count_Requested"
        record_time "HPRv3_WG400_ACLOSS" start "AC_Loss_Count_Check;${bbu_address}" "[0]" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli read ${bbu_address} 0xe4" "${wedge400IP}" | tee ${TEMPLog}
        Value1=$(cat ${TEMPLog} | grep "0x00" | tr -d '\r\n')
        ACLoss1Val=$((${Value1}))
        exeucte_test "/usr/local/bin/rackmoncli read ${bbu_address} 0xe5" "${wedge400IP}" | tee ${TEMPLog}
        Value2=$(cat ${TEMPLog} | grep "0x00" | tr -d '\r\n')
        ACLoss2Val=$((${Value2}))
        echo "BBU Addr : ${bbu_address},${ACLoss1Val},${ACLoss2Val}" >> ${ACLBeforeLog}
        record_time "HPRv3_WG400_ACLOSS" end "AC_Loss_Count_Check;NA" "[0]" "PASS" "${RackSN}"
    done
    update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Count" 2
    
    HPR_PSU_AddressArr=($(cat ${RackmonLog} | grep -B 1 "ORV3_HPR_PSU" | grep "Device Address" | awk '{print$NF}'))
    update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 1
    echo "HPR PSU Address : ${HPR_PSU_AddressArr[@]}"
    for address in ${HPR_PSU_AddressArr[@]};do
        echo "Rack Module Information Test - Assert the ac_loss signal for PSU address : ${address}"
        #/usr/bin/python3 "Wedge400" "${wedge400Dev}" "BMC" "0" "NA" "/usr/local/bin/rackmoninfo"
        #cat ./log/Execution_console.log >> ${LOGFILE}
        echo "Rack Module Information Test - Check the AC_Loss signal should be de-assert : ${address}"
        exeucte_test "/usr/local/bin/rackmoncli read ${address} 0x5e" "${wedge400IP}" | tee ${TEMPLog}
        Status=$(cat ${TEMPLog} | grep "0x08" | tr -d '\r\n')
        if [ $Status == "0x0801" ];then
            echo "The status is ok, continue to test"
            sleep 2
        else
            echo "The register already set to enable, set the register again"
            exeucte_test "/usr/local/bin/rackmoncli write ${address} 0x5e 0x881" "${wedge400IP}" | tee ${TEMPLog}
            AfterStatus=$(cat ${TEMPLog} | grep "0x08" | tr -d '\r\n')
            if [ $AfterStatus == "0x0801" ];then
                echo "The status is ok, continue to test"
                sleep 2
            else
                echo "The register can't set to de-assert, stop the test"
                update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 3
                return 1
            fi
        fi 

        record_time "HPRv3_WG400_ACLOSS" start "PSU_Assert_ACLoss_Signal;${address}" "NA" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli write ${address} 0x5e 0x881" "${wedge400IP}" | tee ${TEMPLog}
        Status=$(cat ${TEMPLog} | grep "SUCCESS" | wc -l)
        exeucte_test "/usr/local/bin/rackmoncli read ${address} 0x5e" "${wedge400IP}" | tee ${TEMPLog}
        RegStatus=$(cat ${TEMPLog} | grep "0x08" | tr -d '\r\n')
        if [ $Status -eq 1 ] && [ $RegStatus == "0x0881" ];then
            echo "The status is ok, continue to test"
            record_time "HPRv3_WG400_ACLOSS" end "PSU_Assert_ACLoss_Signal;${address}" "0x0881" "PASS" "${RackSN}"
            sleep 2
        else
            echo "The register can't be set, try again"
            exeucte_test "/usr/local/bin/rackmoncli write ${address} 0x5e 0x881" "${wedge400IP}" | tee ${TEMPLog}
            Status=$(cat ${TEMPLog} | grep "SUCCESS" | wc -l)
            if [ $Status -eq 1 ];then
                echo "The status is ok, continue to test"
            else
                echo "The register can't be set after retry, stop the test"
                record_time "HPRv3_WG400_ACLOSS" end "PSU_Assert_ACLoss_Signal;${address}" "0x0881" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_ACLOSS" total "HPRv3_WG400_ACLOSS;NA" "NA" "FAIL" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 3
                return 1
            fi
        fi 

        
        record_time "HPRv3_WG400_ACLOSS" start "PSU_DeAssert_ACLoss_Signal;${address}" "NA" "NA" "${RackSN}"
        exeucte_test "/usr/local/bin/rackmoncli write ${address} 0x5e 0x801" "${wedge400IP}" | tee ${TEMPLog}
        Status=$(cat ${TEMPLog} | grep "SUCCESS" | wc -l)
        exeucte_test "/usr/local/bin/rackmoncli read ${address} 0x5e" "${wedge400IP}" | tee ${TEMPLog}
        RegStatus=$(cat ${TEMPLog} | grep "0x08" | tr -d '\r\n')
        if [ $Status -eq 1 ] && [ $RegStatus == "0x0801" ];then
            echo "The status is ok, continue to test"
            record_time "HPRv3_WG400_ACLOSS" end "PSU_DeAssert_ACLoss_Signal;${address}" "0x0801" "PASS" "${RackSN}"
            sleep 2
        else
            echo "The register can't be set, try again"
            exeucte_test "/usr/local/bin/rackmoncli write ${address} 0x5e 0x801" "${wedge400IP}" | tee ${TEMPLog}
            Status=$(cat ${TEMPLog} | grep "SUCCESS" | wc -l)
            if [ $Status -eq 1 ];then
                echo "The status is ok, continue to test"
            else
                echo "The register can't be set after retry, stop the test"
                record_time "HPRv3_WG400_ACLOSS" end "PSU_DeAssert_ACLoss_Signal;${address}" "0x0801" "FAIL" "${RackSN}"
                record_time "HPRv3_WG400_ACLOSS" total "HPRv3_WG400_ACLOSS;NA" "NA" "FAIL" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 3
                return 1
            fi
        fi 
    done

    for bbu_address in ${HPR_BBU_AddressArr[@]};do
        echo "Rack Module Information Test - Precheck with rackmoninfo for AC_Loss_1_Count_Requested and AC_Loss_2_Count_Requested"
        
        OriginACLoss1=$(cat ${ACLBeforeLog} | grep ${bbu_address} | awk -F ':' '{print$2}' | awk -F ',' '{print$2}')
        OriginACLoss2=$(cat ${ACLBeforeLog} | grep ${bbu_address} | awk -F ':' '{print$2}' | awk -F ',' '{print$3}')


        exeucte_test "/usr/local/bin/rackmoncli read ${bbu_address} 0xe4" "${wedge400IP}" | tee ${TEMPLog}
        Value1=$(cat ${TEMPLog} | grep "0x00" | tr -d '\r\n')
        ACLoss1Val=$((${Value1}))
        
        exeucte_test "/usr/local/bin/rackmoncli read ${bbu_address} 0xe5" "${wedge400IP}" | tee ${TEMPLog}
        Value2=$(cat ${TEMPLog} | grep "0x00" | tr -d '\r\n')
        ACLoss2Val=$((${Value2}))
        record_time "HPRv3_WG400_ACLOSS" start "Check_BBU_ACLoss_Count;${bbu_address}" "NA" "NA" "${RackSN}"
        if [ ${ACLoss1Val} -gt ${OriginACLoss1} ] || [ ${ACLoss2Val} -gt ${OriginACLoss2} ];then
            echo "Address : ${address}, AC_Loss_1_Count_Requested origin : ${OriginACLoss1} and new value : ${ACLoss1Val}"
            echo "Address : ${address}, AC_Loss_2_Count_Requested origin : ${OriginACLoss2} and new value : ${ACLoss2Val}"
            if [ ${ACLoss1Val} -gt ${OriginACLoss1} ];then 
                echo "The AC Loss value increase, continue the test"
                echo "Both The AC Loss values are increased now, continue to check"
                show_pass_msg "AC Loss Functional Test -- Address : ${address} AC_Loss Value Check"
                record_time "HPRv3_WG400_ACLOSS" end "Check_BBU_ACLoss_Count;${bbu_address}" "ACCount1 Increase" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 2
            else
                echo "The AC Loss value increase, continue the test"
                echo "Both The AC Loss values are increased now, continue to check"
                show_pass_msg "AC Loss Functional Test -- Address : ${address} AC_Loss Value Check"
                record_time "HPRv3_WG400_ACLOSS" end "Check_BBU_ACLoss_Count;${bbu_address}" "ACCount2 Increase" "PASS" "${RackSN}"
                update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 2
            fi
        elif [ ${ACLoss1Val} -eq ${OriginACLoss1} ] || [ ${ACLoss2Val} -eq ${OriginACLoss2} ];then
            echo "Address : ${address}, AC_Loss_1_Count_Requested origin : ${OriginACLoss1} and new value : ${ACLoss1Val}"
            echo "Address : ${address}, AC_Loss_2_Count_Requested origin : ${OriginACLoss2} and new value : ${ACLoss2Val}"
            echo "The AC Loss value equal, continue the test"
            echo "Both The AC Loss values are eqqualed now, continue to check"
		    show_pass_msg "AC Loss Functional Test -- Address : ${address} AC_Loss Value Check"
            record_time "HPRv3_WG400_ACLOSS" end "Check_BBU_ACLoss_Count;${bbu_address}" "Equal" "PASS" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 2
        else
            echo "Address : ${address}, AC_Loss_1_Count_Requested origin : ${OriginACLoss1} and new value : ${ACLoss1Val}"
		    echo "Address : ${address}, AC_Loss_2_Count_Requested origin : ${OriginACLoss2} and new value : ${ACLoss2Val}"
            echo "The AC Loss value don't increase or equaled, stop the test"
	    	show_fail_msg "AC Loss Functional Test -- Address : ${address} AC_Loss Value Check"
            record_time "HPRv3_WG400_ACLOSS" end "Check_BBU_ACLoss_Count;${bbu_address}" "Equal" "FAIL" "${RackSN}"
            record_time "HPRv3_WG400_ACLOSS" total "HPRv3_WG400_ACLOSS;NA" "NA" "FAIL" "${RackSN}"
            update_status "$SN" "$folder" "$index" "$testitem" "AC Loss Function" 3
	    	return 1
        fi
    done
}

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${RackSN}
startTime=$(date "+%F_%T" | sed -e "s/-//g" -e "s/://g")
RackmonLog=${LOGFOLDER}/RackMonLog.txt
LOGFILE=${LOGFOLDER}/log.txt
ACLBeforeLog=${LOGFOLDER}/ACLossBefore.log
ACLAfterLog=${LOGFOLDER}/ACLossAfter.log
PSULog=${LOGFOLDER}/PSULog.txt
BBULog=${LOGFOLDER}/BBULog.txt
TEMPLog=${LOGFOLDER}/TEMP.log
folder=RUSW
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)

record_time "HPRv3_WG400_ACLOSS" initial "" "" "" "$RackSN"

ACLoss_Function_Diagnostic_test | tee -a ${LOGFILE}
if [ "${PIPESTATUS[0]}" -ne "0" ];then
	show_error_msg "HPRv3 AC LOSS Test" | tee -a ${LOGFILE}
    show_fail | tee -a ${LOGFILE}
    finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_${wedge400SN}_ACLOSS_FAIL_${startTime}.log
    record_time "HPRv3_WG400_ACLOSS" total "HPRv3_WG400_ACLOSS;NA" "NA" "FAIL" "${RackSN}"
    record_time "HPRv3_WG400_ACLOSS" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
    #cat ${LOGPATH}/${RackSN}/summary_table_${station}.conf | tee -a ${LOGFILE}
    cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
    cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
    exit 1
fi

show_pass_msg "HPRv3 AC LOSS Test" | tee -a ${LOGFILE}
show_pass | tee -a ${LOGFILE}
finalLog=${RackIPN}_${RackSN}_${RackAsset}_HPRv3_${switch_index}_${wedge400SN}_ACLOSS_PASS_${startTime}.log
record_time "HPRv3_WG400_ACLOSS" total "HPRv3_WG400_ACLOSS;NA" "NA" "PASS" "${RackSN}"
record_time "HPRv3_WG400_ACLOSS" show "" "" "" "${RackSN}" | tee -a ${LOGFILE}
cat ${LOGFILE} > ${LOGPATH}/${RackSN}/${finalLog}
cp ${LOGPATH}/${RackSN}/${finalLog} /log/hprv3 > /dev/null
exit 0

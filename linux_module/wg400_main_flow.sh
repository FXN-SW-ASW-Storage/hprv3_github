#!/bin/bash
source ../commonlib

stid="L11-FT"

function print_help() {

    cat <<EOF
    Usage: $(basename $0) -s RACK_SN [OPTION]
        s : Rack serial Number.
    [OPTION]:
        i : swtich index. 0 for WG400. 1-8 for FSW.
        m : disable SFC.
    Example: $(basename $0) -s JDYD1234567890 [ -i 1 ] [ -t ]
EOF
}
#set -x
DISABLE_SFC=0
SN=""
index=""
station=""
while getopts s:i:m:d:f OPT; do
    case "${OPT}" in
        "s")
            SN=${OPTARG}
            check_sn "$SN"
            ;;
        "m")
            DISABLE_SFC=1
            ;;
        "i")
            index=${OPTARG}
            ;;
        *)
            echo "Wrong Parameter..."
	    print_help 
            exit 1
            ;;
    esac
done

source ../record_time
newversion=$(cat ${FOXCONN}/newversion | grep -i "version" | awk -F '=' '{print$2}')
PROJECT="WG400"
station=$(cat /home/station.cfg | grep MFG | awk -F '=' '{print$NF}')
LOGFOLDER=${LOGPATH}/${SN}
SFC_CTRL=0 #Enable SFC control first.Should be always 1
folder="RUSW"

if [ -z "${SN}" ] || [ -z "${index}" ];then
    print_help
    exit 1
fi

if [[ "${MFG}" == "FHU" ]];then
        ## Try to fix screen expect command error
        export TMPDIR=${LOGPATH}/${SN}
fi

record_path="${LOGFOLDER}/${folder}/${index}"
sw_sn=`cat ${record_path}/serialnumber.txt`
LOGFILE=${record_path}/log.txt
last_main_log_name=${record_path}/last_main_log_name.txt
if [ -f "${last_main_log_name}" ];then
    rm -f "${last_main_log_name}"
fi

run_command(){
    pushd ${LINUXMODULE} > /dev/null
    echo -e "${PROJECT} Function test" > ${LOGFILE}
    record_time "WG400_MAIN" initial "" "" "" "${RackSN}"
    ret=0
    for m in $1; do
        echo $m |grep -i "untest" > /dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		continue
	fi
    #record_time "HPRv3_WG400_BBU" start "BBU ${bbu_address} Check;${bbu_address}" "${bbu_address}" "NA" "${RackSN}"
	#record_time "WG400_MAIN" start "$m;NA" "NA" "NA" "${SN}" 
    ./$m.sh -s $SN -i $index | tee -a ${LOGFILE}
    if [ "${PIPESTATUS[0]}" -ne "0" ]; then
            show_fail_msg "$m module Test" >> ${LOGFILE}
            ${TOOL}/color "$m module test"  FAIL
            echo " "
            echo " " >>${LOGFILE}
            #record_time "WG400_MAIN" end "$m;NA" "NA" "FAIL" "${SN}" 
            let ret+=1
	    exit 1 
        else
            show_pass_msg "$m module Test " >> ${LOGFILE}
            ${TOOL}/color "$m module test"  PASS
            echo " "
            echo " " >>${LOGFILE}
	        #record_time "WG400_MAIN" end "$m;NA" "NA" "PASS" "${SN}" 
        fi
    done
    #if [ "${ret}" -eq "0" ];then
    #    record_time "WG400_MAIN" total "$m;NA" "NA" "PASS" "${SN}" 
    #else
    #    record_time "WG400_MAIN" total "$m;NA" "NA" "FAIL" "${SN}"
    #fi
    popd > /dev/null
    return ${ret}
}

show_ft_menu(){
    clear
    echo -e "                          ${PROJECT}                                      " 
    echo -e "###########################################################################"
    echo -e "###########################################################################"
    echo -e "##### \t    RUN LEVEL:      ${stid} ${Flag}	\t\t\t     ######"
    echo -e "##### \t    CODE VERSION:   ${newversion} \t\t\t\t     ######"
    echo -e "###########################################################################"
    echo -e "###########################################################################"

}

upload_log()
{  
    pushd ${LOGFOLDER}/${folder}/${index} > /dev/null
    if [ ! -d "${LOGFOLDER}/WG400_MAIN/PASS" ] || [ ! -d "${LOGFOLDER}/WG400_MAIN/FAIL" ] ;then
        mkdir -p "${LOGFOLDER}/WG400_MAIN/PASS"
        mkdir -p "${LOGFOLDER}/WG400_MAIN/FAIL"
    fi
    item=${2}
    time=$(date "+%F_%T" | sed -e "s\:\-\g")
    rack_sn=$(cat ${LOGPATH}/${SN}/SN.txt)
    platform=`cat ${LOGFOLDER}/platform.txt | tr '[:lower:]' '[:upper:]'`
    rackipn=`cat ${LOGFOLDER}/rackipn.txt | tr '[:lower:]' '[:upper:]'`
    log_name="${rack_sn}"_"${platform}"_"${PROJECT}"-${index}_${sw_sn}_WG400_"${Flag}"_${1}_"${time}".log
    file_name="${LOGFOLDER}/WG400_MAIN/${1}/${log_name}"
    echo "****************************************************" >${file_name}
    echo "${file_name}" >> ${file_name}
    echo "****************************************************" >>${file_name}
    echo -e "Station Name\t: ${PROJECT}" >> ${file_name}
    echo -e "Function Name\t: ${execfunction}" >> ${file_name}
    echo -e "Code Version\t: ${newversion}" >> ${file_name}
    echo -e "Start Time\t\t: `head -1 summary_table.conf | awk -F ',' '{print $1}'`" >> ${file_name}
    echo -e "End Time\t\t: `tail -1 summary_table.conf | awk -F ',' '{print $1}'`" >> ${file_name}
    echo -e "Test Time\t\t: `tail -1 summary_table.conf | awk -F ',' '{print $2}' | awk '$1=$1' `" >> ${file_name}
    echo -e "Rack_SN\t\t\t: ${rack_sn}" >>${file_name}
    echo -e "Platform\t\t: ${platform}" >>${file_name}
    echo -e "IPN Number\t\t: ${rackipn}" >>${file_name}
    echo -e "Result\t\t\t: $1" >>${file_name}
    echo "" >>${file_name}
    sleep 1
    echo "************** Summary Table ***********************" >>${file_name}
    #record_time ${record_path} show >> ${file_name}
    echo "****************************************************" >>${file_name}
    cat ${LOGFILE} >> ${file_name}
    echo "wg400_main_flow log file : ${file_name}"
#----------------------------- remark by Otis -----------------------------#
#    umount /log/diag
#    mount -t nfs 192.168.0.1:/tftpboot/pxeboot/log/diag /log/diag
#    if [[ $? -ne 0 ]]; then
#	    echo "mount /log/diag fail"
#	    return 1
#    fi
#----------------------------- remark by Otis -----------------------------#
    echo ${file_name} > ${last_main_log_name}
    
    popd > /dev/null 
    return 0

}

get_test_item(){
	 execfunction=$(cat $LOGFOLDER/execstation.txt)
     if [ $execfunction == "standalone" ];then
     #test_item="chk_fsw_ip mp2_test mp2_initial mp2_prbs31  mp2_snake_traffic mp2_insertion_loss"
         test_item=" chk_rusw_ip HPRv3_BMC_Function HPRv3_PMM_Standalone HPRv3_PSU_Standalone HPRv3_BBU_Standalone"
     elif [ $execfunction == "functional" ];then
     #test_item="chk_fsw_ip mp2_test mp2_initial mp2_prbs31  mp2_snake_traffic mp2_insertion_loss"
         #test_item="chk_rusw_ip run_wedge400_test"
        test_item=" chk_rusw_ip HPRv3_WG400BMC_Function run_wedge400_test HPRv3_PMM_Standalone HPRv3_PSU_Standalone HPRv3_BBU_Standalone HPRv3_PSU_Function_Full HPRv3_BBU_Function_Full HPRv3_PMM_Function_Full HPRv3_ACLoss_Function"
    else
        echo "Can't get correct function, stop the test"
    fi
} 

####################################################
#########         main part             ############
####################################################
#service ipmi start >/dev/null 2>&1

#ver=`ipmitool -V | grep -c 1.8.18`
#if [ "$ver" -ne "1" ];then
#	ipmitool -V
#	echo "The ipmitool verion is not 1.8.18 , please update the ipmitool first."
#	exit 1
#fi

	Flag=FT
    show_ft_menu
    if [[ ${SFC_CTRL} -eq 1 ]];then 
        pushd ${LINUXMODULE} > /dev/null
        if [[ ${DISABLE_SFC} -eq 1 ]];then
            ./down_sfc.sh -s ${SN} -f
            if [[ $? -ne 0 ]];then
                show_fail_msg "Download SFC"
                exit 1
            fi
        else
            ./down_sfc.sh -s ${SN}
            if [[ $? -ne 0 ]];then
                show_fail_msg "Download SFC Force"
                exit 1
            fi
        fi
        popd > /dev/null
    else
        echo "SFC_CTRL is not 1, skip the ./down_sfc.sh script"
    fi 

	get_test_item
	run_command "${test_item}" "$SN" "$index"
    if [[ "$?" -eq "0" ]]; then                
        upload_log PASS
        show_pass
		exit 0
    else
       	upload_log FAIL "${test_item}"
     	show_fail
      	exit 1
    fi

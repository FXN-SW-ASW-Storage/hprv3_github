#!/bin/bash
source ../commonlib
#. ./record_time

stid="L11"

function print_help() {

    cat <<EOF
    Usage: $(basename $0) -s RACK_SN [OPTION]
        s : Rack serial Number.
    [OPTION]:
        m : disable SFC.
	    d : Execute Standalone with -d standalone or execute functional with -d functional
        e : Employee number
    Example: $(basename $0) -e IG1558 -s JDYD1234567890
EOF
}

DISABLE_SFC=1
SN=""
executeStation=""
while getopts s:d:m OPT; do
    case "${OPT}" in
        "s")
            SN=${OPTARG}
            check_sn "$SN"
            ;;
        "m")
            DISABLE_SFC=1
            ;;
        "e")
            employeeNum=${OPTARG}
            ;;
        *)
            echo "Wrong Parameter..."
	    print_help 
            exit 1
            ;;
    esac
done

#. ./record_time
newversion=$(cat ${FOXCONN}/newversion | grep -i "version" | awk -F '=' '{print$2}')
PROJECT="HPRv3"
station=$(cat /home/station.cfg | grep MFG | awk -F '=' '{print$NF}')
LOGFILE=${LOGPATH}/${SN}/log.txt
LOGFOLDER=${LOGPATH}/${SN}
RackType=""
start_time=$(date +"%Y-%m-%dT%H:%M:%S.%6N")
pxeip=""
#cp ../log/${SN}/${SN}.JSON .
sleep 3

#record_path="${LOGFOLDER}"
SFC_CTRL=0 #Enable SFC control first.Should be always 1
run_parallel=0
if [ -z "${SN}" ];then
    print_help
    exit 1
fi

if [[ "${MFG}" == "FHU" ]];then
        ## Try to fix screen expect command error
        export TMPDIR=${LOGPATH}/${SN}
fi

get_pxeip()
{
    defaultInterface=$(ip route | grep default | awk '{print$5}')
    pxeip=$(ifconfig ${defaultInterface} | grep -iw "inet" | awk '{print$2}')
}

check_rack_type()
{
    fbpn=$(cat ${LOGFOLDER}/${SN}_formatted.json | grep "fbpn")
    if printf '%s\n' "${NSFRack[@]}" | grep -qx "$fbpn"; then
        echo "Exist in NSF, the rack is NSF rack"
        RackType="NSF"
    elif printf '%s\n' "${DSFRack[@]}" | grep -qx "$fbpn"; then
        echo "Exist in DSF, the rack is DSF rack"
        RackType="DSF"
    else
        echo "Can't get correct rack type either in NSF or DSF, stop the test"
        exit 1
    fi

}

run_command(){
    #pushd ${LINUXMODULE} > /dev/null
    echo -e "${PROJECT} Function test" > ${LOGFILE}
    #record_time ${record_path} initial
    res=0
    if [[ ${SFC_CTRL} -eq 1 ]];then 
        cd ${TOOL}/SFC > /dev/null
        ./sfc_process_start.sh "${SN}" "FVT" "${employeeNum}" "HPRv3" ""
        if [[ ${PIPESTATUS[0]} -ne 0 ]];then
            show_fail_msg "The Rack ${SN} can't send the start signal to SFC, please check again"
            exit 1
        else     
            echo "The Rack ${SN} can send the start signal to SFC, continue the test"
        fi
    else
        echo "The test don't upload the result to SFC, skip the start time update"
    fi

    for m in $1; do
        echo $m |grep -i "untest" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            continue
        fi

        #record_time ${record_path} start $m
        if [ ! "${m}" = "test_sw_in_parallel" ];then
            pwd
            cd ${LINUXMODULE} > /dev/null
            ./$m.sh -s $SN | tee -a ${LOGFILE}
            let res+=${PIPESTATUS[0]}
        else
            cd ${LINUXMODULE} > /dev/null
            ./test_rusw_in_parallel.sh -s $SN -t wg400_main_flow.sh | tee -a ${LOGFILE}
	        if [ ${RackType} == "NSF" ];then
            	cd ${LINUXMODULE} > /dev/null
            	./test_fsw_in_parallel.sh -s $SN -t mp3_main_flow.sh | tee -a ${LOGFILE}
            fi
            cd ${LINUXMODULE} > /dev/null
            ./show_rack_test_status.sh $SN -k | tee -a ${LOGFILE} 
            let res+=${PIPESTATUS[0]}
            run_parallel=1
        fi
        
        # ./HPRv3_WG400_DAC_Check.sh -s $SN | tee -a ${LOGFILE}
        # let res+=${PIPESTATUS[0]}

        if [ "$res" -ne "0" ]; then
            show_fail_msg "$m module Test " >> ${LOGFILE}
            ${TOOL}/color "$m module test"  FAIL
            echo " "
            echo " " >>${LOGFILE}
	    #record_time ${record_path} end $m Fail
    	    #record_time ${record_path} total "Total" Fail
	        popd
            return 1
        else
            show_pass_msg "$m module Test " >>${LOGFILE}
            ${TOOL}/color "$m module test"  PASS
            echo " "
            echo " " >>${LOGFILE}
	    #record_time ${record_path} end $m Pass
        fi
    done
    #record_time ${record_path} total "Total" Pass
    popd > /dev/null
    return ${res}
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
    pushd ${LOGFOLDER} > /dev/null
    if [ ! -d "${LOGFOLDER}/MAIN/PASS" ] || [ ! -d "${LOGFOLDER}/MAIN/FAIL" ] ;then
        mkdir -p "${LOGFOLDER}/MAIN/PASS"
        mkdir -p "${LOGFOLDER}/MAIN/FAIL"
    fi
    item=${2}
    time=$(date "+%F_%T" | sed -e "s\:\-\g")
    rack_sn=$(cat ${LOGPATH}/${SN}/SN.txt)
    platform=`cat ${LOGFOLDER}/platform.txt | tr '[:lower:]' '[:upper:]'`
    rackipn=`cat ${LOGFOLDER}/rackipn.txt | tr '[:lower:]' '[:upper:]'`
    log_name="${rack_sn}"_"${platform}"_"${PROJECT}"-"${stid}"-"${Flag}"_"${1}"_"${time}"
    log_path="${LOGFOLDER}/MAIN/${1}/${log_name}"
    mkdir -p "${log_path}"
    file_name="${log_path}/${log_name}.log"
    echo "****************************************************" >${file_name}
    echo "${file_name}" >> ${file_name}
    echo "****************************************************" >>${file_name}
    echo -e "Station Name\t: ${PROJECT}" >> ${file_name}
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

    if [[ ! -d /log/diag ]]; then
        mkdir /log/diag
    fi

    if [ "${run_parallel}" -eq "1" ] && [ ${RackType} == "NSF" ];then
        folder="RUSW"
        chk_list=`ls ${LOGFOLDER}/${folder}/`
        chk_pass_count=`cat ${LOGFOLDER}/${folder}_Count.txt`
        mkdir -p "${log_path}/WG400"
        for loc_id in ${chk_list};
        do
            last_log=`cat ${LOGFOLDER}/${folder}/${loc_id}/last_main_log_name.txt`
            if [ -f "${last_log}" ];then
                cp -f "${last_log}" "${log_path}/WG400" > /dev/null
                echo "************* WG400 Test Summary Table *************" >> ${file_name}
                awk '/Summary Table/{f=1; next} /[*]{20,}/{if(f){print; exit}} f' ${last_log} >> ${file_name}
            fi
        done
        folder="FSW"
        chk_list=`ls ${LOGFOLDER}/${folder}/`
        chk_pass_count=`cat ${LOGFOLDER}/${folder}_Count.txt`
        mkdir -p "${log_path}/MP3"
        for loc_id in ${chk_list};
        do
            last_log=`cat ${LOGFOLDER}/${folder}/${loc_id}/last_main_log_name.txt`
            if [ -f "${last_log}" ];then
                cp -f "${last_log}" "${log_path}/MP3" > /dev/null
                echo "************* MP3-${loc_id} Test Summary Table *************" >> ${file_name}
                awk '/Summary Table/{f=1; next} /[*]{20,}/{if(f){print; exit}} f' ${last_log} >> ${file_name}
            fi
        done
    else
        folder="RUSW"
        chk_list=`ls ${LOGFOLDER}/${folder}/`
        chk_pass_count=`cat ${LOGFOLDER}/${folder}_Count.txt`
        mkdir -p "${log_path}/WG400"
        for loc_id in ${chk_list};
        do
            last_log=`cat ${LOGFOLDER}/${folder}/${loc_id}/last_main_log_name.txt`
            if [ -f "${last_log}" ];then
                cp -f "${last_log}" "${log_path}/WG400" > /dev/null
                echo "************* WG400 Test Summary Table *************" >> ${file_name}
                awk '/Summary Table/{f=1; next} /[*]{20,}/{if(f){print; exit}} f' ${last_log} >> ${file_name}
            fi
        done
    fi
 
    cat ${LOGFILE} >> ${file_name}
    cp -f ${file_name} /log/hprv3 > /dev/null 2>&1
    echo "Main Test Log file : ${file_name}"

    if [ "${run_parallel}" -eq "1" ];then
        pushd "${LOGFOLDER}/MAIN/${1}/" > /dev/null 2>&1
        tar zcvf ${log_name}.tar.gz ${log_name} > /dev/null 2>&1
        cp -f ${log_name}.tar.gz /log/diag > /dev/null 2>&1
        echo "Compressed Log : ${LOGFOLDER}/MAIN/${1}/${log_name}.tar.gz"
        popd > /dev/null
    fi


}

get_test_item(){
	rackType=$1
	if [ ${rackType} == "NSF" ];then
    #test_item="chk_fsw_ip mp2_test mp2_initial mp2_prbs31  mp2_snake_traffic mp2_insertion_loss"
        test_item="get_rackinfo split_rackinfo chk_rusw_ip chk_fsw_ip test_sw_in_parallel"
	else
		test_item="get_rackinfo split_rackinfo chk_rusw_ip test_sw_in_parallel"
	fi
}

####################################################
#########         main part             ############
####################################################
#service ipmi start >/dev/null 2>&1

#ver=`ipmiTOOLPATH -V | grep -c 1.8.18`
#if [ "$ver" -ne "1" ];then
#	ipmiTOOLPATH -V
#	echo "The ipmiTOOLPATH verion is not 1.8.18 , please update the ipmiTOOLPATH first."
#	exit 1
#fi

	Flag=FT
    show_ft_menu
    if [[ ${SFC_CTRL} -eq 1 ]];then 
            pushd ${LINUXMODULE} > /dev/null
            if [[ ${DISABLE_SFC} -eq 1 ]];then
                echo "Don't check SFC, start the test directly"
                ./sfc_get_level.sh "${SN}" "FVT" "${LOGPATH}/${SN}"
                if [[ ${PIPESTATUS[0]} -ne 0 ]];then
                    show_fail_msg "The Rack ${SN} can't get any information from SFC, please check again"
                    exit 1
                else     
                    echo "The Rack ${SN} can get the information from SFC, check the file existness"
                    if [ -f "${LOGPATH}/${SN}/${SN}_formatted.json"];then
                        echo "Can get the rack json file, continue the test"
                    else   
                        echo "Can not get the rack json file, stop the test"
                        exit 1
                    fi
                fi
                ./split_rackinfo.sh "${SN}"
                if [[ ${PIPESTATUS[0]} -ne 0 ]];then
                    show_fail_msg "The Rack ${SN} can't split any information from JSON file, please check again"
                    exit 1
                else     
                    echo "The Rack ${SN} can get the information from JSON file and the component numbers are correct, continue the test"
                fi
            else
                read -p "Please input the employee number before test" emp_no
                cd ${TOOL}/SFC > /dev/null
                ./sfc_chk_route.sh "${SN}" "FVT" "${emp_no}"
                if [[ ${PIPESTATUS[0]} -ne 0 ]];then
                    show_fail_msg "The Rack ${SN} is not in FVT stage, please check again"
                    exit 1
                else     
                    show_pass_msg "The Rack ${SN} is in FVT stage, get the rack information"
                    ./sfc_get_level.sh "${SN}" "FVT" "${LOGPATH}/${SN}"
                    if [[ ${PIPESTATUS[0]} -ne 0 ]];then
                        show_fail_msg "The Rack ${SN} can't get any information from SFC, please check again"
                        exit 1
                    else     
                        echo "The Rack ${SN} can get the information from SFC, check the file existness"
                        if [ -f "${LOGPATH}/${SN}/${SN}_formatted.json"];then
                            echo "Can get the rack json file, continue the test"
                            ./split_rackinfo.sh "${SN}"
                            if [[ ${PIPESTATUS[0]} -ne 0 ]];then
                                show_fail_msg "The Rack ${SN} can't split any information from JSON file, please check again"
                                exit 1
                            else     
                                echo "The Rack ${SN} can get the information from JSON file and the component numbers are correct, continue the test"
                            fi
                        else   
                            echo "Can not get the rack json file, stop the test"
                            exit 1
                        fi
                    fi
                fi
            fi
            popd > /dev/null
    else
            echo "SFC_CTRL is not 1, skip the ./down_sfc.sh script"
    fi 
	
	get_test_item ${RackType}
	run_command "${test_item}" "$SN"
    if [[ "$?" -eq "0" ]]; then                
        upload_log PASS
        show_pass
        exit 0
    else
        upload_log FAIL "${test_item}"
        show_fail
        exit 1
    fi

#!/bin/bash
# Version       : v1.0
# Function      : Get bmc mac from node folder and ping if the IP is alive. 
# History       :
# 2024-10-30    | initial version

source ../commonlib

print_help(){

    cat <<EOF
    Usage: ./$(basename $0) Rack_SN#1 Rack_SN#2 Rack_SN#~
        Rack_SN : Input the Rack SN you want to monitor.
    Example: ./$(basename $0) GB123456789 GB223456789 GB333456789
EOF
}

while getopts k OPT; do
    case "${OPT}" in
        "k")
            STOP_Monitor=1
            ;;
        *)
            echo "Wrong Parameter..."
            print_help
            exit 1
            ;;
    esac
done

set -x 
base=$(basename $0)
cycle=30
Rack_SN=$1
LOGFOLDER=${LOGPATH}/${Rack_SN}
rackType=$(cat ${LOGFOLDER}/racktype.txt)

mon_log1=${LOGFOLDER}/mon_log1.txt
mon_log2=${LOGFOLDER}/mon_log2.txt

if [ -z "$1" ];then
    print_help
    echo "Need one Rack SN at least."
    exit 1
fi

show_status_msg(){
    _TEXT="$1"
    len=${#_TEXT}
    while [ $len -lt 19 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$2"
    len=${#_TEXT}
    while [ $len -lt 34 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$3"
    while [ $len -lt 51 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$4"
    while [ $len -lt 73 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$5"
    while [ $len -lt 90 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$6"
    while [ $len -lt 103 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$7"
    while [ $len -lt 120 ]
    do
        _TEXT=$_TEXT" "
        len=${#_TEXT}
    done
    _TEXT=$_TEXT"$8"
    echo "$_TEXT"
}
show_line(){
    folder=$1
    loc_id=$2
        if [ -f "${LOGFOLDER}/${folder}/${loc_id}/mac_ip.txt" ];then
            sw_ip=`cat ${LOGFOLDER}/${folder}/${loc_id}/mac_ip.txt`
        else
            sw_ip="No_Data"
        fi
        if [ -f "${LOGFOLDER}/${folder}/${loc_id}/serialnumber.txt" ];then
            sw_sn=`cat ${LOGFOLDER}/${folder}/${loc_id}/serialnumber.txt`
        else
            sw_sn="No_Data"
        fi
        fsw_session_name="${SN}-${folder}-${loc_id}"
        if [ -f "${LOGPATH}/${SN}/${folder}/${loc_id}/run_status" ];then
            get_status=$( cat ${LOGPATH}/${SN}/${folder}/${loc_id}/run_status)
        else
            get_status="No_Data"
        fi
        if [ -f "${LOGPATH}/${SN}/${folder}/${loc_id}/run_stage" ];then
            get_stage=$( cat ${LOGPATH}/${SN}/${folder}/${loc_id}/run_stage)
        else
            get_stage="No_Data"
        fi
        if [ -f "${LOGPATH}/${SN}/${folder}/${loc_id}/run_step" ];then
            get_step=$( cat ${LOGPATH}/${SN}/${folder}/${loc_id}/run_step)
            update_time=$(stat -c "%y" "${LOGPATH}/${SN}/${folder}/${loc_id}/run_step" | cut -d'.' -f1)
        else
            get_step="No_Data"
            update_time="No_Data"
        fi
        show_status_msg "${fsw_session_name}" "${sw_sn}" "${sw_ip}" "${get_stage}" "${get_step}" "${get_status}" "${update_time}"   

}

main()
{
	if [ $rackType == "NSF" ];then
    		fsw_list=`ls ${LOGFOLDER}/FSW/ | grep -v run | grep -v log`
    		rusw_list=`ls ${LOGFOLDER}/RUSW/ | grep -v run | grep -v log`
    		show_status_msg Session_Name Switch_SN IP TEST_ITEM TEST_STEP TEST_STATUS LAST_UPDATE_TIME > ${mon_log1}
    		for loc_id in ${rusw_list};
    		do
    		    show_line RUSW ${loc_id} >> ${mon_log1}
    		done
    		for loc_id in ${fsw_list};
    		do
    		    show_line FSW ${loc_id} >> ${mon_log1}
    		done
	else
                rusw_list=`ls ${LOGFOLDER}/RUSW/`
                show_status_msg Session_Name Switch_SN IP TEST_ITEM TEST_STEP TEST_STATUS LAST_UPDATE_TIME > ${mon_log1}
                for loc_id in ${rusw_list};
                do
                    show_line RUSW ${loc_id} >> ${mon_log1}
                done
	fi
}


echo "" > ${mon_log1}
echo "" > ${mon_log2}
while ((1))
do
    #clear
    for arg in "$@"; 
    do
        if [ "$arg" = "-k" ];then
		if [ $rackType == "NSF" ];then
            		folder="FSW"
            		chk_list=`ls ${LOGFOLDER}/${folder}/ | grep -v run`
            		chk_pass_count=`cat ${LOGFOLDER}/${folder}_Count.txt`
            		chk_fsw=0
            		fsw_finish=0
            		final_result=0
            		for loc_id in ${chk_list};
            		do
            		    last_log=${LOGFOLDER}/${folder}/${loc_id}/last_main_log_name.txt
            		    if [ -f "${last_log}" ];then
            		        let chk_fsw+=1
            		        ret=`cat ${last_log} | grep -ic pass`
            		        if [ "${ret}" -ne "1" ];then
            		            let final_result+=1
            		        fi
            		    fi
            		done
            		#echo "chk_fsw=${chk_fsw},chk_pass_count=${chk_pass_count}"
            		if [ "${chk_fsw}" -eq "${chk_pass_count}" ];then
            		    fsw_finish=1
            		fi
		fi
            	folder="RUSW"
            	chk_list=`ls ${LOGFOLDER}/${folder}/ | grep -v run`
            	chk_pass_count=`cat ${LOGFOLDER}/${folder}_Count.txt`
            	chk_rusw=0
            	rusw_finish=0
            	for loc_id in ${chk_list};
            	do
            	    last_log=${LOGFOLDER}/${folder}/${loc_id}/last_main_log_name.txt
            	    if [ -f "${last_log}" ];then
            	        let chk_rusw+=1
            	        ret=`cat ${last_log} | grep -ic pass`
            	        if [ "${ret}" -ne "1" ];then
            	            let final_result+=1
            	        fi
            	    fi
            	done
            	#echo "chk_rusw=${chk_rusw},chk_pass_count=${chk_pass_count}"
            	if [ "${chk_rusw}" -eq "${chk_pass_count}" ];then
            	    rusw_finish=1
            	fi
            #echo "fsw_finish=${fsw_finish},rusw_finish=${rusw_finish}"
		if [ ${rackType} == "NSF" ];then
            		if [ "${fsw_finish}" -eq "1" ] && [ "${rusw_finish}" -eq "1" ];then
                		echo "Detect all switches test finished"
                #echo "Final result = ${final_result}"
                		exit ${final_result}
            		fi
		else
			if [ "${rusw_finish}" -eq "1" ];then
                                echo "Detect all switches test finished"
                #echo "Final result = ${final_result}"
                                exit ${final_result}
                        fi
		fi
        elif [ -d "${LOGPATH}/${arg}" ];then
            LOGFOLDER=${LOGPATH}/${arg}
            SN=${arg}
            main
            	echo "" >> ${mon_log1}
            #echo "Flash every ${cycle}s" >> ${mon_log1}
        else 
            echo "Can not find $arg data"
        fi
    done
    # Only echo while changes
    echo "Monitor every ${cycle}s and flash when test status changed." >> ${mon_log1}
    diff ${mon_log1} ${mon_log2} > /dev/null 2>&1
    ret=$?
    if [ "${ret}" -eq "1" ];then
        clear
        cat ${mon_log1}
        cp -f ${mon_log1} ${mon_log2}
    fi 
    #echo "Flash every ${cycle}s"
    sleep ${cycle}
done

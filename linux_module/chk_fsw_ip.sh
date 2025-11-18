#!/bin/bash
# Version       : v1.0
# Function      : Get bmc mac from node folder and ping if the IP is alive. 
# History       :
# 2024-10-30    | initial version

source ../commonlib

while getopts s:i: OPT; do
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
        *)
            print_help
            exit 1
            ;;
    esac
done

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${SN}
LOGFILE=${LOGFOLDER}/${filename}
JSONFILE=${LOGFOLDER}/${SN}.JSON
folder="FSW"
name1="mac"

if [ -z "${SN}" ];then
    print_help
    echo "Need to run with -s option and input the Rack SN."
    exit 1
fi

chk_Count=`cat ${LOGFOLDER}/${folder}_Count.txt`

run_ping_test_bk()
{
    ping_test ${test_ip} > ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt
    if [ "$?" -ne "0" ];then
        #show_fail_msg "Ping ${test_ip}"
        #cat ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt
        mv -f ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt ${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}_fail.txt
        continue
    else
        #show_pass_msg "Ping ${test_ip}"
        mv -f ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt ${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}_pass.txt
        echo ${test_ip} > ${LOGFOLDER}/${folder}/${loc_id}/${name1}_ip.txt
        echo "${folder}-${loc_id} IP : ${test_ip}"
    fi
}

main()
{
    if [ ! -z "${index}" ];then
        chk_list=${index}
        chk_pass_count=1
    else
        chk_list=`ls ${LOGFOLDER}/${folder}/`
        chk_pass_count=${chk_Count}
    fi
    #echo "chk_list=${chk_list}"
    for loc_id in ${chk_list};
    do
        rm -rf ${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}*.txt
        mac=`cat ${LOGFOLDER}/${folder}/${loc_id}/${name1}.txt`
        #echo "MAC in ${SN}/${folder}/${loc_id} : ${mac}"
        if [ -z "${mac}" ];then
            show_fail_msg "Get ${name1}.txt in ${SN}/${folder}/${loc_id}"
            continue
        fi
        #echo "get_ip_from_dhcp $mac"
        get_ip_from_dhcp $mac
        if [ "$?" -ne "0" ];then
            continue
        else
            #echo "IP  in ${SN}/${folder}/${loc_id} : ${test_ip}"
            run_ping_test_bk &
            sleep 0.5 
            #ping_test ${test_ip} > ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt 
            #if [ "$?" -ne "0" ];then
            #    show_fail_msg "Ping ${test_ip}"
            #    cat ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt
            #    mv -f ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt ${LOGFOLDER}/${folder}/${loc_id}/ping_test_fail.txt
            #    continue
            #else
            #    show_pass_msg "Ping ${test_ip}"
            #    mv -f ${LOGFOLDER}/${folder}/${loc_id}/ping_test.txt ${LOGFOLDER}/${folder}/${loc_id}/ping_test_pass.txt
            #    echo ${test_ip} > ${LOGFOLDER}/${folder}/${loc_id}/ip.txt
            #fi
        fi
    done
    sleep 5
    res=0
    pass=0
    for loc_id in ${chk_list};
    do
        chk_file="${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}_fail.txt"
        if [ -f "${chk_file}" ];then
            show_fail_msg "Ping ${test_ip} in ${SN}/${folder}/${loc_id}"
            cat ${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}_fail.txt
            let res+=1
            continue
        fi
        chk_file="${LOGFOLDER}/${folder}/${loc_id}/ping_test_${name1}_pass.txt"
        if [ ! -f "${chk_file}" ];then
            show_fail_msg "Get ping_test_${name1}_pass.txt in ${SN}/${folder}/${loc_id}"
            let res+=1
        else
            let pass+=1
        fi
    done
    if [ "${res}" -ne "0" ];then
        show_fail_msg "Ping ${chk_pass_count} switch ${name1} IP"
        return 1
    elif [ ! "${chk_pass_count}" = "${pass}" ];then
	    show_fail_msg "Only ping ${pass} switch pass,need ${chk_pass_count} switches pass."
    else
        show_pass_msg "Ping ${chk_pass_count} switch ${name1} IP"
    fi
}

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
cycle=0
retry=2
while ((1))
do
    main | tee -a $LOGFILE
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        if [ "$cycle" -lt "$retry" ];then
            let cycle+=1
                echo "Wait 5s to check again"
                sleep 5
            continue
        else
            show_end_msg | tee -a ${LOGFILE}
            exit 1
        fi
    else
        show_end_msg | tee -a ${LOGFILE}
        exit 0
    fi
done

#!/bin/bash

source ../commonlib

print_help(){

    cat <<EOF
    Usage: ./$(basename $0) -s RACK_SN -i Switch_Index
        s : Rack serial Number.
        i : MP2 location ID.Should be 1 to 8.
    Example: ./$(basename $0) -s GD123456789 -i 1
EOF
}


while getopts s:i:p: OPT; do
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
            echo "Wrong Parameter..."
            print_help
            exit 1
            ;;
    esac
done

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${SN}
JSONFILE=${LOGFOLDER}/${SN}.JSON
folder="FSW"
LOGFILE=${LOGFOLDER}/${folder}/${index}/${filename}
RegArray=("0x40078" "0x48078" "0x50078" "0x58078" "0x60078" "0x68078" "0x70078" "0x78078")
PortNumArray=("1-16" "17-32" "33-48" "49-64" "65-80" "81-96" "97-112" "113-128")

#set -x

RackIPN=$1
SN=$2
RackAsset=$3
#wedge400Dev=$4
minipack2Index=$4
minipack2IP=$5

if [ -z "${index}" ];then
    print_help
    echo "Need to run with -i option and specify the index number."
    exit 1
fi

Normal_Function_Diagnostic_test()
{
	echo "Start to Check all Port status" 
    sw_ip=$1   
    PortResultLog=${LOGFOLDER}/${folder}/${index}/portResult.log 
    #executeCMDinDiagOS "cd /usr/local/cls_diag/SDK;./auto_load_user.sh" 
    #executeCMDinDiagOS "linespeed200G.soc"
    executeCMDinDiagBMCOS "portdump status all" "${sw_ip}"  | tee ${PortResultLog}

    PortResult=$(cat ${PortResultLog} | grep "port status check test" | awk '{print$NF}' | tr -d '\r\n')
    if [ "${PortResult}" == "PASSED" ];then
	    echo "${PortIndex} ports already setup" 
	    show_pass_msg "All ports Initial" 
    else
	    show_fail_msg "All  ports Initial"
        echo "Please fix the link down ports below:"
        cat ${PortResultLog} | grep -i down
	#    return 1
    fi
    TG_SnakeResultLog=${LOGFOLDER}/${folder}/${index}/TG_SnakeResultLog.log
    executeCMDinDiagBMCOS "linespeed200G.soc" "${sw_ip}" | tee ${TG_SnakeResultLog}
    sleep 3
    executeCMDinDiagBMCOS "vlan show" "${sw_ip}" | tee -a ${TG_SnakeResultLog}
    sleep 3
    executeCMDinDiagBMCOS "pvlan" "${sw_ip}" | tee -a ${TG_SnakeResultLog}
    return 0
}

main()
{
    eth0setup="ifconfig eth0 172.16.20.195;ifconfig eth0;"
    executeCMDinDiagOS "${eth0setup}" "${sw_ip}"
    res=0
    Normal_Function_Diagnostic_test "${sw_ip}"
    let res+=$?
    return ${res}
}

if [ ! -d "${LOGFOLDER}/TG_Snake_Setup/PASS" ];then
    mkdir -p "${LOGFOLDER}/TG_Snake_Setup/PASS"
    mkdir -p "${LOGFOLDER}/TG_Snake_Setup/FAIL"
fi
show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
cycle=0
retry=0
while ((1))
do
    sw_ip=`cat ${LOGFOLDER}/${folder}/${index}/mac_ip.txt`
    sw_sn=`cat ${LOGFOLDER}/${folder}/${index}/serialnumber.txt`
    update_status "${SN}" "${folder}" "${index}" "${testitem}" "Ping IP" 1
    chk_sw_ip | tee -a ${LOGFILE}
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        if [ "$cycle" -lt "$retry" ];then
            let cycle+=1
            echo "Wait 5s to check again"
            sleep 5
            continue
        else
            show_fail_msg "Ping switch IP ${sw_ip}"
            show_end_msg | tee -a ${LOGFILE}
            update_status "${SN}" "${folder}" "${index}" "${testitem}" "Ping IP" 3
            exit 1
        fi
    fi
    update_status "${SN}" "${folder}" "${index}" "${testitem}" "MAIN" 1
    main | tee -a $LOGFILE
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        if [ "$cycle" -lt "$retry" ];then
            let cycle+=1
                echo "Wait 5s to check again"
                sleep 5
            continue
        else
            show_end_msg | tee -a ${LOGFILE}
            time=$(date "+%F_%T" | sed -e "s\:\-\g")
            file_name="${LOGFOLDER}/TG_Snake_Setup/FAIL/${SN}"_"Megazord"_"MP2"-${index}_${sw_sn}_TG_Snake_Setup_FAIL_"${time}".log
            cp -f ${LOGFILE} ${file_name}
            echo "Log file : ${file_name}"
            update_status "${SN}" "${folder}" "${index}" "${testitem}" "" 3
            exit 1
        fi
    else
        show_end_msg | tee -a ${LOGFILE}
        time=$(date "+%F_%T" | sed -e "s\:\-\g")
        file_name="${LOGFOLDER}/TG_Snake_Setup/PASS/${SN}"_"Megazord"_"MP2"-${index}_${sw_sn}_TG_Snake_Setup_PASS_"${time}".log
        cp -f ${LOGFILE} ${file_name}
        echo "Log file : ${file_name}"
        update_status "${SN}" "${folder}" "${index}" "${testitem}" "MAIN" 2
        exit 0
    fi
done


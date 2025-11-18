#!/bin/bash
# Version       : v1.0
# Function      : Split the JSON file into servers,tors,consoleswitches folders.
# History       :
# 2024-10-22    | initial version

source ../commonlib

print_help(){

    cat <<EOF
    Usage: $(basename $0) -s RACK_SN
        s : Rack serial Number.
    Example: $(basename $0) -s GB123456789
EOF
}

while getopts s: OPT; do
    case "${OPT}" in
        "s")
            SN=${OPTARG}
            check_sn ${SN}
            ;;
        *)
            print_help
            exit 1
            ;;
    esac
done
#set -x
base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${SN}
LOGFILE=${LOGFOLDER}/${filename}
JSONFILE=${LOGFOLDER}/${SN}.JSON

rack_item="assetid rackipn platform RUSW_Model RUSW_Count FSW_Model FSW_Count powershelf_count"
sw_item="mac serialnumber"
#sw_item="mac serialnumber assetid partnumber"
ps_item="serialnumber"
#ps_item="serialnumber assetid partnumber"


if [ -z "${SN}" ];then
    print_help
    echo "Need to run with -s option and input the Rack SN."
    exit 1
fi

jq_rack()
{
    str1=`jq .rack.${1} ${JSONFILE} | sed 's/"//g'`
    if [ -z "${str1}" ];then
        show_fail_msg "Get ${1} $str1 from JSON"
        return 1
    else
        show_pass_msg "Get ${1} $str1 from JSON"
        echo ${str1} > ${LOGFOLDER}/${1}.txt
        return 0
    fi
}

main()
{
    if [ ! -f ${JSONFILE} ];then
        show_fail_msg "Check ${SN}.JSON file"
        echo "Please run get_rackinfo.sh first"
	echo functional > /opt/HPRV/log/$SN
	$SN
        return 1
    fi
    res=0
    for item in ${rack_item};
    do
        jq_rack ${item}
        if [ "$?" -ne "0" ];then
            let res+=1
        fi
    done
    #FSW_Count=`cat ${LOGFOLDER}/FSW_Count.txt`
    #FSW_count=`jq '.rack.FSW.node|length' ${JSONFILE}`
    #if [ ! "${FSW_count}" = "${FSW_Count}" ];then
    #    show_fail_msg "Check ${FSW_Count} FSW node data of JASON file"
    #    echo "The FSW Count from rack level data : ${FSW_Count} , the FSW node data from Node area : ${FSW_count}"
    #    return 1
    #fi
    #if [ ! -d "${LOGFOLDER}/FSW" ];then
    #    mkdir "${LOGFOLDER}/FSW"
    #fi
    #res2=0
    #for ((i=0;i<${FSW_Count};i++))
    #do
    #    split_node FSW ${i} & >> ${LOGFILE}
     #   let res2+=${PIPESTATUS[0]}
    #done
    #sleep 1
    #if [ "${res2}" -ne "0" ];then
    #    show_fail_msg "Split FSW data from JSON file"
    #    let res+=1
    #else
    #    show_pass_msg "Split FSW data from JSON file"
    #fi
    RUSW_Count=`cat ${LOGFOLDER}/RUSW_Count.txt`
    RUSW_count=`jq '.rack.RUSW.node|length' ${JSONFILE}`
    if [ ! "${RUSW_count}" = "${RUSW_Count}" ];then
        show_fail_msg "Check ${RUSW_Count} RUSW node data of JASON file"
        echo "The RUSW Count from rack level data : ${RUSW_Count} , the FSW node data from Node area : ${RUSW_count}"
        return 1
    fi
    if [ ! -d "${LOGFOLDER}/RUSW" ];then
        mkdir "${LOGFOLDER}/RUSW"
    fi
    res2=0
    for ((i=0;i<${RUSW_Count};i++))
    do
        split_node RUSW ${i} & >> ${LOGFILE}
        let res2+=${PIPESTATUS[0]}
    done
    sleep 1
    if [ "${res2}" -ne "0" ];then
        show_fail_msg "Split RUSW data from JSON file"
        let res+=1
    else
        show_pass_msg "Split RUSW data from JSON file"
    fi
    ps_Count=`cat ${LOGFOLDER}/powershelf_count.txt`
    ps_count=`jq '.rack.powershelf.node|length' ${JSONFILE}`
    if [ ! "${ps_count}" = "${ps_Count}" ];then
        show_fail_msg "Check ${ps_Count} powershelf node data of JASON file"
        echo "The powershelf Count from rack level data : ${ps_Count} , the FSW node data from Node area : ${ps_count}"
        return 1
    fi
    if [ ! -d "${LOGFOLDER}/powershelf" ];then
        mkdir "${LOGFOLDER}/powershelf"
    fi
    res2=0
    for ((i=0;i<${RUSW_Count};i++))
    do
        split_node powershelf ${i} & >> ${LOGFILE}
        let res2+=${PIPESTATUS[0]}
    done
    sleep 1
    if [ "${res2}" -ne "0" ];then
        show_fail_msg "Split powershelf data from JSON file"
        let res+=1
    else
        show_pass_msg "Split powershelf data from JSON file"
    fi
    if [ "${res}" -ne "0" ];then
        show_fail_msg "Split rack information"
        return 1
    else
        show_pass_msg "Split rack information"
        return 0
    fi
}

split_node()
{
        index=`jq .rack.${1}.node[${2}].index ${JSONFILE} | sed 's/"//g'`
        if [ -z "${index}" ];then
            show_fail_msg "Get .rack.${1}.node[${2}].index"
            return 1
        fi
        if [ ! -d "${LOGFOLDER}/${1}/${index}" ];then
            mkdir -p "${LOGFOLDER}/${1}/${index}"
        fi
        split_item=""
        if [ ! "${1}" = "powershelf" ];then
            split_item=${sw_item}
        else
            split_item=${ps_item}
        fi
        res1=0
        for item in ${split_item};
        do
            str1=`jq .rack.${1}.node[${2}].${item} ${JSONFILE} | sed 's/"//g'`
            if [ -z "${str1}" ];then
                show_fail_msg "Get .rack.${1}.node[${2}].${item}"
                let res1+=1
            else
                echo ${str1} > ${LOGFOLDER}/${1}/${index}/${item}.txt
            fi
        done
        if [ "${res1}" -ne "0" ];then
            return 1
        else
            return 0
        fi
} 

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
cycle=0
retry=0
while ((1))
do
    chk_station_cfg | tee -a $LOGFILE
    if [ "${PIPESTATUS[0]}" -ne "0" ];then
        show_end_msg | tee -a ${LOGFILE}
        exit 1
    fi
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

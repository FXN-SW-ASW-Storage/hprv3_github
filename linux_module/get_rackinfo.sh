#!/bin/bash
# Version       : v1.0
# Function      : Get the rack JSON file from MFG SFC.
# History       :
# 2024-10-22	| initial version

source ../commonlib
#set -x
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
            echo "Wrong Parameter..."
            echo "Usage: $(basename $0) -s SN -p logpath"
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

if [ -z "${SN}" ];then
    print_help
    echo "Need to run with -s option and input the Rack SN."
    exit 1
fi

main()
{
    #${MFG}/get_rackinfo_by_site.sh ${SN}
    pwd
    #read
    if [ -f "${SN}.JSON" ];then
        show_pass_msg "Download ${SN}.JSON file from SFC"
	    mv -f ${SN}.JSON ${LOGPATH}/${SN}/	
        if [ "$?" -eq "0" ];then
            show_pass_msg "Move ${SN}.JSON into log/${SN}/"
            return 0
        else
            show_fail_msg "Move ${SN}.JSON into log/${SN}/"
            return 1
        fi
    else
        show_fail_msg "Download ${SN}.JSON file from SFC"
        return 1
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

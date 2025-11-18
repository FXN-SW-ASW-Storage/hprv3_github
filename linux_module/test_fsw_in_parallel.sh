#!/bin/bash
# Version       : v1.0
# Function      : Get bmc mac from node folder and ping if the IP is alive. 
# History       :
# 2024-10-30    | initial version

source ../commonlib

print_help(){

    cat <<EOF
    Usage: ./$(basename $0) -s RACK_SN -t Script_Name [ Option ]
        s : Rack serial Number.
        t : Script Name.Like mp2_initial.sh , mp2_prbs31.sh..etc.
    [ Option ]
        i : MP3 location ID.Should be 1 to 3.
    Example: ./$(basename $0) -s GD123456789 -t mp2_initial.sh [ -i 1 ]
EOF
}


while getopts s:i:t: OPT; do
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
        "t")
            script_name=${OPTARG}
            if [ -z "${script_name}" ];then
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
LOGFILE=${LOGFOLDER}/${filename}
JSONFILE=${LOGFOLDER}/${SN}.JSON
folder="FSW"

if [ -z "${script_name}" ];then
    print_help
    exit 1
fi


main()
{
    if [ ! -z "${index}" ];then
        sw_list=${index}
        chk_pass_count=1
    else
        sw_list=`ls ${LOGFOLDER}/${folder}/`
        rusw_list=`ls ${LOGFOLDER}/RUSW/`
        chk_pass_count=${chk_Count}
    fi
    #echo "chk_list=${chk_list}"
    for loc_id in ${sw_list};
    do
        sw_session_name="${SN}-${folder}-${loc_id}"
        chk=`tmux ls | grep -c "${sw_session_name}"`
        if [ "${chk}" -ne "0" ]; then
            echo "${sw_session_name} is already alive.Kill the session"
            tmux kill-session -t ${sw_session_name}
            sleep 3
        fi
        if ! tmux new -d -s ${sw_session_name}; then
            #if [ -z "${res}" ];then
            show_fail_message "Start tmux session ${sw_session_name}"
            echo "Please make sure if install tmux well first."
        else
            show_pass_message "Start tmux session ${sw_session_name}"
        fi
        tmux set -g history-limit 3600 >/dev/null
        tmux send-keys -t ${sw_session_name} "export SN=${SN}" ENTER
        tmux send-keys -t ${sw_session_name} "source ../commonlib" ENTER
        tmux send-keys -t ${sw_session_name} "./${script_name} -i ${loc_id} -s ${SN}" ENTER
        echo "Run \" ./${script_name} -s ${SN} -i ${loc_id} \" on ${sw_session_name}"
        echo "tmux a -t ${sw_session_name}"
        sleep 1
    done

}

show_title_msg "${testitem}" | tee ${LOGFILE}
START=$(date)
cycle=0
retry=0
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

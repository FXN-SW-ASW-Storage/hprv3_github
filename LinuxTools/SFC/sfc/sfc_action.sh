#!/bin/bash
set -e # do not remove it
set -o nounset

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 100
. ../../../../lib/commonlib
. "$(dirname "${BASH_SOURCE[0]}")"/config.sh
# shellcheck disable=SC2034
VERSION=0.1

parser_definition() {
    setup REST plus:true help:usage abbr:true error:parsererror export:true -- \
    "Usage: ${2##*/} [options...] [arguments...]" ''
    msg -- "    Upload server info to SFC"
    msg -- ""
    msg -- "    1. Mount SFC share folders"
    msg -- "    2. Send_xxx for test"
    msg -- "    3. Remove .EEE .FFF .LOG"
    msg -- ""
    
    msg -- 'Options:'
    param SN -s -- "Serial Number"
    param test_stage -t -- "Test stage <L6 L10 L11>"
    param function_test -f  -- "
        Function test:
            L6:
                1. PDB          PDB broad test (for compute tray)
                2. SCM          SCM Module test (for compute tray)
                3. FIO          Front IO Board test (for compute tray)
                4. OSFP         OSFP board test (for compute tray)
                5. E1S          E1.S BP test (for compute tray)
                6. INTERPOSER   Interposer test (for compute tray)
                7. RMC          RMC broad test (for RMC tray)
            L10:
                1. INIT         Initial Test
                2. FVT          Functional Test
                3. RUNIN        Run-in test
            L11:
                1. PRETEST      Rack Level test - pre-check host status
                2. RLT          Rack Level test 
                3. FST          Rack Level test - check host status after RLT test
                4. RMC          RMC tray test
    "
    param ACTION --action -- "download/up info from SFC [up|down]"
    param RESULT --result -- "test result"
    param ERROR_CODE --error-code -- "FAIL on which test item"
    param ERROR_DESC --error-desc -- "FAIL test item description"
    disp :usage -h --help
    disp VERSION --version
    msg -- ''
    
    msg -- 'Exit code:'
    msg -- '    0   : successful'
}

send_log() {

    if [[ -f ${SFCPATH}/${ID}.* ]]; then
        rm -rf ${SFCPATH}/${ID}.*
    fi

    echo -e "${SFC_Station_ID}\n${SN}\n${OP_ID}\n${RESULT}\n${ERROR_CODE:-0}\n${ERROR_DESC:-}" > ${LOGFOLDER}/${ID}.LOG
    
    for ((x = 0; x < 3; x++)); do
        cp -rf "${LOGFOLDER}/${ID}.LOG" ${SFCPATH}
        sleep 1
        
        if [ -f ${SFCPATH}/${ID}.EEE ]; then
            show_pass_msg "Get ${SFCPATH}/${ID}.EEE"
            cp -rf ${SFCPATH}/${ID}.EEE ${LOGFOLDER}
            break
        elif [ -f ${SFCPATH}/${ID}.FFF ]; then
            show_fail_msg "Get ${SFCPATH}/${ID}.EEE"
            show_fail_message "Get ${SFCPATH}/${ID}.FFF"
            cat ${SFCPATH}/${ID}.FFF
            return 1
        elif [ $x -eq 2 ]; then
            show_fail_msg "Get ${SFCPATH}/${ID}.EEE"
            return 1
        fi
    done
}

send_AAA() {

    if [[ -f ${LOGFOLDER}/${ID}.AAA ]]; then
        rm -rf ${LOGFOLDER}/${ID}.*
        rm -rf ${SFCPATH}/${ID}.*
    fi
    
    echo -e "${SN}\n\n${OP_ID}\n${SFC_Station_ID}\n${SFC_Station_ID}" > ${LOGFOLDER}/${ID}.AAA 
    #echo -e "${SN}\n\n${OP_ID}\n${SFC_Station_ID}\n${SFC_Station_ID}\nFORCE" >${LOGFOLDER}/${ID}.AAA 
    
    for ((x = 0; x < 3; x++)); do
        cp -rf ${LOGFOLDER}/${ID}.AAA ${SFCPATH}/
        sleep 2
        
        cp -rf ${SFCPATH}/${ID}.* ${LOGFOLDER}
        
        if [ -f ${LOGFOLDER}/${ID}.BBB ]; then
            run_command cat ${LOGFOLDER}/${ID}.BBB
            show_pass_msg "Get ${ID}.BBB"
            cat -A ${LOGFOLDER}/${ID}.BBB | sed 's/\^\M\$//g' >${LOGFOLDER}/down_sfc.txt
            break
        elif [ -f ${LOGFOLDER}/${ID}.DDD ]; then
            show_fail_msg "Get ${ID}.BBB"
            show_fail_message "Get ${ID}.DDD"
            cat ${LOGFOLDER}/${ID}.DDD
            return 1
        elif [ $x -eq 2 ]; then
            show_fail_msg "Get ${LOGFOLDER}/${ID}.BBB"
            return 1
        fi
    done
}

main() {
  
    import_config "${test_stage}"

    if [ "${test_stage}" == "L6"  ]; then
        export SFC_Station_ID="FNC-CLEMENTE-BFT" 
    elif [ "${test_stage}" == "L10"  ]; then
        export SFC_Station_ID="FNC-CLEMENTE-FVT" 
    elif [ "${test_stage}" == "L11"  ]; then
        export SFC_Station_ID="FNC-CLEMENTE-L11"
    fi
 
    ID=${SFC_Station_ID}${SN}

    case ${ACTION} in
        "up")
            ## 2. send_xxx for test
            show_prompt_b "Upload result to SFC"
            send_log || return 1
            
            ## 3. remove .EEE .FFF .LOG
            #rm -rf LOGPATH/${ID}.EEE LOGPATH/${ID}.FFF LOGPATH/${ID}.LOG
            #rm -rf ${LOGFOLDER}/${ID}.FFF
        ;;
        "down")
            ## 2. Send AAA. file to SFC
            show_prompt_b "Send .AAA file to SFC"
            send_AAA || return 1
            
            ## 3. remove .AAA .BBB .DDD
            #rm -rf ${SFCPATH}/${ID}.AAA ${SFCPATH}/${ID}.BBB  ${SFCPATH}/${ID}.DDD
            #rm -rf ${LOGFOLDER}/${ID}.DDD
        ;;
        *)
            show_fail_msg "Need input --action parameter for ACTION (up/down)."
            return 1
        ;;
    esac    
}

[[ "$0" == "${BASH_SOURCE[0]}" ]] || exit 1
eval "$(getoptions parser_definition - "$0") exit 1"
main "$@"


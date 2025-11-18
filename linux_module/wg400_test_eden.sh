#!/bin/bash
source ../commonlib

base=$(basename $0)
testitem=${base%.*}
filename="${testitem}.log"
LOGFOLDER=${LOGPATH}/${SN}
JSONFILE=${LOGFOLDER}/${SN}.JSON
folder="RUSW"
LOGFILE="/usr/local/megazord_L11-FT_v1.3/linux_module/eden_wg400_test.log"

test_item()
{
    echo "-------------------"
    echo "PSU_Input_Voltage_AC Check Test"
    echo "Check the value is between 200 & 300"

    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0
    device_addr=""
    PSU_input=()

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue        
        fi

        if [[ $line =~ [[:space:]]*PSU_Input_Voltage_AC\<0x0058\>[[:space:]]*:[[:space:]]*([0-9]+\.[0-9]+)[[:space:]]* ]]; then
            volt_input="${BASH_REMATCH[1]}"
            check_input=$(echo "$volt_input >= 200 && $volt_input <= 300" | bc)

            if [[ "$check_input" -eq 1 ]]; then
                echo "PSU devece address:$device_addr | PSU Input Voltage: $volt_input PASS!"
            else
                echo "PSU devece address:$device_addr | PSU Input Voltage: $volt_input FAIL!"
            fi
            continue
        fi        
    done < "$logfile"
    
    echo "-------------------"
    echo "PSU_Output_Power Check Test"
    echo "Check the value is between 0 & 6600"

    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0
    device_addr=""
    PSU_output=()

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*PSU_Output_Power\<0x0052\>[[:space:]]*:[[:space:]]*([0-9]+\.[0-9]+)[[:space:]]* ]]; then
            power_output="${BASH_REMATCH[1]}"
            check_output=$(echo "$power_output >= 0 && $power_output <= 6600" | bc)

            if [[ "$check_output" -eq 1 ]]; then
                echo "PSU devece address:$device_addr | PSU Output Power: $power_output PASS!"
            else
                echo "PSU devece address:$device_addr | PSU Output Power: $power_output FAIL!"
            fi
            continue
        fi
    done < "$logfile"   


    echo "-------------------"
    echo "PSU_Output_Voltage Check Test"
    echo "Check the value is between 48 & 50.5"

    
    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0
    device_addr=""
    PSU_output=()

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*PSU_Output_Voltage\<0x004f\>[[:space:]]*:[[:space:]]*([0-9]+\.[0-9]+)[[:space:]]* ]]; then
            volt_output="${BASH_REMATCH[1]}"
            check_output=$(echo "$volt_output >= 48 && $volt_output <= 50.5" | bc)

            if [[ "$check_output" -eq 1 ]]; then
                echo "PSU devece address:$device_addr | PSU Output Voltage: $volt_output PASS!"
            else
                echo "PSU devece address:$device_addr | PSU Output Voltage: $volt_output FAIL!"
            fi
            continue
        fi
    done < "$logfile"
 
    echo "-------------------"
    echo "PSU General_Alarm_Status_Register Test"

    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*General_Alarm_Status_Register\<0x003c\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alarm_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | General register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | General register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\][[:space:]]*(.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"

                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alarm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"
    
    echo "-------------------"
    echo "PFC Alarm Status Register Test"
    
    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*PFC_Alarm_Status_Register\<0x003d\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alarm_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | PFC Alarm Status Register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | PFC Alarm Status Register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\][[:space:]]*(.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"

                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alarm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"

    echo "-------------------"
    echo "DCDC Alarm Status Register Test"
    
    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*DCDC_Alarm_Status_Register\<0x003e\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alarm_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | DCDC Alarm Status Register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | DCDC Alarm Status Register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\][[:space:]]*(.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"

                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alarm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"


    echo "-------------------"
    echo "Temperature_Alarm_Status_Register Test"

    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*Temperature_Alarm_Status_Register\<0x003f\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alarm_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | Temperature Alarm Status Register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | Temperature Alarm Status Register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\][[:space:]]*(.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"

                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alarm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"

    echo "-------------------"
    echo "Communication_Alarm_Status_Register Test"
    
    logfile="${LOGPATH}/M3250700004/${folder}/1/wedge400_rackmoninfo.log"
    fail_flag=0

    In_alarm_block=0
    alarm_type=1
    alarm_msg=()
    device_addr=""

    while IFS= read -r line; do
        if [[ $line =~ [[:space:]]*Device[[:space:]]*Address:[[:space:]]*(0xe[a-z0-9])[[:space:]]* ]]; then
            device_addr="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ $line =~ [[:space:]]*Communication_Alarm_Status_Register\<0x0040\>[[:space:]]* ]]; then
            In_alarm_block=1
            alarm_type=1
            alarm_msg=()
            continue
        fi

        if [[ $In_alarm_block -eq 1 ]]; then
            if [[ ! $line =~ ^[[:space:]]*\[[0-9]+\] ]]; then
                In_alarm_block=0
                if [[ $alarm_type -eq 1  ]]; then
                    echo "PSU devece address:$device_addr | Communication Alarm Status Register PASS!"
                else
                    item=$(IFS=" | "; echo"${alarm_msg[*]}")
                    echo "PSU devece address:$device_addr | Communication Alarm Status Register FAIL! | FAIL item:$item"
                fi

                continue
            fi

            if [[ $line =~ ^[[:space:]]*\[([0-9)]\][[:space:]]*(.+)  ]]; then
                code="${BASH_REMATCH[1]}"
                msg="${BASH_REMATCH[2]}"

                if [[ $code != "0" ]]; then
                    alarm_type=0
                    alarm_msg+=("$msg")
                fi
            fi
            continue
        fi
    done < "$logfile"
}


main(){
    
    local output 
    output= "eden_wg400_test.log"
    test_item | tee "$output"
    return ${PIPESTATUS[0]}
}

main | tee -a $LOGFILE
exit $?

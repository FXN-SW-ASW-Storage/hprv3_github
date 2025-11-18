#!/bin/bash
# Version       : v1.0
# Function      : Parser the PRBS31 test log.
# History       :
# 2024-11-01	| initial version

#set -x
source ../commonlib
logfile=""
standardPRBSValueCriteria=8
#standardPRBSValueCriteria=9

function print_help() {
    cat <<EOF
    Usage: $(basename $0) -f [Filename]
    Example: $(basename $0) -f /log/Diag/abc.log
EOF
}

portNum=0

while getopts f:p:t: OPT; do
    case "${OPT}" in
        "f")
            logfile=${OPTARG}
	    #echo "logfile=$logfile"
            if [ ! -f "${logfile}" ];then
		echo "Can not find log file ${logfile}. Please check the file manually first."
		exit 1
	    fi
	    ;;
        "p")
            	portNum=${OPTARG}
        ;;
	"t")
		stage=${OPTARG}
	;;
	
        *)
	    echo "Wrong Parameter..."
            print_help
	    exit 1
            ;;
    esac
done

if [ ! -f "${logfile}" ];then
	echo "Can not find log file ${logfile}. Please check the file manually first."
        print_help
        exit 1
fi

res=0
smallres=0
for ((i=1;i <= ${portNum};i++))
do
            smallres=0  
            echo "Current is checking port : ${i}"
            if [ ${stage} == "DVT" ];then 
		VaildLane=$(cat ${PORTFILE}/Port_Mapping_MP3.csv | grep "^${i}," | awk -F ',' '{print$3}' | wc -c)
            	if [ $VaildLane -eq 0 ];then
                	echo "Can't find correct port mapping number, stop the test"
                	return 1
            	else 
                	LaneStr=$(cat ${PORTFILE}/Port_Mapping_MP3.csv | grep "^${i}," | awk -F ',' '{print$3}')
                	echo "The PRBS Lane number of port ${i} are ${LaneStr}"
            	fi
            	for ((k=1;k<=2;k++))
            	do
                	LaneNum=$(echo $LaneStr | awk -F '-' '{print$'${k}'}')
                	echo "Current is check Lane ${LaneNum}"
			#echo "Pim ${pim} ; Port ${port} ; Check Number=${chkvalue}"
			chkcount=`cat ${logfile} | grep -aiw "${LaneNum}\[.\]" | grep -aic "e-"`
			#echo "chkcount=cat ${logfile} | grep -i \"${chkvalue}\[.\]\" | grep -ic \"\e-\""
    			if [ "${chkcount}" -ne "4" ];then
				#echo "Pim:${pim} Port:${port} ----------- [FAIL]"
				cat ${logfile} | grep -aiw "${chkvalue}\[.\]"
				echo "Count=${chkcount};Can't find 4 values matching ${LaneNum}[.] ###e-## format."
				let res+=1
				let smallres+=1
				continue
			fi
			    #or ((port=0;port < 48; port++))
			for ((m=0;m < 4; m++))
			do
				value=`cat ${logfile} | grep -aiw "${LaneNum}\[${m}\]" | awk -F 'e-' '{print $2}' | tr -d '[:cntrl:]'`
				    #echo "value=${value}"
				if [ "${value}" -lt "${standardPRBSValueCriteria}" ];then
					    #echo "Pim:${pim} Port:${port} ----------- [FAIL]"
					cat ${logfile} | grep -aiw "${chkvalue}\[.\]"
					echo "Not all value less then ###e-0${standardPRBSValueCriteria}"
					let res+=1
					let smallres+=1
				fi
			done
		done
	    elif [ ${stage} == "PVT" ];then
		if [ ${i} -lt 33 ];then
  			case $i in	
				4|8|12|16|20|24|28|32) continue ;;
  			esac
  			
	
			VaildLane=$(cat ${PORTFILE}/Port_Mapping_MP3.csv | grep "^${i}," | awk -F ',' '{print$3}' | wc -c)
                	if [ $VaildLane -eq 0 ];then
                        	echo "Can't find correct port mapping number, stop the test"
                        	return 1
                	else
                        	LaneStr=$(cat ${PORTFILE}/Port_Mapping_MP3.csv | grep "^${i}," | awk -F ',' '{print$3}')
                        	echo "The PRBS Lane number of port ${i} are ${LaneStr}"
                	fi
                	for ((k=1;k<=2;k++))
                	do
                        LaneNum=$(echo $LaneStr | awk -F '-' '{print$'${k}'}')
                        echo "Current is check Lane ${LaneNum}"
                        #echo "Pim ${pim} ; Port ${port} ; Check Number=${chkvalue}"
                        chkcount=`cat ${logfile} | grep -aiw "${LaneNum}\[.\]" | grep -aic "e-"`
                        #echo "chkcount=cat ${logfile} | grep -i \"${chkvalue}\[.\]\" | grep -ic \"\e-\""
                        if [ "${chkcount}" -ne "4" ];then
                                #echo "Pim:${pim} Port:${port} ----------- [FAIL]"
                                cat ${logfile} | grep -aiw "${chkvalue}\[.\]"                                echo "Count=${chkcount};Can't find 4 values matching ${LaneNum}[.] ###e-## format."
                                let res+=1
                                let smallres+=1
                                continue
                        fi
                            #or ((port=0;port < 48; port++))
                        for ((m=0;m < 4; m++))
                        do                                value=`cat ${logfile} | grep -aiw "${LaneNum}\[${m}\]" | awk -F 'e-' '{print $2}' | tr -d '[:cntrl:]'`
                                    #echo "value=${value}"
                                if [ "${value}" -lt "${standardPRBSValueCriteria}" ];then
                                            #echo "Pim:${pim} Port:${port} ----------- [FAIL]"
                                        cat ${logfile} | grep -aiw "${chkvalue}\[.\]"
                                        echo "Not all value less then ###e-0${standardPRBSValueCriteria}"
                                        let res+=1
                                        let smallres+=1
                                fi      
                        done
                done
		else
			VaildLane=$(cat ${PORTFILE}/Port_Mapping_MP3.csv | grep "^${i}," | awk -F ',' '{print$3}' | wc -c)
                        if [ $VaildLane -eq 1 ];then
                                echo "Can find correct port mapping number, but it should not include the cable"
                                return 1
                        fi
		fi
	    else
		echo "Can't get correct stage, stop the test"
		exit 1
	    fi
		    if [ $smallres -eq 0 ];then
			echo "The Port ${i} is pass PRBS31, continue other ports"
		    else
			echo "The Port ${i} is fail PRBS31, continue to check other ports"
			exit 1
		    fi
done
if [ "${res}" -ne "0" ];then
	echo "PRBS31 Test ----------- [FAIL]"
	exit 1
else
	echo "PRBS31 Test ----------- [PASS]"
	exit 0
fi

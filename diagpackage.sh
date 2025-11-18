#!/bin/bash

#***********************************************************************************
## PROJECT       : COMMON
## Filename      : diagpackage.sh
## Creator       : Brian Wang
## Creation Site : TPE
## Creation Date : 2016-05-26
## Description   : This script is used for packing FT tool and erasing relative ini files.
## Usage         : upload diagpackage.sh and newversion files in /usr/local/Foxconn .
##                 Remember using chmod command to change file permissions.
##                 Edit the newversion file for project/phase/type name.
##                 After running it , it package the Diag. program in /usr/local/
##   
## Copyright (c) 2016-2020 Foxconn IND., Group. All Rights Reserved
##
## Version History
##-------------------------------
## Version       : 1.1
## Release Date  : 2017-03-14
## Revised by    : Donny Wang
## Description   : remove to encrypt check_list and chk_tool scripts.
##-------------------------------
## Version       : 1.0
## Release Date  : 2016-05-26
## Revised by    : Brian Wang
## Description   : Preliminary release
##
#*************************************************************************************/

TIME_STAMP=`date "+%Y%m%d"`
ROOT_DIR=`pwd`
REF_FILE="newversion"
BACKUP_DIR=""
BASEDIR=$(dirname "$0")

readonly PREFIX_TEST_PROGRAM="TestProgram"

cd ${ROOT_DIR}
if [ -f ${REF_FILE} ]; then
	PROJECT_NAME=`grep "Project=" ${REF_FILE} | awk 'BEGIN {FS="="}; {print $2}'`
	PHASE=`grep "Phase=" ${REF_FILE} | awk 'BEGIN {FS="="}; {print $2}'`
	TYPE=`grep "Type=" ${REF_FILE} | awk 'BEGIN {FS="="}; {print $2}'`
	VERSION=`grep "Version=" ${REF_FILE} | awk 'BEGIN {FS="="}; {print $2}'`
fi

if [ -z ${PROJECT_NAME} ]; then
	echo -e 'Prject Name is NULL'
	exit 1
fi

if [ -z ${PHASE} ]; then
	echo -e 'Phase is NULL'
	exit 2
fi

if [ -z ${TYPE} ]; then
	echo -e 'Type is NULL'
	exit 3
fi

if [ -z ${VERSION} ]; then
	echo -e 'Version is NULL'
	exit 4
fi

BACKUP_DIR=${PROJECT_NAME}-${PHASE}-${TYPE}-${PREFIX_TEST_PROGRAM}-${VERSION}-${TIME_STAMP}

cd ..

mkdir -p ${BACKUP_DIR}

cd -
#echo -e 'Copying to temp folder...'
cp -r ${BASEDIR}/* ../${BACKUP_DIR}/

#echo -e 'Copy Finished. Start removing ini and log...'
cd ..

#rm -rf ${BACKUP_DIR}/l10tool/*
#rm -rf ${BACKUP_DIR}/ini/*
#rm -rf ${BACKUP_DIR}/DiagCaptor/ini/*
#rm -rf ${BACKUP_DIR}/DiagCaptor/data/*
#rm -rf ${BACKUP_DIR}/log/diag/*
#rm -rf ${BACKUP_DIR}/log/CRC/*
#rm -rf ${BACKUP_DIR}/log/sfp/*
rm -rf ${BACKUP_DIR}/log/*

#rm -rf ${BACKUP_DIR}/DiagCaptor/log/*
#rm -rf ${BACKUP_DIR}/*.*doc
#rm -rf ${BACKUP_DIR}/*.*xls

#pwd
#mkdir -p ../${BACKUP_DIR}/log/{CRC,diag,sfp}

#echo -e 'Encoding...'
#cd ${BACKUP_DIR}/config/COMMON/encode
#./encode-shc ../burn/dmiburn
#./encode-shc ../burn/fruburn
#./encode-shc ../../process/linux_module/check_list
#./encode-shc ../../process/linux_module/chk_tool
#./encode-shc ../../process/linux_module/cpu_config
#cd ../..

cd ${BACKUP_DIR}

#echo -e 'Archiving...'
tar jcvf ${BACKUP_DIR}.tar.bz2 *
mv ${BACKUP_DIR}.tar.bz2 ../
cd ..
rm -rf ${BACKUP_DIR}
#echo -e 'Done'


exit 0

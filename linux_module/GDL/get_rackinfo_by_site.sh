#!/bin/bash

 curl --location --request POST '10.1.89.12/MES/api?apiKey=rYnfDoeKPRVc5si1Jm5RoOgBy' \
	--header 'Content-Type: application/x-www-form-urlencoded' \
	--data-urlencode 'type=getRLTJson' \
	--data-urlencode 'cust=MS' \
	--data-urlencode 'param1='$1'' \
	--data-urlencode 'format=true' \
	--data-urlencode 'withContainer=false' > ${1}.JSON
	

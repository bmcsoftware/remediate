#!/bin/nsh

# v0.0.1
# This script is designed to find a patch analysis job, then for each
# target in the job, generate a patch deployment job.
# 
# Use as is, free to redistribute, and no Warranty or support will be provided.
#
# Call this script with the following parameters:
#   $1  Region (ex: America)
#   $2  DataCenterName (ex: DC.FL_LAB)
#   $3  OS (ex: RHEL)
#

if [ "$#" != 3 ]
then 
  echo "Usage: nsh $0 Region DataCenterName OS"
  exit 1
fi

# Set the DEBUG variable to false to print out all debug statements
DEBUG=true
# Folder (group) containing Patch Analysis job
JOB_FOLDER="/UNIX Patching/DATA CENTERS/$1/$2/Analysis Jobs/$3" 
# Name of the Patch Analysis job
JOB_NAME="$3 Security Patch Analysis-$2"
# Name of the job group where the new job is going to be saved. 
JOB_GROUP_NAME="/UNIX Patching/DATA CENTERS/$1/$2/Deploy Jobs/$3"
# Name of the job group where the generated Deploy Job(s) and Batch Job is going to be saved. 
DEPLOY_JOB_GROUP_NAME="/UNIX Patching/DATA CENTERS/$1/$2/Deploy Jobs/$3"
# Name of the depot group where the new package is going to be saved. 
DEPOT_GROUP_NAME="/UNIX Patching/Data Center Objects - Remediation Items (Deploy Jobs)/$2/$3"
# Remediation Template.  This Patch Remediation Job should contain the right
# ACL Policy and deploy options.
TEMPLATE_JOB_NAME="$2-Deploy Job Template"
TEMPLATE_JOB_GROUP="/UNIX Patching/DATA CENTERS/$1/$2/Deploy Jobs/$3/Deploy Job Template"
PWD=`pwd`
DEP_FILE="${PWD}/dep.out"
RUNNING_HOST=`echo $HOST`
TMP_FILE="c:\\Temp\\dep.out"
RUNNING_HOST_TMP_FILE="//${RUNNING_HOST}/Temp/dep.out"

echo
echo "JOB_FOLDER is: "
echo $JOB_FOLDER
echo
echo "JOB_NAME is: "
echo $JOB_NAME
echo
echo "JOB_GROUP_NAME is: "
echo $JOB_GROUP_NAME
echo
echo "DEPLOY_JOB_GROUP_NAME is: "
echo $DEPLOY_JOB_GROUP_NAME
echo
echo "DEPOT_GROUP_NAME is: "
echo $DEPOT_GROUP_NAME
echo
echo "TEMPLATE_JOB_NAME is: "
echo $TEMPLATE_JOB_NAME
echo
echo "TEMPLATE_JOB_GROUP is: "
echo $TEMPLATE_JOB_GROUP
echo

echo "RUNNING_HOST=$RUNNING_HOST"


print_debug()
{
	if [ "${DEBUG}" = "true" ]
		then
		echo " "
		echo "DEBUG: $@"
	fi
}

print_info()
{
	echo " "
	echo "INFO: $@"
}

check_errs()
{
  # Function. Parameter 1 is the return code
  # Para. 2 is text to display on failure.
  if [ "${1}" -ne "0" ]; then
    echo "ERROR # ${1} : ${2}"
    # as a bonus, make our script exit with the right error code.
    exit ${1}
  fi
}

gen_patch_job()
{
	TODAY=`date +%Y%m%d%H%M`
	# Specify prefix to be used in package name. 
	PKG_PREFIX="${1}_${3}" 
	# Get Patching Job DBKey by job group name and job name. 
	PA_JOB_RUNKEY="$2"
	# Name of the new job. 
	REMEDIATION_JOB_NAME="${1}_Remediation_${TODAY}" 

	print_debug "blcli_execute PatchRemediationJob createRemediationJobWithDeployOptsForATarget" "$REMEDIATION_JOB_NAME" "$JOB_GROUP_NAME" "$PA_JOB_RUNKEY" "$1" "$PKG_PREFIX" "$DEPOT_GROUP_NAME" "$DEPLOY_JOB_GROUP_NAME" "$4"
	blcli_execute PatchRemediationJob createRemediationJobWithDeployOptsForATarget "$REMEDIATION_JOB_NAME" "$JOB_GROUP_NAME" "$PA_JOB_RUNKEY" "$1" "$PKG_PREFIX" "$DEPOT_GROUP_NAME" "$DEPLOY_JOB_GROUP_NAME" "$4"
	check_errs $? "BLCLI ERROR"
	blcli_storeenv DB_KEY
    print_info "Generated Patch Remediation Jobs for $1"
	
	blcli_execute PatchRemediationJob executeJobAndWait "$DB_KEY"
	check_errs $? "BLCLI ERROR"
	blcli_storeenv JRUN_KEY

	# Set the ACL on the DEPLOY_JOB_GROUP_NAME (where deploy jobs are stored)
	blcli_execute JobGroup applyAclPolicy "$DEPLOY_JOB_GROUP_NAME" "$5"
	check_errs $? "BLCLI ERROR"
	
	# Now check out the Job run result
	blcli_execute JobRun jobRunKeyToJobRunId "$JRUN_KEY"
	check_errs $? "BLCLI ERROR"
	blcli_storeenv JRUN_ID

	`sleep 5`
	
	blcli_execute JobRun getLogItemsByJobRunId "$DB_KEY" "$JRUN_ID" 
	check_errs $? "BLCLI ERROR"
	blcli_storeenv ITEMLOG
	print_debug "$ITEMLOG"
	
	# parse the log to find the package and deploy job to apply acl policy
	ITEMLOG=`echo $ITEMLOG | sed 's/Type: Info Date:/:/g'`
	print_debug "$ITEMLOG"
	
	# find the pkg create (this is for Linux, need to test out for Solaris, HPUX, and and AIX
	CREATED_PKG=`echo $ITEMLOG | awk '{split($0,a,":"); for (i in a) if (a[i] == " Created BlPackage") print a[i+1]}'`
	#trim the front and end spaces
	CREATED_PKG=`echo $CREATED_PKG | awk '{i=split($0,a,"/"); print a[i]}'`
	# find the deploy job
	CREATED_DPJOB=`echo $ITEMLOG | awk '{split($0,a,":"); for (i in a) if (a[i] == " Created deploy job") print a[i+1]}'`
	CREATED_DPJOB=`echo $CREATED_DPJOB | awk '{i=split($0,a,"/"); print a[i]}'`
	print_debug "PKG=$CREATED_PKG"
	print_debug "DPJOB=$CREATED_DPJOB"
	
	# ONLY Proceed if deploy job created
	if [ -n "$CREATED_DPJOB" ] 
	then
		#Apply ACL policy on Package
		blcli_execute BlPackage getDBKeyByGroupAndName "$DEPOT_GROUP_NAME" "$CREATED_PKG"
		check_errs $? "BLCLI ERROR"
		blcli_storeenv DEPOT_KEY

		blcli_execute DepotObject applyAclPolicy "$DEPOT_KEY" "$5"
		check_errs $? "BLCLI ERROR"
	
		#Apply ACL to the deploy job, we'll not apply ACL to the batch job because the batch is useless
		blcli_execute DeployJob getDBKeyByGroupAndName "$DEPLOY_JOB_GROUP_NAME" "$CREATED_DPJOB"
		check_errs $? "BLCLI ERROR"
		blcli_storeenv DPJOB_KEY
	
		blcli_execute Job applyAclPolicy "$DPJOB_KEY" "$5"
		check_errs $? "BLCLI ERROR"
		
		# Find and REMOVE the Batch Job because it's useless
		blcli_execute Utility exportDependencyGraph DEPLOY_JOB "$DEPLOY_JOB_GROUP_NAME" "$CREATED_DPJOB" "$TMP_FILE" true 0
		check_errs $? "BLCLI ERROR"
		`cp $RUNNING_HOST_TMP_FILE $DEP_FILE`
		BATCH_JOB=`awk 'END{print}' ${DEP_FILE} | awk '{split($0,a,","); print a[1]}'`
		BATCH_JOB=`echo $BATCH_JOB | sed 's/\"//g'`
		echo "deleting=$BATCH_JOB"
		blcli_execute BatchJob deleteJobByGroupAndName "$DEPLOY_JOB_GROUP_NAME" "$BATCH_JOB"		
		
		# if this is Linux, we need to apply ACL on the custom package as well.
		blcli_execute Server printPropertyValue "${1}" "OS"
		blcli_storeenv OS_TYPE
		if [ "${OS_TYPE}" = "Linux" ]
		then
			blcli_execute Utility exportDependencyGraph DEPLOY_JOB "$DEPLOY_JOB_GROUP_NAME" "$CREATED_DPJOB" "$TMP_FILE" false 0
			`cp $RUNNING_HOST_TMP_FILE $DEP_FILE`
			check_errs $? "BLCLI ERROR"
			blcli_storeenv CUSTOM_PKG
			CUSTOM_PKG=`grep "_Remediation_" ${DEP_FILE} | awk '{split($0,a,","); print a[1]}'`
			CUSTOM_PKG=`echo $CUSTOM_PKG | sed 's/\"//g'`
			echo "CustomPKG=$CUSTOM_PKG"	
			echo "GROUP=$DEPOT_GROUP_NAME"
			
			blcli_execute DepotObject getDBKeyByTypeStringGroupAndName "CUSTOM_SOFTWARE_INSTALLABLE" "$DEPOT_GROUP_NAME" "$CUSTOM_PKG"
			check_errs $? "BLCLI ERROR"
			blcli_storeenv DEPOT_KEY

			blcli_execute DepotObject applyAclPolicy "$DEPOT_KEY" "$5"
			check_errs $? "BLCLI ERROR"										
		fi
		print_info "Patch Package and Deploy Job generated."
	fi
    return 0
}


#Main script
#######################################
# Initialize BLCLI
print_info "$TODAY"
print_info "Initialize BLCLI"
print_debug "blcli_disconnect"
blcli_disconnect
check_errs $? "BLCLI ERROR"
print_debug "blcli_init"
blcli_init
check_errs $? "BLCLI ERROR"
print_debug "blcli_setoption roleName BLAdmins"
blcli_setoption roleName BLAdmins
blcli_setoption serviceProfileName defaultProfile
#blcli_setoption serviceProfileName SOTA_SRP
check_errs $? "BLCLI ERROR"
print_debug "blcli_connect"
blcli_connect
check_errs $? "BLCLI ERROR"

# strip off the suffix as ACL Policy
ACL_POLICY=`echo $JOB_NAME | awk '{split($0,a,"-"); print a[2]}'`
print_debug "$ACL_POLICY"
# make the Remediation Job based on the analysis job
REM_JOB_NAME=`echo $JOB_NAME | sed 's/Analysis/Deploy/g'`
print_debug "$REM_JOB_NAME"

# get the remediation template job key
print_debug "blcli_execute PatchRemediationJob getDBKeyByGroupAndName $TEMPLATE_JOB_GROUP $TEMPLATE_JOB_NAME"
blcli_execute DeployJob getDBKeyByGroupAndName "$TEMPLATE_JOB_GROUP" "$TEMPLATE_JOB_NAME"
check_errs $? "BLCLI ERROR"
blcli_storeenv TEMPLATE_JOB_KEY
#print_debug "JOB_KEY: $TEMPLATE_JOB_KEY"


# get the patch analysis job key
print_debug "blcli_execute PatchingJob getDBKeyByGroupAndName $JOB_FOLDER $JOB_NAME"
blcli_execute PatchingJob getDBKeyByGroupAndName "$JOB_FOLDER" "$JOB_NAME"
check_errs $? "BLCLI ERROR"
blcli_storeenv JOB_KEY
print_debug "JOB_KEY: $JOB_KEY"

# get the last job run key
blcli_execute JobRun findLastRunKeyByJobKey $JOB_KEY
check_errs $? "BLCLI ERROR"
blcli_storeenv JOB_RUN_KEY
print_debug "JOB_RUN_KEY: $JOB_RUN_KEY"

#get the target list
blcli_execute Job getTargetServers $JOB_KEY "ENROLLED"
check_errs $? "BLCLI ERROR"
blcli_storeenv TARGETS
# strip the bracket from [...]
TARGETS=`echo $TARGETS | awk  -F'.' '{print substr($0, 2, length()-2)}'`
TARGETS=`echo $TARGETS | sed 's/\,//g'`
print_debug "TARGETS: $TARGETS"

# Iterate through the TARGET in TARGETS.
for TARGET in ${TARGETS}
	do
		print_debug "TARGET=$TARGET"
		# make sure the target server exist, else don't bother
		blcli_execute Server serverExists "$TARGET"
		check_errs $? "BLCLI ERROR"
		blcli_storeenv SERVER_EXIST

		if [ "${SERVER_EXIST}" = "true" ]
		then
			gen_patch_job "$TARGET" "$JOB_RUN_KEY" "$REM_JOB_NAME" "$TEMPLATE_JOB_KEY" "$ACL_POLICY"
		fi
	done	
echo "Script Complete."
print_debug "blcli_destroy"
blcli_destroy
check_errs $? "BLCLI ERROR"

exit 0

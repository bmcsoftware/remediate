#!/bin/nsh
zmodload zsh/datetime
blcli_setjvmoption -Dcom.bladelogic.cli.execute.quietmode.enabled=true
blcli_setoption serviceProfileName defaultProfile
blcli_setoption roleName BLAdmins
blcli_connect

createNSHJobWithParams()
{
    local jobGroup="${1}"
    local jobName="${2}"
    local executionMode="${3}"
    local objectType="${4}"
    local retention="${5}"
    local duration="${6}"

    createNSHJob "${jobGroup}" "${jobName}" "${jobName}" "${cleanupScript%/*}" "${cleanupScript##*/}"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 0 "${executionMode}"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 1 "NONE"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 2 "${duration}"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 3 "NONE"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 4 "${retention}"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 5 "${objectType}"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 6 "NONE"
    setNSHScriptJobParameter "${jobGroup}" "${jobName}" 8 "NONE"

}

createNSHJob()
{
    local jobGroup="${1}"
    local jobName="${2}"
    local description="${3}"
    local scriptGroup="${4}"
    local scriptName="${5}"
    local parallel=0
    
    echo "Creating ${jobGroup}/${jobName}..."
    blcli_execute NSHScriptJob createNSHScriptJob "${jobGroup}" "${jobName}" "${description}" "${scriptGroup}" "${scriptName}" "${parallel}"
}

setNSHScriptJobParameter()
{
    local jobGroup="${1}"
    local jobName="${2}"
    local paramIndex="${3}"
    local paramValue="${4}"
    
    if [[ "${paramValue}" = "NONE" ]]
        then
        echo "Setting ${paramIndex} to skip..."
        blcli_execute NSHScriptJob addNSHScriptParameterOptionByGroupAndName "${jobGroup}" "${jobName}" ${paramIndex} "true" "true"
    else
        echo "Setting ${paramIndex} to ${paramValue}..."
        blcli_execute NSHScriptJob addNSHScriptParameterOptionByGroupAndName "${jobGroup}" "${jobName}" ${paramIndex} "false" "false"
        blcli_execute NSHScriptJob addNSHScriptParameterValueByGroupAndName "${jobGroup}" "${jobName}" ${paramIndex} "${paramValue}"
    fi
}

checkObjectsExist()
{
    echo "Checkign for DepotGroup ${cleanupScript%/*}..."
    blcli_execute DepotGroup groupExists "${cleanupScript%/*}"
    blcli_storeenv depotGroupExists
    if [[ "${depotGroupExists}" = "false" ]]
        then
        echo "Cannot find Depot Group: ${cleanupScript%/*}"
        exit 1
    fi
    echo "Checking for NSHScript ${cleanupScript}..."
    blcli_execute DepotObject depotObjectExistsByTypeStringGroupAndName NSHSCRIPT "${cleanupScript%/*}" "${cleanupScript##*/}"
    blcli_storeenv scriptExists
    if [[ "${scriptExists}" = "false" ]]
        then
        echo "Cannot find NSHScript: ${cleanupScript}"
        exit 1
    fi
    

    for i in "${parentJobGroup}" "${cleanupJobGroup}" "${memberJobGroup}"
        do
        echo "Checking for JobGroup ${i}..."
        blcli_execute JobGroup groupExists "${i}"
        blcli_storeenv jobGroupExists
        if [[ "${jobGroupExists}" = "false" ]]
            then
            echo "Creating ${i}..."
            blcli_execute JobGroup createGroupWithParentName "${i##*/}" "${i%/*}"
        fi
    done
}

parentJobGroup="/BMC Maintenance/${EPOCHSECONDS}"
cleanupJobGroup="${parentJobGroup}/Database Cleanup Jobs"
memberJobGroup="${cleanupJobGroup}/Member Jobs"

cleanupScript="/BMC Maintenance/BSA Recommended Database Cleanup Script"
defaultRetention=14
defaultDuration=720
typeset -a jobTypes
typeset -A executionMode
typeset -A objType
typeset -A retentionTime
typeset -A durationTime
jobTypes=(Retention JobRunEvent AuditTrail JobSchedule SnapshotResult AuditResult ComplianceResult Deploy PatchResult SharedData OldVersionJob OldVersionComponent CleanupDatabase HardDeleteAllSharedObjects FileServer AppServerCache)
executionMode=(Retention RETENTION JobRunEvent HISTORY_ORDR AuditTrail HISTORY_ORDR JobSchedule HISTORY_ORDR SnapshotResult HISTORY_ORDR AuditResult HISTORY_ORDR ComplianceResult HISTORY_ORDR Deploy HISTORY_ORDR PatchResult HISTORY_ORDR SharedData HISTORY_ORDR OldVersionJob HISTORY_ORDR OldVersionComponent HISTORY_ORDR CleanupDatabase CLEAN_DB HardDeleteAllSharedObjects CLEAN_SHARED_OBJECTS FileServer CLEAN_FS AppServerCache CLEAN_ALL_AS)
objType=(JobRunEvent JobRunEvent AuditTrail AuditTrail JobSchedule JobSchedule SnapshotResult SnapshotResult AuditResult AuditResult ComplianceResult ComplianceResult Deploy Deploy PatchResult PatchResult SharedData SharedData OldVersionJob OldVersionJob OldVersionComponent OldVersionComponent)
retentionTime=(JobRunEvent ${defaultRetention} AuditTrail ${defaultRetention} JobSchedule ${defaultRetention} AppServerCache ${defaultRetention})
durationTime=(CleanupDatabase ${defaultDuration} HardDeleteAllSharedObjects ${defaultDuration}) 


checkObjectsExist

for i in ${jobTypes}
    do
    echo "Creating job for ${i}..."
    createNSHJobWithParams "${memberJobGroup}" "Cleanup - ${i}" "${executionMode[${i}]}" "${objType[${i}]:-NONE}" "${retentionTime[${i}]:-NONE}" "${durationTime[${i}]:-NONE}" 
done


blcli_execute JobGroup groupNameToId "${memberJobGroup}"
blcli_storeenv memberGroupId
blcli_execute JobGroup groupNameToId "${cleanupJobGroup}"
blcli_storeenv cleanupGroupId

# Create the daily jobs
# cleanup historical parallel
echo "Creating cleanupHistorical Batch Job..."
j=0
for i in JobRunEvent JobSchedule AuditTrail
    do
    blcli_execute NSHScriptJob getDBKeyByGroupAndName "${memberJobGroup}" "Cleanup - ${i}"
    blcli_storeenv nshJobKey
    
    if [[ ${j} -eq 0 ]]
        then
        blcli_execute BatchJob createBatchJob "Cleanup - CleanupHistoricalData" ${memberGroupId} ${nshJobKey} true true false true
        blcli_storeenv parallelKey
        let j+=1
    else
        blcli_execute BatchJob addMemberJobByJobKey ${parallelKey} ${nshJobKey}
        blcli_storeenv parallelKey
    fi
done


# cleanup historical sequential
echo "Creating cleanupHistorical Result Batch Job..."
j=0
for i in SnapshotResult AuditResult ComplianceResult Deploy PatchResult SharedData OldVersionJob OldVersionComponent
    do
    blcli_execute NSHScriptJob getDBKeyByGroupAndName "${memberJobGroup}" "Cleanup - ${i}"
    blcli_storeenv nshJobKey
    if [[ ${j} -eq 0 ]]
        then
        blcli_execute BatchJob createBatchJob "Cleanup - Results" ${memberGroupId} ${nshJobKey} true true false false
        blcli_storeenv seqKey
        let j+=1
    else   
        blcli_execute BatchJob addMemberJobByJobKey ${seqKey} ${nshJobKey}
        blcli_storeenv seqKey
    fi
done

# make the daily job
echo "Creating the Daily Batch Job..."
blcli_execute NSHScriptJob getDBKeyByGroupAndName "${memberJobGroup}" "Cleanup - Retention"
blcli_storeenv nshJobKey

blcli_execute BatchJob createBatchJob "Cleanup - Daily" ${cleanupGroupId} ${nshJobKey} true true false false
blcli_storeenv dailyKey


blcli_execute BatchJob addMemberJobByJobKey ${dailyKey} ${parallelKey}
blcli_storeenv dailyKey
blcli_execute BatchJob addMemberJobByJobKey ${dailyKey} ${seqKey}
blcli_storeenv dailyKey
blcli_execute NSHScriptJob getDBKeyByGroupAndName "${memberJobGroup}" "Cleanup - AppServerCache"
blcli_storeenv nshJobKey
blcli_execute BatchJob addMemberJobByJobKey ${dailyKey} ${nshJobKey}
blcli_storeenv dailyKey

blcli_execute Job addWeeklySchedule ${dailyKey} "$(date +%Y-%m-%d) 01:00:00" 63 1

echo "Creating the Weekly Batch Job..."

j=0
for i in Retention CleanupDatabase HardDeleteAllSharedObjects FileServer
    do
    blcli_execute NSHScriptJob getDBKeyByGroupAndName "${memberJobGroup}" "Cleanup - ${i}"
    blcli_storeenv nshJobKey
    if [[ ${j} -eq 0 ]]
        then
        blcli_execute BatchJob createBatchJob "Cleanup - Weekly" ${cleanupGroupId} ${nshJobKey} true true false false
        blcli_storeenv weeklyKey
        let j+=1
    else
        blcli_execute BatchJob addMemberJobByJobKey ${weeklyKey} ${nshJobKey}
        blcli_storeenv weeklyKey
    fi
done
blcli_execute Job addWeeklySchedule ${weeklyKey} "$(date +%Y-%m-%d) 01:00:00" 64 1


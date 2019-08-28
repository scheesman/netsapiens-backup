#!/bin/bash
# Backs up NetSapiens files based on the article located at https://help.netsapiens.com/hc/en-us/articles/205235690-What-Commands-Should-I-Execute-For-Scheduled-Backups-
#
# Usage - Save file, set nsbackup.conf as needed, and call with the modules that needed to be backed up.
# ie: nsbackup.sh core cdr conference

source nsbackup.conf

################################################################################
########### Nothing to edit in this file.  All options are defined    ##########
########### in the nsbackup.conf file.  A sample file is provided in  ##########
########### nsbackup.conf.sample.  Simply copy it to nsbackup.conf    ##########
################################################################################

# Set default file permissions
 umask 177

# Define error message for modular display of errors
errmsg=$"
Usage: \e[92m$0 [services]\e[39m

Example: \e[92m$0 core,cdr,messaging\e[39m
will back up the core, cdr, and messaging services

Valid services:
  \e[92mcore
  cdr
  cdr2
  cdr2last
  messaging
  conference
  ndp
  ndpfiles
  recording\e[39m"

# Begin runtime

echo -e "\e[96mNetsapiens Backup Script\e[39m"
echo -e "\e[96mSean Cheesman - https://github.com/scheesman\e[39m"
echo -e ""

# Set bucket variable to s3bucket variable value if bucket is blank. s3bucket was previous option but the addition of
# other storage options required detatching the bucket definition from the S3 product.

if [[ "$bucket" = "" ]]
then
    if [[ "$s3bucket" = "" ]]
        then
            echo -e "\e[91mError: Bucket name not set\e[39m"
            $logmsg "Error: Bucket name not set"
        exit
    fi

    bucket=${s3bucket}
    echo $bucket
fi

# Error out if db user is not set
if [ "$user" = "" ]
then
    echo -e "\e[91mError: DB user not set\e[39m"
    $logmsg "Error: DB user not set"
    exit
fi

# Error out if db password is not set
if [ "$password" = "" ]
then
    echo -e "\e[91mError: DB password not set\e[39m"
    $logmsg "Error: DB password not set"
    exit
fi

# Error out if storage option not set
if [ "$storage" = "" ]
then
    echo -e "\e[91mError: Storage method not set\e[39m"
    $logmsg "Error: Storage method not set"
    exit
fi


echo -e "\e[92mInfo: Beginning backup\e[39m"
$logmsg "Info: Beginning backup"
echo -e ""

# Set Google Storage variables for processing
if [ "$storage" = "gs" ]
then
    storageName="Google Cloud Storage"
    echo -e "\e[92mStorage option set to \e[92m${storageName}\e[39m"
    $logmsg "Info: Storage Option set to ${storageName}"
    backup() {
    gsutil cp ${backup_path}/$1 gs://${bucket}/${hostname}/
    if [[ "$?" = "0" ]]
    then
        echo -e "\e[92mInfo: File uploaded successfully to ${storageName}\e[39m"
        $logmsg "Info: File uploaded successfully to ${storageName}"
    else
        echo -e "\e[91mError: Problem uploading file to ${storageName}\e[39m"
        $logmsg "Error: Problem uploading file to ${storageName}"
    fi
    rm ${backup_path}/$1
    }
fi

# Set Amazon S3 variables for processing
if [ "$storage" = "s3" ]
then
    storageName="Amazon S3"
    echo -e "\e[92mStorage option set to \e[92m${storageName}\e[39m"
    $logmsg "Info: Storage Option set to ${storageName}"

    # Error out if Amazon S3 config file location is not set
    if [ "$s3cfg" = "" ]
    then
        echo -e "\e[91mError: .s3cfg location not set\e[39m"
        $logmsg "Error: .s3cfg location not set"
        exit
    fi
    backup() {
    s3cmd -c ${s3cfg} put ${backup_path}/$1 s3://${bucket}/${hostname}/
    if [[ "$?" = "0" ]]
    then
        echo -e "\e[92mInfo: File uploaded successfully to ${storageName}\e[39m"
        $logmsg "Info: File uploaded successfully to ${storageName}"
    else
        echo -e "\e[91mError: Problem uploading file to ${storageName}\e[39m"
        $logmsg "Error: Problem uploading file to ${storageName}"
    fi
    rm ${backup_path}/$1
    }
fi


# Error out if no CLI options provided and display CLI options
if [ $# -lt 1 ]
then
    echo -e "$errmsg"
    exit
fi

# Loop through all command line options
while [ $# -gt 0 ]; do

  # Perform action based on command line options

  case "$1" in
    core)
      infile="sipbxdomain_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Core Module Config to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Core Module Config to ${outfile} and moving to ${storageName}"
      mysqldump SiPbxDomain --user=${user} --password=${password} --compact --ignore-table=SiPbxDomain.cdr --ignore-table=SiPbxDomain.subscriber_cdr --ignore-table=SiPbxDomain.audit_log --ignore-table=SiPbxDomain.callqueue_stat_cdr_helper --ignore-table=SiPbxDomain.filejournal --ignore-table=SiPbxDomain.time_zone_transition --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    cdr)
      infile="sipbxdomain-cdr_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Core Module CDRs (25 hours) to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Core Module CDRs (25 hours) to ${outfile} and moving to ${storageName}"
      mysqldump SiPbxDomain cdr --user=${user} --password=${password}  --insert-ignore --where='cdr.time_release > DATE_SUB( UTC_TIMESTAMP( ) , INTERVAL 25 HOUR )' --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    cdr2last)
      cdr2last=`date -d "$(date +%Y-%m-1) -1 month" +%Y%m`
      infile="cdrdomain-cdr2last_${hostname}_${cdr2last}.sql"
      outfile="${infile}.gz"
      echo "Backing up previous month's CDR2 to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up previous month's CDR2 to ${outfile} and moving to ${storageName}"
      mysqldump CdrDomain ${cdr2last}_d ${cdr2last}_g ${cdr2last}_m ${cdr2last}_r ${cdr2last}_u --user=${user} --password=${password} --insert-ignore --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    cdr2)
      cdr2current=$(date +"%Y%m")
      infile="cdrdomain-cdr2_${hostname}_${cdr2current}.sql"
      outfile="${infile}.gz"
      echo "Backing up current CDR2 to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up current CDR2 to ${outfile} and moving to ${storageName}"
      mysqldump CdrDomain ${cdr2current}_d ${cdr2current}_g ${cdr2current}_m ${cdr2current}_r ${cdr2current}_u --user=${user} --password=${password} --insert-ignore --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    messaging)
      infile="messagingdomain_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Messaging DB to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Messaging DB to ${outfile} and moving to ${storageName}"
      mysqldump MessagingDomain --user=${user} --password=${password}  --insert-ignore --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    conference)
      infile="conferencing_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Conferencing Module to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Conferencing Module to ${outfile} and moving to ${storageName}"
      mysqldump NcsDomain --user=${user} --password=${password}  --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    ndp)
      infile="ndp_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Endpoints Module to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Endpoints Module to ${outfile} and moving to ${storageName}"
      mysqldump NdpDomain --user=${user} --password=${password}  --ignore-table=NdpDomain.ndp_syslog --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    ndpfiles)
      outfile="ndp-files_${hostname}_${date}.tar.gz"
      echo "Backing up Endpoints Files to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Endpoints Files to ${outfile} and moving to ${storageName}"
      tar -zcvf ${backup_path}/${outfile} /usr/local/NetSapiens/ndp/frm
      backup $outfile
      ;;
    recording)
      infile="recording_${hostname}_${date}.sql"
      outfile="${infile}.gz"
      echo "Backing up Recording Module to ${outfile} and moving to ${storageName}"
      $logmsg "Backing up Recording Module to ${outfile} and moving to ${storageName}"
      mysqldump LiCfDomain --user=${user} --password=${password}  --result-file=${backup_path}/${infile}
      gzip -f ${backup_path}/${infile}
      backup $outfile
      ;;
    *)
    echo -e "\e[91mError: Unknown option $1\e[39m"
    $logmsg "Error: Unknown options specified"
    echo -e "$errmsg"

  esac
  shift

echo -e ""
echo -e "\e[92mInfo: Backup complete\e[39m"
$logmsg "Info: Backup complete"

done

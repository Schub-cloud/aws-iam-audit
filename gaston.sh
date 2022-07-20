#!/bin/bash

# Set old time
timeago='90 days ago'
taSec=$(date --date "$timeago" +'%s')
# Get list of users
usersList=$(aws iam list-users | jq -r '.Users[].UserName')
# Inicialize oldest date
latestAccessDate=$(date --date "1970-01-01T12:00:00+00:00" +'%s')




while getopts "sr:h:" FLAG
do
	case "${FLAG}" in
		s)
			echo "Step by Step Execution"
			;;
		r)
			echo "Reporting Mode"
			echo "this execution will generate an output file"
			
# Initialize the comma separated file
echo "UserName,accessKeyID,Status,LastUsed" > ${OPTARG}
			for user in $usersList
do
  # Access user data
  accessKeyData=$(aws iam list-access-keys --user-name "$user")
  aks=$(echo $accessKeyData | jq -r '.AccessKeyMetadata | length')
  count=0
  if [ $aks -ne 0 ]; then
    while [ $count -lt $aks ]
    do
      keyID=$(echo -n $accessKeyData | jq -r '.AccessKeyMetadata['$count'].AccessKeyId')
      status=$(echo -n $accessKeyData | jq -r '.AccessKeyMetadata['$count'].Status')
      access_key=$(echo -n $accessKeyData | jq -r '.AccessKeyMetadata['$count'].AccessKeyId')
      lastUsed=$(aws iam get-access-key-last-used --access-key-id "$access_key" | jq -r '.AccessKeyLastUsed.LastUsedDate')
      dtSec=$(date --date "$lastUsed" +'%s' 2>/dev/null)

      if [ $status != "Active"  ]; then
        echo "$user,$keyID,$status,$lastUsed" >> ${OPTARG}
        else
          if [ -z "$dtSec" ]; then
            echo "$user,$keyID,$status,Key Never Used" >> ${OPTARG}
            else
              [ $dtSec -lt $taSec ] && echo "$user,$keyID,$status,Key Too old: $lastUsed" >> ${OPTARG}
          fi
      fi
      count=$((count+1))
    done
    else
      userData=$(aws iam get-login-profile --user-name "$user" 2>/dev/null)
      result=$?
      if [ $result != "0" ]; then
        echo "$user,No Key,Inactive,Password Disabled" >> ${OPTARG}
        else
          userARN=$(aws iam get-user --user-name $user | jq -r '.User.Arn')
          jobID=$(aws iam generate-service-last-accessed-details --arn $userARN | jq -r '.JobId')
          accessedList=$(aws iam get-service-last-accessed-details --job-id $jobID | jq -r '.ServicesLastAccessed[].LastAuthenticated')
          for lastAccessed in $accessedList
          do
            if [ $lastAccessed != "null" ]; then
              linuxDate=$(date --date "$lastAccessed" +'%s' 2>/dev/null)
              [ $linuxDate -gt $latestAccessDate ] && latestAccessDate=$linuxDate  2>/dev/null
            fi
          done
          [ $linuxDate -lt $taSec ] && echo "$user,No Key,Active,Last Accessed: $(date --date @$latestAccessDate)" >> ${OPTARG}
      fi
  fi
done
echo "Report execution Finished"
echo "check ${OPTARG} file"
			;;
		h)
			echo "this is a tool designed to audit and disable un used AWS accounts and access keys"
			echo "usage: "
			echo "-r <outputfile> will read you AWS accounts and generate a report in the outputfile specified"
			echo "-s will run step by step control asking confirmation for each account or access key before disable"
			echo "-a will run and automatically disable unused accounts or access keys"
			;;
		*)
			echo "Pasaste una opcion invalida por favor seleciona a,b o c"
			;;
		esac
done

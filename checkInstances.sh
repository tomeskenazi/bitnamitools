#!/usr/bin/bash
PROGNAME=${0##*/}
CURRENT_USER=$(whoami)
CURRENT_IP=$(hostname -I)
UNUSED_INSTANCES=()
JENKINSWS="/home/jenkins/workspace" #default location for jenkins workspace
JENKINS_SSH="~jenkins/.ssh/id_rsa"

# Verbose mode function
dbg_print () {
  if [ ! -z "$DEBUGMODE"  ]; then
    echo $1
  fi
  return 1
}

# Usage function
usage()
{
cat << EOF
        Usage: $PROGNAME [options]
               $PROGNAME --aws-id=<AWS_ACCESS_KEY_ID> --aws-key=<AWS_SECRET_ACCESS_KEY> --aws-region=<AWS_DEFAULT_REGION> --sys-ssh=<FILENAME> --sys-usr=<USERNAME> --nbdays=<NB_DAYS>

        List the AWS instances that are not flagged as active anymore.
        This is based on 'last' log activity and jenkins workspace if used (ssh-jenkins option required).

        Options:
EOF
cat <<EOF | column -s\& -t

        -h|--help & show this output
        -v|--verbose & add debug traces
        --jenkins-ssh <FILENAME> & SSH key of jenkins user (default ~jenkins/.ssh/id_rsa)
        --jenkins-ws & Location of Jenkins workspace on slaves (default /home/jenkins/workspace)
EOF
}

#Digest Script Arguments
SHORTOPTS="h:v"
LONGOPTS="help,verbose,aws-id:,aws-key:,aws-region:,sys-ssh:,sys-usr:,nbdays:,jenkins-ssh:,jenkins-ws:"
ARGS=$(getopt -s bash --options $SHORTOPTS  --longoptions $LONGOPTS --name $PROGNAME -- "$@" )
eval set -- "$ARGS"
while true; do
   case $1 in
      -h|--help)
         usage
         exit 0
         ;;
      -v|--verbose)
         DEBUGMODE=1
         ;;
      --aws-key)
         shift
         export AWS_SECRET_ACCESS_KEY="$1"
         ;;
      --aws-id)
         shift
         export AWS_ACCESS_KEY_ID="$1"
         ;;
      --aws-region)
         shift
         export AWS_DEFAULT_REGION="$1"
         ;;
      --nbdays)
         shift
         NB_DAYS="$1"
         ;;
      --sys-ssh)
         shift
         SYS_SSH="$1"
         ;;
      --sys-usr)
         shift
         SYS_USR="$1"
         ;;
      --jenkins-ssh)
         shift
         JENKINS_SSH="$1"
         ;;
      --jenkins-ws)
         shift
         JENKINSWS="$1"
         ;;
      --)
         shift
         break
         ;;
      *)
         shift
         break
         ;;
   esac
   shift
done

# Trace arguments
dbg_print "CURRENT USER: $CURRENT_USER"
dbg_print "CURRENT IP: $CURRENT_IP"
dbg_print "AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
dbg_print "AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"
dbg_print "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
dbg_print "USER FOR AWS API ACCESS: $SYS_USR"
dbg_print "SSH KEYFILE FOR AWS API ACCESS: $SYS_SSH"
dbg_print "SSH KEYFILE FOR JENKINS: $JENKINS_SSH"
dbg_print "JENKINS WORKSPACE: $JENKINSWS"
dbg_print "NB_DAYS: $NB_DAYS"
dbg_print "DEBUGMODE: $DEBUGMODE"

# Mandotory arguments should be filled
if [ ! "$AWS_ACCESS_KEY_ID" ] || [ ! "$AWS_SECRET_ACCESS_KEY" ] || [ ! "$AWS_DEFAULT_REGION" ] || [ ! "$NB_DAYS" ] || [ ! "$SYS_SSH" ]
then
    usage
    exit 1
fi

# Discover instances to iterate through (except the machine from which the script runs)
EC2_INSTANCES=$(aws ec2 describe-instances | grep '"PrivateIpAddress"' | sed -e 's/.\+: "\([^"]\+\)".*$/\1/g' | uniq)

#Iterate through EC2 instances
for instance in $EC2_INSTANCES; do
  if [ $instance != $CURRENT_IP ]; then
    INUSE=0
    dbg_print "=================================="
    echo "Analysing instance: $instance"
    dbg_print "=================================="

    # Analysing JENKINS workspace to check if any file has changed in the last NB_DAYS
    dbg_print "Analysing Jenkins Workspace..."
    lastmodified=$(ssh -o StrictHostKeyChecking=no -i $JENKINS_SSH jenkins@$instance find $JENKINSWS -ctime -$NB_DAYS 2>&1)
     if [[ "$lastmodified" != "" ]] && [[ "$lastmodified" != *"No such file"* ]] && [[ "$lastmodified" != *"Permission denied"* ]]; then
      INUSE=1
      dbg_print "-> Workspace has been used recently by a Jenkins job"
      dbg_print "$lastmodified"
      continue
    fi

    # Analysing Last command output to check if anyone is still connected or was in the last NB_DAYS
    dbg_print "Analysing Last Connection Log..."
    lastlog=$(ssh -o StrictHostKeyChecking=no -i $SYS_SSH $SYS_USR@$instance last -F 2>&1 | grep -v 'system boot')
    if [[ "$lastlog" == *"key verification failed"* ]]; then
      dbg_print "WARNING: SSH connection failed"
      break;
    fi
    CURRENTTIME=$(date +%s)
    ONEDAYTIME=86400
    while read -r line; do
      dbg_print "---------------------------------------------------------------------------------------"
      if [[ "$line" == *"known hosts"* ]]; then continue; fi
      if [ "$line" == "" ]; then break; fi
      dbg_print "LINE: $line"
      LASTCONNECTIONUSER=$(echo "$line" | awk '{print $1}')
      dbg_print "LASTCONNECTIONUSER: $LASTCONNECTIONUSER";
      if [[ "$line" == *"still logged in"* ]]; then
        dbg_print "User still connected to the machine: $LASTCONNECTIONUSER"
        INUSE=1
      else
        LASTCONNECTIONTIME=`echo "$line" | sed -e 's/.* - \([^\(]\+\).*/\1/'`
        dbg_print "LASTCONNECTIONTIME: $LASTCONNECTIONTIME";
        LASTTIME=$(date -d "$LASTCONNECTIONTIME" +%s)
        dbg_print "LASTTIME: $LASTTIME"
        DIFFTIME=$(($CURRENTTIME - ($LASTTIME + ($ONEDAYTIME * $NB_DAYS)) ))
        dbg_print "DIFFTIME: $DIFFTIME"
        if [ "$DIFFTIME" \< 0 ]; then
          INUSE=1
        fi
      fi
    done <<< "$lastlog"
    if [ "$INUSE" == "0" ]; then
      host=$(ssh -o StrictHostKeyChecking=no -i $SYS_SSH $SYS_USR@$instance hostname)
      UNUSED_INSTANCES+=("$host ($instance)")
      dbg_print "WARNING: This machine has not been logged in for more than $NB_DAYS days."
    fi
  fi
done

# Display hostname and ip of instances that were flagged as "not in use anymore".
if [ -n "$UNUSED_INSTANCES" ]; then
  echo "THESE INSTANCES MAY NEED TO BE DECOMMISSIONED:"
  printf '%s\n' "${UNUSED_INSTANCES[@]}"
else
  echo "ALL INSTANCES SEEM IN USE"
fi

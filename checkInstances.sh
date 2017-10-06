#!/usr/bin/bash
JENKINSWS="/home/jenkins/workspace"
CURRENT_USER=$(whoami)
CURRENT_IP=$(hostname -I)
UNUSED_INSTANCES=()

EC2_INSTANCES=$(aws ec2 describe-instances | grep '"PrivateIpAddress"' | sed -e 's/.\+: "\([^"]\+\)".*$/\1/g' | uniq)

dbg_print () {
  if [ ! -z "$DEBUGMODE"  ]; then
    echo $1
  fi
  return 1
}

dbg_print "CURRENT USER: $CURRENT_USER"
dbg_print "CURRENT IP: $CURRENT_IP"

for instance in $EC2_INSTANCES; do
  if [ $instance != $CURRENT_IP ]; then
    INUSE=0
    dbg_print "=================================="
    echo "Analysing instance: $instance"
    dbg_print "=================================="
    dbg_print "Analysing Jenkins Workspace..."
    #checkdir=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa jenkins@$instance find $JENKINSWS -maxdepth 0 2>&1)
    #if [[ "$checkdir" != *"No such file"* ]] && [[ "$checkdir" != *"Permission denied"* ]]; then
      lastmodified=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa jenkins@$instance find $JENKINSWS -ctime -$NB_DAYS 2>&1)
       if [[ "$lastmodified" != "" ]] && [[ "$lastmodified" != *"No such file"* ]] && [[ "$lastmodified" != *"Permission denied"* ]]; then
        INUSE=1
        dbg_print "-> Workspace has been used recently by a Jenkins job"
        dbg_print "$lastmodified"
        continue
      fi
    #fi
    dbg_print "Analysing Last Connection Log..."
    lastlog=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/tombitnami.pem ec2-user@$instance last -F 2>&1)
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
      host=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/tombitnami.pem ec2-user@$instance hostname)
      UNUSED_INSTANCES+=("$host ($instance)")
      dbg_print "WARNING: This machine has not been logged in for more than $NB_DAYS days."
    fi
  fi
done

if [ -n "$UNUSED_INSTANCES" ]; then
  echo "THESE MACHINES NEED TO BE DECOMMISSIONED:"
  printf '%s\n' "${UNUSED_INSTANCES[@]}"
else
  echo "ALL MACHINES ARE IN USE"
fi

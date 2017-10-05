#!/usr/bin/bash
DEBUGMODE=0 # Switch to 1 for verbose traces
CURRENT_USER=$(whoami)
CURRENT_IP=$(hostname -I)
UNUSED_INSTANCES=()

EC2_INSTANCES=$(aws ec2 describe-instances | grep '"PrivateIpAddress"' | sed -e 's/.\+: "\([^"]\+\)".*$/\1/g' | uniq)

dbg_print () {
  if [ "$DEBUGMODE" == "1" ]; then
    echo $1
  fi
  return 1
}

dbg_print "CURRENT USER: $CURRENT_USER"
dbg_print "CURRENT IP: $CURRENT_IP"

for instance in $EC2_INSTANCES; do
  if [ $instance != $CURRENT_IP ]; then
    dbg_print "=================================="
    echo "Analysing instance: $instance"
    dbg_print "=================================="
    lastlog=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/tombitnami.pem ec2-user@$instance last -F 2>&1)
    #lastlog=$(<last.log)
    if [[ "$lastlog" == *"key verification failed"* ]]; then
      dbg_print "WARNING: SSH connection failed"
      break;
    fi
    #dbg_print "Last Log:"
    #dbg_print "$lastlog"
    CURRENTTIME=$(date +%s)
    ONEDAYTIME=86400
    INUSE=0
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

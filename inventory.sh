printf "\nGathering CMA Info\n"
for CMA_NAME in $($MDSVERUTIL AllCMAs);
do
  mdsenv $CMA_NAME
  echo "CMA $CMA_NAME"
  cpmiquerybin attr "" network_objects " (type='cluster_member' & vsx_cluster_member='true' & vs_cluster_member='true') | (type='cluster_member' & (! vs_cluster_member='true')) | (vsx_netobj='true') | (type='gateway'&cp_products_installed='true' & (! vs_netobj='true') & connection_state='communicating')" -a __name__,ipaddr;
done 1>> logfile 2>> logfile

printf "\nCalling out to gateways. This may take some time\n"
while read line;
do
  if [ `echo "$line" | grep -c ^CMA` -gt 0 ]; then
    CMA_NAME=`echo "$line" | awk '{print $2}'`
    mdsenv $CMA_NAME

  else
    GW=`echo "$line" | awk '{print $1}'`
    IP=`echo "$line" | awk '{print $2}'`
    MODEL=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd /bin/clish -s -c 'show asset system' | grep ^Model | awk -F: '{print $2}' | sed  's/ Check Point //'`
  fi
# Fix for chassis
  if [ "x$MODEL" = "x" ]; then
    MODEL=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "dmiparse System Product"`;
  fi
  if [ "x$MODEL" = "xA-40" ]; then
	 MODEL="41000";
  fi
done

TAKE=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "grep 'was installed successfully' /opt/CPInstLog/DA_UI.log" | egrep "Image|Jumbo|Upgrade|Bundle_T" | tail -1 | sed 's/Take/#/' | sed 's/was/#/' | sed 's/)//' | awk -F# '{print "Take"$2}' | xargs`

# Fix for earlier releases or when take cannot be read from DA logs
if [ "x$TAKE" = "x" ];then
  TAKE=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "cpinfo -y FW1" | grep HOTFIX | tail -1 | awk '{print $1}'`;
fi
# Fix for manually imported package installations
if [ `echo $TAKE | wc -w` -gt 2 ];then
  TAKE=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "grep 'was installed successfully' /opt/CPInstLog/DA_UI.log" | egrep "Bundle_T" | tail -1 | sed 's/_T/#T/' | awk -F# '{print $2}' | sed 's/_/ /' | sed 's/T//' |awk '{print "Take "$1}'`;
fi

MAJOR=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "fw ver" |  sed 's/This is Check Point VPN-1(TM) & FireWall-1(R) //' | sed "s/This is Check Point's software version //" | awk '{print $1}'`
MAC=`$CPDIR/bin/cprid_util -server $IP -verbose rexec -rcmd bash -c "ifconfig -a" | egrep "Mgmt|Internal|eth0" | head -1 | awk '{print $5}'`

echo "$GW;$IP;$MODEL;$MAJOR;$TAKE;$MAC" >>inventory.txt
printf "\nYour Inventory is located in inventory.txt\n"

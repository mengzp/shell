#!/bin/bash
username='dbsupport'
password='N7ZCbno;f[msB7}dFLf+'
mysql_CMD="-u${username} -p${password} -hlocalhost";

mysql_main_version=5
mysql_sub_version=7

function get_mysql_version(){
	eval `mysql -V | awk '{match($0, /([0-9]).([0-9]).([0-9]+)-(.+)/,a);printf("bigver=%s\nmidver=%s\nsmallver=%s\n", a[1],a[2],a[3]) }'`
	mysql_main_version=$bigver
	mysql_sub_version=$midver
}

function is_version_ok(){
	isok=1
	if [ $mysql_main_version -ne 5 ] && [ $mysql_main_version -ne 8 ]; then
		isok=0
	fi

	if [ $isok -eq 1 ] && ( [ $mysql_sub_version -eq 0 ] || [ $mysql_sub_version -eq 4 ] ); then
		isok=1
	else
		isok=0
	fi
	echo $isok
}

function get_mgr_node_role(){
	
        sql="SELECT member_role,member_state from performance_schema.replication_group_members  WHERE MEMBER_HOST = @@hostname"
	result=$(mysql ${mysql_CMD} -s -N -e "${sql}" 2>/dev/null)
	echo $result
}

function get_slave_status(){
        slavesql="show slave status\G"
        if [ $mysql_main_version -eq 8 ] && [ $mysql_sub_version -eq 4 ]; then
		$slavesql = "show replica status\G"
	fi
	result=$(mysql ${mysql_CMD} -sNe  "$slavesql" 2>/dev/null)
	echo $result
}

function is_slave_node(){
 	isslave=0
	slavesql="show slave status"
	if [ $mysql_main_version -eq 8 ] && [ $mysql_sub_version -eq 4 ]; then
		$slavesql = "show replica status"
	fi

	result=$(mysql ${mysql_CMD} -s -N -e "$slavesql" 2>/dev/null | wc -l)
	if [ "$result" -gt 0 ]; then
		isslave=1
	fi
	echo $isslave
}

function is_ms_master_node(){
	ismsmaster=0
	mastersql="show master status"
	if [ $mysql_main_version -eq 8 ] && [ $mysql_sub_version -eq 4 ]; then
		$mastersql = "show binary log status"
	fi

        result=$(mysql ${mysql_CMD} -s -N -e "$mastersql" 2>/dev/null | wc -l)
	if [ "$result" -gt 0 ]; then
		ismsmaster=1
	fi
	echo $ismsmaster
}

function mysql_running_status(){
	mysql_status=$(systemctl status mysqld)
	if echo "$mysql_status" | grep -q "Active: active (running)"; then
	    echo 1
    	else
	    echo 0
	fi
}

function node_exporter_status(){
	mysql_status=$(systemctl status node_exporter)
	if echo "$mysql_status" | grep -q "Active: active (running)"; then
	    echo 1
    	else
	   echo 0
	fi
}

function mysql_exporter_status(){
	mysql_status=$(systemctl status mysqld_exporter)
	if echo "$mysql_status" | grep -q "Active: active (running)"; then
	    echo 1
    	else
	    echo 0
	fi
}


running_status=$(mysql_running_status)
if [ $running_status -eq 0 ]; then
	echo "MySQL services don't active"
	exit 1
fi

get_mysql_version

check_version=$(is_version_ok)
if [ $check_version -eq 0 ]; then
	echo "MySQL version isn't right, please contact MySQL DBA team for help!";
	exit 1
fi

result=$(get_mgr_node_role)
node_role=$(echo "$result" | cut -d' ' -f1)
node_state=$(echo "$result" | cut -d' ' -f2)
if  [[ "${node_role,,}" == "primary" ]] || [[ "${node_role,,}" == "secondary" ]] ; then
	if [[ "${node_state,,}" == "online" ]] ; then
		echo "MySQL MGR $node_role node running online state"
	else

		echo "MySQL MGR $node_role node running $node_state state"
		echo "Please check the server state!"
		exit 1
	fi
else
	result=$(get_slave_status)
	Io_running=$(echo "$result" | grep "Slave_IO_Running" | awk -F: '{print $2}')
	sql_running=$(echo "$result" | grep "Slave_SQL_Running" | awk -F: '{print $2}')

	if [ $Io_running == "Yes" &&  $sql_running == "Yes" ]; then
		echo "MySQL Slave Node Io_running state: $Io_running"
		echo "MySQL Slave Node sql_running state: $sql_running"
		
	else
		if [$Io_running == "No" ||  $sql_running == "No" ]; then
			echo "MySQL Master-slave Slave node isnot right, please check it!"
			exit 1
		fi
	fi
fi

node_exporter_state=$(node_exporter_status)
if [ $node_exporter_state -eq 1 ]; then
	echo "MySQL Node Exporter is running"
else
	echo "MySQL Node Exporter isn't running"
	exit 1
fi

mysql_exporter_state=$(mysql_exporter_status)
if [ $mysql_exporter_state -eq 1 ]; then
	echo "MySQL Exporter is running"
else
	echo "MySQL Exporter isn't running"
	exit 1
fi


exit 0







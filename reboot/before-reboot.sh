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
	
        mysql ${mysql_CMD} -s -N -e "SELECT member_role from performance_schema.replication_group_members  WHERE MEMBER_HOST = @@hostname" 2>/dev/null
	echo $!
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



get_mysql_version

running_status=$(mysql_running_status)
if [ $running_status -eq 0 ]; then
	echo "MySQL services don't active"
	exit 1
fi


check_version=$(is_version_ok)
if [ $check_version -eq 0 ]; then
	echo "MySQL version isn't right, please contact MySQL DBA team for help!";
	exit 1
fi
node_role=$(get_mgr_node_role)
if [[ "${node_role,,}" == "secondary" ]] ; then
	echo "MySQL MGR secondary node"
	echo "MySQL services could be stop now"
	exit 0
else
	if [[ "${node_role,,}" == "primary" ]] ; then
		echo "MySQL MGR Cluster primary node"
		echo "MySQL service couldn't be stop now";
		exit 1
	fi
fi	


isslave=$(is_slave_node)
if [ $isslave -eq 1 ]; then
	echo "MySQL Master-Slave slave node"
	echo "MySQL service could be stop now"
	exit 0
else
	ismaster=$(is_ms_master_node)
	if [ $ismaster -eq 0 ]; then
		echo "This instance isn't Master-Slave master node"
		echo "MySQL service could be stop now"
		exit 0
	else
		echo "This instance is perhaps Master-Slave master node, Can't tell if you can reboot"
		echo "please contact MySQL DBA team for help!"
		exit 1
	fi
fi






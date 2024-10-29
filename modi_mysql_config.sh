echo $1
eval `awk '{match($0,/.+DATA_SOURCE_NAME=(.+):(.+)@\((.+:[0-9]+)\)/,a);if (a[1] != null ) printf("username=%s\npassword=%s\ndbconn=%s\n", a[1],a[2],a[3])  }' $1`

#echo $username
#echo $password
#echo $dbconn
cat $1 | grep "Environment=\"DATA_SOURCE_NAME"
if [ $? == 0 ]; then
	sed -i "s/Environment=\"DATA.*/Environment=\"MYSQLD_EXPORTER_PASSWORD=${password}\"/g" $1 
	sed -i "/--web.listen-address/ s/$/ --mysqld.address=${dbconn} --mysqld.username=${username}/g" $1
fi

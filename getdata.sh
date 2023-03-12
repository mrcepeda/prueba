#!/bin/bash

TERM=xterm
export TERM
reset=$(tput sgr0)
hostname=$(hostname)
IP=$(hostname -i)
time=$(date +%d%m%y-%k%M)

#####################

installpathcore=$(ps -ef | grep kernel  | grep "vt-net/" | tail -n1 | awk '{ print $10 }' |  awk -F"vt-net/" '{ print $1 }')
installpathauth=$(ps -ef | grep kernel | grep -i "vt-net-as/" | tail -n1 | awk '{ print $10 }' | awk -F"vt-net-as/" '{ print $1 }')
installpathcomm=$(ps -ef | grep appD | grep -v grep | awk '{ print $10 }'  | awk -F "/appDeployer/" '{ print $1 }')
installpathnotif=$(ps -ef | grep kernel | grep -i "vt-net-notif/" | tail -n1 | awk '{ print $10 }' | awk -F"vt-net-notif/" '{ print $1 }')
installpathstudio=$(ps -ef | grep -i "tomcat" | grep -v grep | tail -n1 | awk -F"-Dcatalina.base=" '{ print $2 }' | awk '{ print $1 }')
installusercomm=$(ps axo user:20,comm | grep appD | grep -v grep | awk '{ print $1 }' )
installuserstudio=$(ps axo user:20,comm | grep tomcat | grep -v grep | awk '{ print $1 }' )


if [ -z $installpathcore ];
then
installpathcore=/veritran/
export installpathcore
fi

if [ -z $installpathauth ];
then
installpathauth=/veritran/
export installpathauth
fi

if [ -z $installpathcomm ];
then
installpathcomm=/veritran/
export installpathcomm
fi

if [ -z $installpathnotif ];
then
installpathnotif=/veritran/
export installpathnotif
fi

if [ -z $installpathstudio ];
then
installpathstudio=/veritran/vt-studio
export installpathstudio
fi

if [ -z $installusercomm ];
then
installusercomm=vt724
export installusercomm
fi

if [ -z $installuserstudio ];
then
installuserstudio=vt724
export installuserstudio
fi


server="$hostname  "


OS="echo $(grep -i pretty /etc/*release)"
OS2=$(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')

##Archivos de configuracion
# COMM
#set -x
vtUasCF="$installpathcomm/vt-uas/htdocs/index.php"
httpdCOMM="/usr/sbin/httpd"
nginxCOMM="/usr/sbin/nginx"
AppDeployerBIN="$installpathcomm/appDeployer/bin/appDeployer"

# CORE
vtconsoleCoreCF="$installpathcore/vt-console/config/application.properties"
vt724CoreCF="$installpathcore/vt-724/vt-config/config/version.info"

# NOTIF
vt724NotifCF="$installpathnotif/vt-724-notif/vt-config/config/version.info"
vtNotifBIN="$installpathnotif/vt-net-notif/bin/vtNotifServer"

# AS
vtAsBIN="$installpathauth/vt-net-as/bin/tkAuthServer"
vt724AsCF="$installpathauth/vt-724-as/vt-config/config/version.info"

# OTHERS
#WEBSERVER=$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')


#### FUNCIONES ####


function ParseaTNS () {

case "$1" in
  CORE | core)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathcore/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')
if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

;;

  
  AUTH | auth)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathauth/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')

if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

    ;;

  
  NOTIF | notif)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathnotif/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')
if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

    ;;

esac
}

##########
# COMMON #
##########

AutoGetData() {

ps -efa > /tmp/TeMpPS
CORE=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]1')
AS=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]2')
COMMAPPD=$(grep appD /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]3')
COMMLIGHT=$(grep light /tmp/TeMpPS | grep -e 'lighttpd-comm')
NOTIF=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]4')
OMNI=$(/usr/bin/sudo -i docker service ls 2>/dev/null | grep -e 'workspace-api')
STUDIO=$(grep tomcat /tmp/TeMpPS | grep -e 'tomcat-juli')


if [[ $CORE =~ N[A-Z][A-Z]1 ]]; then
  CoreGetData CORE

fi

if [[ $AS =~ N[A-Z][A-Z]2 ]]; then
  AuthGetData AUTH
fi

if [[ $COMMAPPD =~ N[A-Z][A-Z]3 ]] || [[ ! -z $COMMLIGHT ]]
 then
  CommGetData COMM
fi


if [[ $NOTIF =~ N[A-Z][A-Z]4 ]]; then
NotifGetData NOTIF
fi

if [[ $OMNI =~ workspace-api ]]; then
OmniGetData OMNI

fi

if [[ $STUDIO =~ tomcat-juli.jar ]]; then
StudioGetData STUDIO
#else
#UnusedGetData UNUSED
fi

}

########
# COMM #
########

CommGetData() {

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724 php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


if [ -f /usr/bin/sudo ]; then
  /usr/bin/sudo -i /usr/sbin/apachectl -t -D DUMP_VHOSTS > /tmp/TeMp 2>/dev/null
  chmod 777 /tmp/TeMp
fi

VTGWF=$(cat /tmp/TeMp | grep gateway | grep conf | awk -F"(" '{ print $2 }' | cut -d":" -f1 | grep -v ^\# | uniq )

if [ -f $VTGWF ]; then
TEST=$(/usr/bin/sudo -i -u $installusercomm cat $VTGWF | grep vt-gateway.php | grep -v ^\# | grep "/vt-gateway/" | uniq | awk '{ print $3 }' | uniq )
fi

if [ $? == "0" ];
 then
 export VTGWVER=$(/usr/bin/sudo -i -u $installusercomm wc -l $TEST | awk '{ print $1 }')

 if [ $VTGWVER = 392 ];
  then
   echo "COMM_VT-GATEWAY_VERSION; 1.14.0"
 fi

 if [ $VTGWVER != 392 ];
  then
   echo "COMM_VT-GATEWAY_VERSION; $VTGWVER"
 fi

else
  echo "COMM_VT-GATEWAY_VERSION;NA" >&2
fi


if [ -f "$httpdCOMM" ];
then
 echo COMM_VT-GATEWAY_SERVERNAME \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerName | grep -v ^\# | awk -F"ServerName" '{ print $2 }' )
 echo COMM_VT-GATEWAY_SERVERALIAS \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerAlias | grep -v ^\# | awk -F"ServerAlias" '{ print $2 }' )
else
   echo "COMM_VT-GATEWAY_VERSION;NA"
fi

if [ -f "$httpdCOMM" ];
then
 grep -v ^\# $(cat /tmp/TeMp | grep gateway | grep conf | awk -F"(" '{ print $2 }' | cut -d":" -f1 | uniq) | grep vt-uas | grep DocumentRoot > /tmp/TeMp3
 TEST=$(cat /tmp/TeMp3 | awk '{ print $2 }')

if [ -f "$TEST/index.php" ];
then
  vtUasVer=$(grep Version $TEST/index.php | awk -F":" '{ print $2 }')
  echo "COMM_VT-UAS_VERSION ;" $vtUasVer
else
  echo "COMM_VT-UAS_VERSION ; NA"
fi

echo COMM_VT-UAS_SERVERNAME \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerName | grep -v ^\# | awk -F"ServerName" '{ print $2 }' )
echo COMM_VT-UAS_SERVERALIAS \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerAlias | grep -v ^\# | awk -F"ServerAlias" '{ print $2 }' )

else
  echo "COMM_VT-UAS_VERSION ; NA"
fi

if [[ -f "$AppDeployerBIN" ]] && [[ ! -z $COMMAPPD ]]
then
  export appd=$(/usr/bin/sudo -i -u $installusercomm $AppDeployerBIN -v | awk '{ print $2 }')
  echo "COMM_APPDEPLOYER_VERSION ;"  $appd
else
   echo "COMM_APPDEPLOYER_VERSION;NA"
fi

}

StudioGetData() {

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 

STUDIOPID=$(cat /tmp/TeMpPS | grep -i tomcat | grep -v grep  | awk '{ print $8 }')

if [[ -d $installpathstudio ]] && [[ ! -z $STUDIOPID ]] 
 then
  for i in $(sudo -i -u $installuserstudio ls $installpathstudio/webapps | grep -i -v OLD | grep -v ROOT | grep ".war" | awk -F ".war" '{ print $1 }')
  do sudo -i -u $installuserstudio grep Implementation-Version $installpathstudio/webapps/$i/META-INF/MANIFEST.MF | awk -F"Implementation-Version:" '{ print "'$1'_VTSTUDIO_'$i'_VERSION;" $2}'
  done
 else
	echo "$1_VTSTUDIO_VERSION;NA"
fi 

}

### APP SERVER ####
AppsrvGetData() {
#AllGetData APP


echo "ps -ef | grep java | egrep -v 'vt-console|jenkins|studio|idm|brm|audit' | egrep -i 'wls|tomcat|websphere|jboss|wild'" > /tmp/TeMpAPP

sh /tmp/TeMpAPP | grep -i catalina > /dev/null 2>&1
if [ $? -eq 0 ]
then
  for i in $(sh /tmp/TeMpAPP | grep -i catalina | awk -F"-Dcatalina.base=" '{ print $2 }' | awk -F"-D" '{ print $1 }'); do sudo -i -u vt724 $i/bin/version.sh; done  2>/dev/null > /tmp/TeMpAPP2
  cat /tmp/TeMpAPP2 | grep Tomcat | awk -F"/" '{ print "APP_APPSRV_VERSION;Tomcat " $2 }'
  cat /tmp/TeMpAPP2 | grep "JVM Version" | awk -F":" '{ print "APP_JAVA_VERSION;Oracle" $2 }'
  cat /tmp/TeMpAPP2 | grep "JVM Vendor" | awk -F":" '{ print "APP_JAVA_VENDOR;" $2 }'

else
   echo "APP_APPSERVER_VERSION ;"
   echo "APP_JAVA_VERSION;"
   echo "APP_JAVA_VENDOR;"
fi

}

### OMNI SERVER ####
OmniGetData() {
#AllGetData OMNI

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;NA"
fi


if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


#if [ -d $installpathomni ];
# then
#  VTMIDDLEWAREBIN="$installpathomni/vt-net/bin/deviceHandler"

#if [ -f "$VTMIDDLEWAREBIN" ];
# then 
#  echo "CORE_VTMIDDLEWARE_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/deviceHandler -v  )
# else
#	echo "CORE_VTMIDDLEWARE_VERSION;NA"
#fi 
#fi

SSOHOST=$(/usr/bin/sudo -i docker service inspect veritran_workspace-api 2>/dev/null | grep traefik.http.routers.workspace-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')
SSOPORT=$(/usr/bin/sudo -i docker service inspect veritran_traefik 2>/dev/null | grep PublishedPort | head -n1 | cut -d ":" -f2 | cut -d "," -f1 | cut -d " " -f2)

if [ -n $SSOHOST ];
then
curl -k https://$SSOHOST:$SSOPORT/api > /tmp/ssoVer 2>/dev/null

ssoVer=$(cat /tmp/ssoVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_WORKSPACE_VERSION;"   $ssoVer
else
  echo "$1_WORKSPACE_VERSION;NA"
fi

AUDITHOST=$(/usr/bin/sudo -i docker service inspect veritran_audit-api 2>/dev/null | grep traefik.http.routers.audit-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $AUDITHOST ];
then
curl -k https://$AUDITHOST:$SSOPORT/api > /tmp/auditVer 2>/dev/null

auditVer=$(cat /tmp/auditVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_AUDIT_VERSION;"  $auditVer
else
  echo "$1_AUDIT_VERSION;NA"
fi

STATICSHOST=$(/usr/bin/sudo -i docker service inspect veritran_statics-api 2>/dev/null | grep traefik.http.routers.statics-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $STATICSHOST ];
then
curl -k https://$STATICSHOST:$SSOPORT/api > /tmp/staticsVer 2>/dev/null

staticsVer=$(cat /tmp/staticsVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_STATICS_VERSION;"  $staticsVer
else
  echo "$1_STATICS_VERSION;NA"
fi

HTSHOST=$(/usr/bin/sudo -i docker service inspect veritran_http-to-sql-api 2>/dev/null | grep traefik.http.routers.http-to-sql-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $HTSHOST ];
then
curl -k https://$HTSHOST:$SSOPORT/api > /tmp/htsVer 2>/dev/null

htsVer=$(cat /tmp/staticsVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_HTTP-TO-SQL_VERSION;"  $htsVer
else
  echo "$1_HTTP-TO-SQL_VERSION;NA"
fi

}


### CORE SERVER ####
CoreGetData() {
#AllGetData CORE

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724  php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


if [ -d $intallpathcore ];
 then
  VTNETBIN="$installpathcore/vt-net/bin/kernel"

if [ -f "$VTNETBIN" ];
 then 
  echo "CORE_VTNET_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/kernel -v  )
 else
	echo "CORE_VTNET_VERSION;NA"
fi 
fi

if [ -d $intallpathcore ];
 then
  VTMIDDLEWAREBIN="$installpathcore/vt-net/bin/deviceHandler"

if [ -f "$VTMIDDLEWAREBIN" ];
 then 
  echo "CORE_VTMIDDLEWARE_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/deviceHandler -v  )
 else
	echo "CORE_VTMIDDLEWARE_VERSION;NA"
fi 
fi

if [ -d $intallpathcore ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathcore/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 


#if [ -f /veritran/vt-net/bin/vrtrDummyHost ];
 #then
 # for i in $(ls /veritran/vt-net/bin/*Host); do echo $i | awk -F'bin/' '{ print $2 ";" }' && sudo -i -u vt724 $i -V | grep Version | head -1 | awk '{ print $2 }' ; done > /tmp/TeMp4
#cat /tmp/TeMp4  
#else
#  echo "CORE_HOST_VERSION ;" >&2
#fi

if [ -f "$vtconsoleCoreCF" ];
then
vtconsoleVerPort=$(grep ".port=" $vtconsoleCoreCF | cut -d "=" -f2)
curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null

vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
echo "CORE_VTCONSOLE_VERSION;"   $vtconsoleVer
else
  echo "CORE_VTCONSOLE_VERSION;NA"
fi

##### VT724-CORE  #####

if [ -f "$vt724CoreCF" ];
then
vt724CoreVer=$(cat $vt724CoreCF | cut -d ":" -f2 )
echo "CORE_VT724_VERSION;"   $vt724CoreVer
else
  echo "CORE_VT724_VERSION;"
fi

fi


}


### AUTH SERVER ####
AuthGetData() {
#AllGetData AUTH

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"


if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724  php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 



if [ -r $installpathauth ];
 then
  VTNETASBIN="$installpathauth/vt-net-as/bin/kernel"

if [ -f "$VTNETASBIN" ];
 then 
  echo "AUTH_VTNETAS_VERSION;" $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/kernel -v  | awk '{ print $2 }' )
 else
	echo "AUTH_VTNETAS_VERSION;"
fi 

if [ -r $installpathauth ];
 then
  VTASBIN="$installpathauth/vt-net-as/bin/tkAuthServer"

if [ -f "$VTASBIN" ];
 then 
  echo "AUTH_VTAS_VERSION;" $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/tkAuthServer -v  | awk '{ print $2 }' )
 else
	echo "AUTH_VTAS_VERSION;"
fi 
fi

if [ -d $installpathauth ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathauth/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 
fi

#echo "AUTH_VTAS_VERSION ;"  $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/tkAuthServer -v | awk '{ print $2 }' ) 

##### VT724-AS  #####

if [ -f "$vt724AsCF" ];
then 
vt724AsVer=$(cat $vt724AsCF | cut -d ":" -f2 )
echo "AUTH_VT724_VERSION ;"   $vt724AsVer
else
	echo "AUTH_VT724_VERSION;"
fi 

fi
}

### NOTIF SERVER ####
NotifGetData() {
#set -x
echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724 php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 

vtconsoleNotifCF="$installpathnotif/vt-console-notif/config/application.properties"
vtNFconsoleCF="$installpathnotif/vt-notif/config/application.properties"
vtNFnodeCF="$installpathnotif/nfnode/config/application.properties"
vtNFconsolenotifCF="$installpathnotif/nfconsole/config/application.properties"



if [ -r $installpathnotif ];
 then
  VTNETNOTIFBIN="$installpathnotif/vt-net-notif/bin/kernel"

  if [ -f "$VTNETNOTIFBIN" ];
   then 
     NOTIFVERSION=$(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/kernel -v )
     notifregex="1.13.5.*"
    if [[ $NOTIFVERSION =~ $notifregex ]]; then 
      echo "NOTIF_VTNETNOTIF_VERSION; $NOTIFVERSION"
    else
      NOTIFVERSION=$(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/kernel -v  | awk '{ print $2 }' )
	    echo "NOTIF_VTNETNOTIF_VERSION; $NOTIFVERSION"
fi 


if [ -r $installpathnotif ];
 then
  VTNOTIFBIN="$installpathnotif/vt-net-notif/bin/vtNotifServer"

if [ -f "$VTNOTIFBIN" ];
 then 
  echo "NOTIF_VTNOTIF_VERSION;" $(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/vtNotifServer -v  | awk '{ print $2 }' )

 else
	echo "NOTIF_VTNOTIF_VERSION;"
fi 
fi

if [ -d $installpathnotif ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathnotif/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 
fi


if [ -f "$vtconsoleNotifCF" ];
 then 
  vtconsoleVerPort=$(grep ".port=" $vtconsoleNotifCF | cut -d "=" -f2)
  curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null
  vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
  echo "NOTIF_NFNODE_VERSION ;"   $vtconsoleVer
 else
  echo "NOTIF_NFNODE_VERSION;"
fi 

if [ -f "$vtNFconsoleCF" ];
 then
  vtNFconsoleVerPort=$(grep application.port $vtNFconsoleCF | cut -d "=" -f2)
  curl -k http://localhost:$vtNFconsoleVerPort/configuration > /tmp/vtNFconsoleVer 2>/dev/null
  vtNFconsoleVer=$(cut -d "\"" -f18 /tmp/vtNFconsoleVer)
  echo "NOTIF_NFCONSOLE_VERSION ;"   $vtNFconsoleVer
 else
  echo "NOTIF_NFCONSOLE_VERSION;"
fi

if [ -f "$vtNFnodeCF" ];
 then 
  vtconsoleVerPort=$(grep ".port=" $vtNFnodeCF | cut -d "=" -f2)
  curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null
  vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
  echo "NOTIF_NFNODE_VERSION ;"   $vtconsoleVer
 else
  echo "NOTIF_NFNODE_VERSION;"
fi 

if [ -f "$vtNFconsolenotifCF" ];
 then
  vtNFconsoleVerPort=$(grep application.port $vtNFconsolenotifCF | cut -d "=" -f2)
  curl -k http://localhost:$vtNFconsoleVerPort/configuration > /tmp/vtNFconsoleVer 2>/dev/null
  vtNFconsoleVer=$(cut -d "\"" -f18 /tmp/vtNFconsoleVer)
  echo "NOTIF_NFCONSOLE_VERSION ;"  $vtNFconsoleVer
 else
  echo "NOTIF_NFCONSOLE_VERSION;"
fi

fi
fi

}

## MAIN ##

case "$1" in
  COMM | comm)
    CommGetData
    rm -f /tmp/TeMp*
    ;;

  APPSRV | appsrv)
    AppsrvGetData
    rm -f /tmp/TeMp*
    ;;

  CORE | core)
    CoreGetData
    rm -f /tmp/TeMp*
    ;;

  AUTH | auth)
    AuthGetData
    rm -f /tmp/TeMp*
    ;;

  NOTIF | notif)
    NotifGetData
    rm -f /tmp/TeMp*
    ;;

  OMNI | omni)
    OmniGetData
    rm -f /tmp/TeMp*
    ;;

  STUDIO | studio)
    StudioGetData
    rm -f /tmp/TeMp*
    ;;

  AUTO | auto)
    AutoGetData
    rm -f /tmp/TeMp*
    ;;

    ALL)
    CommGetData
    CoreGetData
    AuthGetData
    NotifGetData
    AppsrvGetData
    OmniGetData
    rm -f /tmp/TeMp*
    ;;


  *)
    echo "Usage: $0 {COMM|CORE|AUTH|NOTIF|APPSRV|OMNI}"
    ;;
esac

#!/bin/bash

TERM=xterm
export TERM
reset=$(tput sgr0)
hostname=$(hostname)
IP=$(hostname -i)
time=$(date +%d%m%y-%k%M)

#####################

installpathcore=$(ps -ef | grep kernel  | grep "vt-net/" | tail -n1 | awk '{ print $10 }' |  awk -F"vt-net/" '{ print $1 }')
installpathauth=$(ps -ef | grep kernel | grep -i "vt-net-as/" | tail -n1 | awk '{ print $10 }' | awk -F"vt-net-as/" '{ print $1 }')
installpathcomm=$(ps -ef | grep appD | grep -v grep | awk '{ print $10 }'  | awk -F "/appDeployer/" '{ print $1 }')
installpathnotif=$(ps -ef | grep kernel | grep -i "vt-net-notif/" | tail -n1 | awk '{ print $10 }' | awk -F"vt-net-notif/" '{ print $1 }')
installpathstudio=$(ps -ef | grep -i "tomcat" | grep -v grep | tail -n1 | awk -F"-Dcatalina.base=" '{ print $2 }' | awk '{ print $1 }')
installusercomm=$(ps axo user:20,comm | grep appD | grep -v grep | awk '{ print $1 }' )
installuserstudio=$(ps axo user:20,comm | grep tomcat | grep -v grep | awk '{ print $1 }' )


if [ -z $installpathcore ];
then
installpathcore=/veritran/
export installpathcore
fi

if [ -z $installpathauth ];
then
installpathauth=/veritran/
export installpathauth
fi

if [ -z $installpathcomm ];
then
installpathcomm=/veritran/
export installpathcomm
fi

if [ -z $installpathnotif ];
then
installpathnotif=/veritran/
export installpathnotif
fi

if [ -z $installpathstudio ];
then
installpathstudio=/veritran/vt-studio
export installpathstudio
fi

if [ -z $installusercomm ];
then
installusercomm=vt724
export installusercomm
fi

if [ -z $installuserstudio ];
then
installuserstudio=vt724
export installuserstudio
fi


server="$hostname  "


OS="echo $(grep -i pretty /etc/*release)"
OS2=$(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')

##Archivos de configuracion
# COMM
#set -x
vtUasCF="$installpathcomm/vt-uas/htdocs/index.php"
httpdCOMM="/usr/sbin/httpd"
nginxCOMM="/usr/sbin/nginx"
AppDeployerBIN="$installpathcomm/appDeployer/bin/appDeployer"

# CORE
vtconsoleCoreCF="$installpathcore/vt-console/config/application.properties"
vt724CoreCF="$installpathcore/vt-724/vt-config/config/version.info"

# NOTIF
vt724NotifCF="$installpathnotif/vt-724-notif/vt-config/config/version.info"
vtNotifBIN="$installpathnotif/vt-net-notif/bin/vtNotifServer"

# AS
vtAsBIN="$installpathauth/vt-net-as/bin/tkAuthServer"
vt724AsCF="$installpathauth/vt-724-as/vt-config/config/version.info"

# OTHERS
#WEBSERVER=$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')


#### FUNCIONES ####


function ParseaTNS () {

case "$1" in
  CORE | core)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathcore/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')
if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

;;

  
  AUTH | auth)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathauth/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')

if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

    ;;

  
  NOTIF | notif)

arr=( $(/usr/bin/sudo -i -u vt724 grep -v ^\# $installpathnotif/share/network/admin/tnsnames.ora | egrep -v "DESCRIPTION|CONNECT_DATA|SERVER" | grep -A 4 $2)  )
TNSHOST=$(echo ${arr[8]} | cut -d ")" -f1 )
TNSPORT=$(echo ${arr[10]} | cut -d ")" -f1)
TNSSN=$(echo ${arr[13]}| cut -d ")" -f1)
TNSIP=$(grep -i $TNSHOST /etc/hosts | grep -v ^\# | awk '{ print $1 }')
if [ -z $TNSIP ];
 then
  echo "$1_DB_${arr[0]} ; $TNSHOST:$TNSPORT/$TNSSN "
 else
  echo "$1_DB_${arr[0]} ; $TNSIP:$TNSPORT/$TNSSN "
fi

    ;;

esac
}

##########
# COMMON #
##########

AutoGetData() {

ps -efa > /tmp/TeMpPS
CORE=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]1')
AS=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]2')
COMMAPPD=$(grep appD /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]3')
COMMLIGHT=$(grep light /tmp/TeMpPS | grep -e 'lighttpd-comm')
NOTIF=$(grep kernel /tmp/TeMpPS | grep -e 'N[A-Z][A-Z]4')
OMNI=$(/usr/bin/sudo -i docker service ls 2>/dev/null | grep -e 'workspace-api')
STUDIO=$(grep tomcat /tmp/TeMpPS | grep -e 'tomcat-juli')


if [[ $CORE =~ N[A-Z][A-Z]1 ]]; then
  CoreGetData CORE

fi

if [[ $AS =~ N[A-Z][A-Z]2 ]]; then
  AuthGetData AUTH
fi

if [[ $COMMAPPD =~ N[A-Z][A-Z]3 ]] || [[ ! -z $COMMLIGHT ]]
 then
  CommGetData COMM
fi


if [[ $NOTIF =~ N[A-Z][A-Z]4 ]]; then
NotifGetData NOTIF
fi

if [[ $OMNI =~ workspace-api ]]; then
OmniGetData OMNI

fi

if [[ $STUDIO =~ tomcat-juli.jar ]]; then
StudioGetData STUDIO
#else
#UnusedGetData UNUSED
fi

}

########
# COMM #
########

CommGetData() {

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724 php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


if [ -f /usr/bin/sudo ]; then
  /usr/bin/sudo -i /usr/sbin/apachectl -t -D DUMP_VHOSTS > /tmp/TeMp 2>/dev/null
  chmod 777 /tmp/TeMp
fi

VTGWF=$(cat /tmp/TeMp | grep gateway | grep conf | awk -F"(" '{ print $2 }' | cut -d":" -f1 | grep -v ^\# | uniq )

if [ -f $VTGWF ]; then
TEST=$(/usr/bin/sudo -i -u $installusercomm cat $VTGWF | grep vt-gateway.php | grep -v ^\# | grep "/vt-gateway/" | uniq | awk '{ print $3 }' | uniq )
fi

if [ $? == "0" ];
 then
 export VTGWVER=$(/usr/bin/sudo -i -u $installusercomm wc -l $TEST | awk '{ print $1 }')

 if [ $VTGWVER = 392 ];
  then
   echo "COMM_VT-GATEWAY_VERSION; 1.14.0"
 fi

 if [ $VTGWVER != 392 ];
  then
   echo "COMM_VT-GATEWAY_VERSION; $VTGWVER"
 fi

else
  echo "COMM_VT-GATEWAY_VERSION;NA" >&2
fi


if [ -f "$httpdCOMM" ];
then
 echo COMM_VT-GATEWAY_SERVERNAME \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerName | grep -v ^\# | awk -F"ServerName" '{ print $2 }' )
 echo COMM_VT-GATEWAY_SERVERALIAS \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerAlias | grep -v ^\# | awk -F"ServerAlias" '{ print $2 }' )
else
   echo "COMM_VT-GATEWAY_VERSION;NA"
fi

if [ -f "$httpdCOMM" ];
then
 grep -v ^\# $(cat /tmp/TeMp | grep gateway | grep conf | awk -F"(" '{ print $2 }' | cut -d":" -f1 | uniq) | grep vt-uas | grep DocumentRoot > /tmp/TeMp3
 TEST=$(cat /tmp/TeMp3 | awk '{ print $2 }')

if [ -f "$TEST/index.php" ];
then
  vtUasVer=$(grep Version $TEST/index.php | awk -F":" '{ print $2 }')
  echo "COMM_VT-UAS_VERSION ;" $vtUasVer
else
  echo "COMM_VT-UAS_VERSION ; NA"
fi

echo COMM_VT-UAS_SERVERNAME \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerName | grep -v ^\# | awk -F"ServerName" '{ print $2 }' )
echo COMM_VT-UAS_SERVERALIAS \; $(cat /tmp/TeMp | grep gateway | grep conf | tail -n1 | awk -F"(" '{ print $2 }' | cut -d":" -f1 | xargs grep ServerAlias | grep -v ^\# | awk -F"ServerAlias" '{ print $2 }' )

else
  echo "COMM_VT-UAS_VERSION ; NA"
fi

if [[ -f "$AppDeployerBIN" ]] && [[ ! -z $COMMAPPD ]]
then
  export appd=$(/usr/bin/sudo -i -u $installusercomm $AppDeployerBIN -v | awk '{ print $2 }')
  echo "COMM_APPDEPLOYER_VERSION ;"  $appd
else
   echo "COMM_APPDEPLOYER_VERSION;NA"
fi

}

StudioGetData() {

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 

STUDIOPID=$(cat /tmp/TeMpPS | grep -i tomcat | grep -v grep  | awk '{ print $8 }')

if [[ -d $installpathstudio ]] && [[ ! -z $STUDIOPID ]] 
 then
  for i in $(sudo -i -u $installuserstudio ls $installpathstudio/webapps | grep -i -v OLD | grep -v ROOT | grep ".war" | awk -F ".war" '{ print $1 }')
  do sudo -i -u $installuserstudio grep Implementation-Version $installpathstudio/webapps/$i/META-INF/MANIFEST.MF | awk -F"Implementation-Version:" '{ print "'$1'_VTSTUDIO_'$i'_VERSION;" $2}'
  done
 else
	echo "$1_VTSTUDIO_VERSION;NA"
fi 

}

### APP SERVER ####
AppsrvGetData() {
#AllGetData APP


echo "ps -ef | grep java | egrep -v 'vt-console|jenkins|studio|idm|brm|audit' | egrep -i 'wls|tomcat|websphere|jboss|wild'" > /tmp/TeMpAPP

sh /tmp/TeMpAPP | grep -i catalina > /dev/null 2>&1
if [ $? -eq 0 ]
then
  for i in $(sh /tmp/TeMpAPP | grep -i catalina | awk -F"-Dcatalina.base=" '{ print $2 }' | awk -F"-D" '{ print $1 }'); do sudo -i -u vt724 $i/bin/version.sh; done  2>/dev/null > /tmp/TeMpAPP2
  cat /tmp/TeMpAPP2 | grep Tomcat | awk -F"/" '{ print "APP_APPSRV_VERSION;Tomcat " $2 }'
  cat /tmp/TeMpAPP2 | grep "JVM Version" | awk -F":" '{ print "APP_JAVA_VERSION;Oracle" $2 }'
  cat /tmp/TeMpAPP2 | grep "JVM Vendor" | awk -F":" '{ print "APP_JAVA_VENDOR;" $2 }'

else
   echo "APP_APPSERVER_VERSION ;"
   echo "APP_JAVA_VERSION;"
   echo "APP_JAVA_VENDOR;"
fi

}

### OMNI SERVER ####
OmniGetData() {
#AllGetData OMNI

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;NA"
fi


if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


#if [ -d $installpathomni ];
# then
#  VTMIDDLEWAREBIN="$installpathomni/vt-net/bin/deviceHandler"

#if [ -f "$VTMIDDLEWAREBIN" ];
# then 
#  echo "CORE_VTMIDDLEWARE_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/deviceHandler -v  )
# else
#	echo "CORE_VTMIDDLEWARE_VERSION;NA"
#fi 
#fi

SSOHOST=$(/usr/bin/sudo -i docker service inspect veritran_workspace-api 2>/dev/null | grep traefik.http.routers.workspace-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')
SSOPORT=$(/usr/bin/sudo -i docker service inspect veritran_traefik 2>/dev/null | grep PublishedPort | head -n1 | cut -d ":" -f2 | cut -d "," -f1 | cut -d " " -f2)

if [ -n $SSOHOST ];
then
curl -k https://$SSOHOST:$SSOPORT/api > /tmp/ssoVer 2>/dev/null

ssoVer=$(cat /tmp/ssoVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_WORKSPACE_VERSION;"   $ssoVer
else
  echo "$1_WORKSPACE_VERSION;NA"
fi

AUDITHOST=$(/usr/bin/sudo -i docker service inspect veritran_audit-api 2>/dev/null | grep traefik.http.routers.audit-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $AUDITHOST ];
then
curl -k https://$AUDITHOST:$SSOPORT/api > /tmp/auditVer 2>/dev/null

auditVer=$(cat /tmp/auditVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_AUDIT_VERSION;"  $auditVer
else
  echo "$1_AUDIT_VERSION;NA"
fi

STATICSHOST=$(/usr/bin/sudo -i docker service inspect veritran_statics-api 2>/dev/null | grep traefik.http.routers.statics-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $STATICSHOST ];
then
curl -k https://$STATICSHOST:$SSOPORT/api > /tmp/staticsVer 2>/dev/null

staticsVer=$(cat /tmp/staticsVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_STATICS_VERSION;"  $staticsVer
else
  echo "$1_STATICS_VERSION;NA"
fi

HTSHOST=$(/usr/bin/sudo -i docker service inspect veritran_http-to-sql-api 2>/dev/null | grep traefik.http.routers.http-to-sql-api.rule | tail -n1 | awk '{ print $2'} | awk -F"\"" '{ print $3 }' |awk  -F"\\" '{ print $1 }')

if [ -n $HTSHOST ];
then
curl -k https://$HTSHOST:$SSOPORT/api > /tmp/htsVer 2>/dev/null

htsVer=$(cat /tmp/staticsVer | awk -F version\":\" '{ print $2 }' | cut -d "\"" -f1)
echo "$1_HTTP-TO-SQL_VERSION;"  $htsVer
else
  echo "$1_HTTP-TO-SQL_VERSION;NA"
fi

}


### CORE SERVER ####
CoreGetData() {
#AllGetData CORE

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724  php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 


if [ -d $intallpathcore ];
 then
  VTNETBIN="$installpathcore/vt-net/bin/kernel"

if [ -f "$VTNETBIN" ];
 then 
  echo "CORE_VTNET_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/kernel -v  )
 else
	echo "CORE_VTNET_VERSION;NA"
fi 
fi

if [ -d $intallpathcore ];
 then
  VTMIDDLEWAREBIN="$installpathcore/vt-net/bin/deviceHandler"

if [ -f "$VTMIDDLEWAREBIN" ];
 then 
  echo "CORE_VTMIDDLEWARE_VERSION;" $(sudo -i -u vt724 $installpathcore/vt-net/bin/deviceHandler -v  )
 else
	echo "CORE_VTMIDDLEWARE_VERSION;NA"
fi 
fi

if [ -d $intallpathcore ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathcore/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 


#if [ -f /veritran/vt-net/bin/vrtrDummyHost ];
 #then
 # for i in $(ls /veritran/vt-net/bin/*Host); do echo $i | awk -F'bin/' '{ print $2 ";" }' && sudo -i -u vt724 $i -V | grep Version | head -1 | awk '{ print $2 }' ; done > /tmp/TeMp4
#cat /tmp/TeMp4  
#else
#  echo "CORE_HOST_VERSION ;" >&2
#fi

if [ -f "$vtconsoleCoreCF" ];
then
vtconsoleVerPort=$(grep ".port=" $vtconsoleCoreCF | cut -d "=" -f2)
curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null

vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
echo "CORE_VTCONSOLE_VERSION;"   $vtconsoleVer
else
  echo "CORE_VTCONSOLE_VERSION;NA"
fi

##### VT724-CORE  #####

if [ -f "$vt724CoreCF" ];
then
vt724CoreVer=$(cat $vt724CoreCF | cut -d ":" -f2 )
echo "CORE_VT724_VERSION;"   $vt724CoreVer
else
  echo "CORE_VT724_VERSION;"
fi

fi


}


### AUTH SERVER ####
AuthGetData() {
#AllGetData AUTH

echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"


if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724  php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 



if [ -r $installpathauth ];
 then
  VTNETASBIN="$installpathauth/vt-net-as/bin/kernel"

if [ -f "$VTNETASBIN" ];
 then 
  echo "AUTH_VTNETAS_VERSION;" $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/kernel -v  | awk '{ print $2 }' )
 else
	echo "AUTH_VTNETAS_VERSION;"
fi 

if [ -r $installpathauth ];
 then
  VTASBIN="$installpathauth/vt-net-as/bin/tkAuthServer"

if [ -f "$VTASBIN" ];
 then 
  echo "AUTH_VTAS_VERSION;" $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/tkAuthServer -v  | awk '{ print $2 }' )
 else
	echo "AUTH_VTAS_VERSION;"
fi 
fi

if [ -d $installpathauth ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathauth/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 
fi

#echo "AUTH_VTAS_VERSION ;"  $(sudo -i -u vt724 $installpathauth/vt-net-as/bin/tkAuthServer -v | awk '{ print $2 }' ) 

##### VT724-AS  #####

if [ -f "$vt724AsCF" ];
then 
vt724AsVer=$(cat $vt724AsCF | cut -d ":" -f2 )
echo "AUTH_VT724_VERSION ;"   $vt724AsVer
else
	echo "AUTH_VT724_VERSION;"
fi 

fi
}

### NOTIF SERVER ####
NotifGetData() {
#set -x
echo "$1_SERVERNAME; $hostname"
echo "$1_IPADDRESS; $IP"
echo "$1_SISTEMAOPERATIVO; $(grep -i pretty /etc/*release | awk -F "\"" '{ print $2 }')"

if [ -f "/usr/sbin/httpd" ];
then
  echo "$1_WEBSERVER_VERSION;$(/usr/sbin/httpd -v | head -n1 | awk -F":" '{ print $2 }' | awk -F"(" '{ print $1 }')"
  WEBSERVER=APACHE
else
   echo "$1_WEBSERVER_VERSION;"
fi

if [ -f /usr/bin/php ]
 then
 PHPVER=$(/usr/bin/sudo -i -u vt724 php -v 2>/dev/null | head -n1 | awk -F"(" '{ print $1 }'| awk '{ print $2 }')
 echo "$1_PHP_VERSION; $PHPVER"
 else
   echo "$1_PHP_VERSION;NA"
fi

if [ -f /usr/bin/docker ];
 then 
  echo "$1_DOCKER_VERSION ; $(/usr/bin/docker -v | awk -F"," '{ print $1 }' | awk -F"version " '{ print $2 }') "
 else
	echo "$1_DOCKER_VERSION;NA"
fi 

vtconsoleNotifCF="$installpathnotif/vt-console-notif/config/application.properties"
vtNFconsoleCF="$installpathnotif/vt-notif/config/application.properties"
vtNFnodeCF="$installpathnotif/nfnode/config/application.properties"
vtNFconsolenotifCF="$installpathnotif/nfconsole/config/application.properties"



if [ -r $installpathnotif ];
 then
  VTNETNOTIFBIN="$installpathnotif/vt-net-notif/bin/kernel"

  if [ -f "$VTNETNOTIFBIN" ];
   then 
     NOTIFVERSION=$(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/kernel -v )
     notifregex="1.13.5.*"
    if [[ $NOTIFVERSION =~ $notifregex ]]; then 
      echo "NOTIF_VTNETNOTIF_VERSION; $NOTIFVERSION"
    else
      NOTIFVERSION=$(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/kernel -v  | awk '{ print $2 }' )
	    echo "NOTIF_VTNETNOTIF_VERSION; $NOTIFVERSION"
fi 


if [ -r $installpathnotif ];
 then
  VTNOTIFBIN="$installpathnotif/vt-net-notif/bin/vtNotifServer"

if [ -f "$VTNOTIFBIN" ];
 then 
  echo "NOTIF_VTNOTIF_VERSION;" $(sudo -i -u vt724 $installpathnotif/vt-net-notif/bin/vtNotifServer -v  | awk '{ print $2 }' )

 else
	echo "NOTIF_VTNOTIF_VERSION;"
fi 
fi

if [ -d $installpathnotif ];
 then
  TNSDBS=$(sudo -i -u vt724 grep -v \# $installpathnotif/share/network/admin/tnsnames.ora | awk -F"[ =]" '/DESCRIPTION/ { print X }{ X=$1 }')
if [ -n "$TNSDBS" ];
 then 
  ParseaTNS $1 $TNSDBS
 else
	echo "$1_TNSDBS;NA"
fi 
fi


if [ -f "$vtconsoleNotifCF" ];
 then 
  vtconsoleVerPort=$(grep ".port=" $vtconsoleNotifCF | cut -d "=" -f2)
  curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null
  vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
  echo "NOTIF_NFNODE_VERSION ;"   $vtconsoleVer
 else
  echo "NOTIF_NFNODE_VERSION;"
fi 

if [ -f "$vtNFconsoleCF" ];
 then
  vtNFconsoleVerPort=$(grep application.port $vtNFconsoleCF | cut -d "=" -f2)
  curl -k http://localhost:$vtNFconsoleVerPort/configuration > /tmp/vtNFconsoleVer 2>/dev/null
  vtNFconsoleVer=$(cut -d "\"" -f18 /tmp/vtNFconsoleVer)
  echo "NOTIF_NFCONSOLE_VERSION ;"   $vtNFconsoleVer
 else
  echo "NOTIF_NFCONSOLE_VERSION;"
fi

if [ -f "$vtNFnodeCF" ];
 then 
  vtconsoleVerPort=$(grep ".port=" $vtNFnodeCF | cut -d "=" -f2)
  curl -k http://localhost:$vtconsoleVerPort/vt-console/authentication/version > /tmp/vtconsoleVer 2>/dev/null
  vtconsoleVer=$(cut -d "\"" -f22 /tmp/vtconsoleVer)
  echo "NOTIF_NFNODE_VERSION ;"   $vtconsoleVer
 else
  echo "NOTIF_NFNODE_VERSION;"
fi 

if [ -f "$vtNFconsolenotifCF" ];
 then
  vtNFconsoleVerPort=$(grep application.port $vtNFconsolenotifCF | cut -d "=" -f2)
  curl -k http://localhost:$vtNFconsoleVerPort/configuration > /tmp/vtNFconsoleVer 2>/dev/null
  vtNFconsoleVer=$(cut -d "\"" -f18 /tmp/vtNFconsoleVer)
  echo "NOTIF_NFCONSOLE_VERSION ;"  $vtNFconsoleVer
 else
  echo "NOTIF_NFCONSOLE_VERSION;"
fi

fi
fi

}

## MAIN ##

case "$1" in
  COMM | comm)
    CommGetData
    rm -f /tmp/TeMp*
    ;;

  APPSRV | appsrv)
    AppsrvGetData
    rm -f /tmp/TeMp*
    ;;

  CORE | core)
    CoreGetData
    rm -f /tmp/TeMp*
    ;;

  AUTH | auth)
    AuthGetData
    rm -f /tmp/TeMp*
    ;;

  NOTIF | notif)
    NotifGetData
    rm -f /tmp/TeMp*
    ;;

  OMNI | omni)
    OmniGetData
    rm -f /tmp/TeMp*
    ;;

  STUDIO | studio)
    StudioGetData
    rm -f /tmp/TeMp*
    ;;

  AUTO | auto)
    AutoGetData
    rm -f /tmp/TeMp*
    ;;

    ALL)
    CommGetData
    CoreGetData
    AuthGetData
    NotifGetData
    AppsrvGetData
    OmniGetData
    rm -f /tmp/TeMp*
    ;;


  *)
    echo "Usage: $0 {COMM|CORE|AUTH|NOTIF|APPSRV|OMNI}"
    ;;
esac

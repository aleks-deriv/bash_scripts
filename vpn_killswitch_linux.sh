#!/bin/bash

pip3 install requests || true

py_loc=`which python3`

cat <<EOT > /opt/vpn_killswitch.py
#!${py_loc}
import requests
import os, platform, sys, datetime
import json, getpass
import subprocess
import netifaces
from uuid import getnode as get_mac
api_url = "http://vpnmonitoring.deriv.cloud/ipcheck"
api_url_notify = "http://vpnmonitoring.deriv.cloud/notify"
geoIP_url = "https://ipinfo.io"
action = ""
username = ""
geo = requests.get(geoIP_url).json()
if sys.platform.startswith('win32'):
	username = ""
	wifi_ssid = ""
elif sys.platform.startswith('linux'):
	username = subprocess.check_output("echo $SUDO_USER", shell=True).rstrip()
	wifi_ssid = subprocess.check_output("iw dev | grep ssid | awk {'for (i=2; i<=NF; i++) printf\"%s \",\$i'}", shell=True).rstrip().decode('utf-8')
	if wifi_ssid == "":
		wifi_ssid = subprocess.check_output("nmcli --fields IN-USE,SSID device wifi | grep  \* | awk 'BEGIN {IGNORECASE = 1} !/SSID/' | awk '{for (i=2; i<NF; i++) printf \$i \" \"; print \$NF}' | awk 'NR == 1'", shell=True).rstrip().decode('utf-8')
elif sys.platform.startswith('darwin'):
	username = subprocess.check_output("users", shell=True).rstrip()
	wifi_ssid = subprocess.check_output("/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F: '/ SSID/{print \$2}'", shell=True).rstrip()
	wifi_ssid = wifi_ssid.strip().decode("utf-8").replace('SSID: ', '')
	
if wifi_ssid == "RMGTech 5GHz" :
	office = "Malaysia"
elif wifi_ssid == "Binary Malta 5GHz" :
	office = "Malta"
elif wifi_ssid == "Binary-BPSA" :
	office = "Paraguay"
elif wifi_ssid == "Binary-DMCC" :
	office = "Dubai"
elif wifi_ssid == "FS" :
	office = "FirstSource"
elif wifi_ssid == "jy" :
	office = "Malaysia"
else :
	office = "unknown"
x = {
  "os": platform.system(), 
  "name": username,
  "wifi_ssid" : wifi_ssid,
  "mac_add" : netifaces.ifaddresses('enp4s0')[17][0]['addr'], # get_mac(),
  "office" : office
}
try:
	action = requests.get(api_url, params=x).json()
	action = action['isValid']
except:
	action =""
print("{}- Client data: {}".format(datetime.datetime.now(), x))
print("{}- Action Code: {}".format(datetime.datetime.now(), action))
try:
    country_code = geo["country"]
except:
    print("{}- Exception thrown no country code".format(datetime.datetime.now()))
    country_code = ""
if (country_code == "BY" or country_code == "IR" ) :
	#notify = requests.get(api_url_notify, params=x).json()
	#print("{}- {}".format(datetime.datetime.now(), notify))
	if sys.platform.startswith('win32'):
		os.system("netsh wlan delete profile name=* i=*.")
	elif sys.platform.startswith('linux'):
		os.system("rfkill block all")
	elif sys.platform.startswith('darwin'):
		cmd = '/usr/sbin/networksetup -listallhardwareports | awk "/Wi-Fi/,/Ethernet Address/" | awk "NR==2" | cut -d " " -f 2'
		interface = subprocess.check_output(cmd, shell=True).rstrip()
		cmd = "networksetup -removepreferredwirelessnetwork " + interface.decode("utf-8") + " " + wifi_ssid			
		os.system(cmd)
		cmd = 'networksetup -listallnetworkservices | while read -r line; do networksetup -setnetworkserviceenabled "\$line" off; done'
		os.system(cmd)
EOT

runscript=`chmod +x /opt/vpn_killswitch.py`
echo $?

if [[ $(crontab -l | grep -q 'vpn_killswitch'; echo $?) == 1 ]]
then
    { echo "* * * * * ${py_loc} /opt/vpn_killswitch.py >> /tmp/vpnkillswitch.log";} | crontab -
    exit 0
else
    exit 0
fi

exit 0



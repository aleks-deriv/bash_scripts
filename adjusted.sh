#!$/usr/local/bin/python3
import requests
import os, platform, sys, datetime
import json, getpass
import subprocess
import re
from uuid import getnode as get_mac
api_url = "http://monitor.firstsource.tech/ipcheck"
api_url_notify = "http://monitor.firstsource.tech/notify"
geoIP_url = "http://monitor.firstsource.tech/geoip"
action = ""
username = ""
geo = requests.get(geoIP_url).json()
if sys.platform.startswith('win32'):
	username = ""
	wifi_ssid = ""
elif sys.platform.startswith('linux'):
	username = subprocess.check_output("hostname").rstrip()
	wifi_ssid = subprocess.check_output("iw dev | grep ssid | awk {'for (i=2; i<=NF; i++) printf\"%s \",\$i'}", shell=True).rstrip().decode('utf-8')
	if wifi_ssid == "":
		wifi_ssid = subprocess.check_output("nmcli --fields IN-USE,SSID device wifi | grep  \* | awk 'BEGIN {IGNORECASE = 1} !/SSID/' | awk '{for (i=2; i<NF; i++) printf \$i \" \"; print \$NF}' | awk 'NR == 1'", shell=True).rstrip().decode('utf-8')
elif sys.platform.startswith('darwin'):
	username = subprocess.check_output("users", shell=True).rstrip()
	wifi_ssid = subprocess.check_output("/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F: '/ SSID/{print $2}'", shell=True).rstrip()
	wifi_ssid = wifi_ssid.strip().decode("utf-8").replace('SSID: ', '')

def f(wifi_ssid):
    office_by_ssid = {
        "Deriv": "Deriv.*"
    }

    for office, regex in office_by_ssid.items():
        if re.fullmatch(regex, wifi_ssid):
            return office
    return "fallback"

office = f(wifi_ssid)

	
x = {
  "os": platform.system(), 
  "name": username,
  "wifi_ssid" : wifi_ssid,
  "mac_add" : get_mac(),
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
if (country_code == "BY" or country_code == "IR" ) and (action == 0) :
	notify = requests.get(api_url_notify, params=x).json()
	print("{}- {}".format(datetime.datetime.now(), notify))
	if sys.platform.startswith('win32'):
		os.system("netsh wlan delete profile name=* i=*.")
	elif sys.platform.startswith('linux'):
		os.system("rfkill block all")
	elif sys.platform.startswith('darwin'):
		cmd = '/usr/sbin/networksetup -listallhardwareports | awk "/Wi-Fi/,/Ethernet Address/" | awk "NR==2" | cut -d " " -f 2'
		interface = subprocess.check_output(cmd, shell=True).rstrip()
		cmd = "/usr/sbin/networksetup -removepreferredwirelessnetwork " + interface.decode("utf-8") + " " + wifi_ssid			
		os.system(cmd)
		cmd = '/usr/sbin/networksetup -listallnetworkservices | while read -r line; do /usr/sbin/networksetup -setnetworkserviceenabled "\$line" off; done'
		os.system(cmd)

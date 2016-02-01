##openvpn-install
OpenVPN [road warrior](http://en.wikipedia.org/wiki/Road_warrior_%28computing%29) installer for Entware-NG running on NDMS v.2.
Please see http://keenopt.ru and http://forums.zyxmon.org

This script will let you setup your own VPN server in a few  minutes, even if you haven't used OpenVPN before. It isn't bulletproof but has been designed to be as unobtrusive and universal as possible.

###Installation
 
Please check that you have a openvpn installed !

Run the script and follow the assistant:  
`opkg update`  
`opkg install bash wget openssl-util`  
`wget --no-check-certificate https://raw.githubusercontent.com/kpoxxx/openvpn-install/master/openvpn-install.sh -O openvpn-install.sh && bash openvpn-install.sh`

Once it ends, you can run it again to add more users or remove some of them.

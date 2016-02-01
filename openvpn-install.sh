#!/opt/bin/bash
#OpenVPN road warrior installer for Entware-NG running on NDMS v.2. Please see http://keenopt.ru and http://forums.zyxmon.org
#This script will let you setup your own VPN server in a few minutes, even if you haven't used OpenVPN before

if [[ ! -e /dev/net/tun ]]; then
    echo "TUN/TAP is not available"
    exit 1
fi

newclient () {
    # Generates the custom client.ovpn
    cp /opt/etc/openvpn/client-common.txt ~/$1.ovpn
    echo "<ca>" >> ~/$1.ovpn
    cat /opt/etc/openvpn/easy-rsa/pki/ca.crt >> ~/$1.ovpn
    echo "</ca>" >> ~/$1.ovpn
    echo "<cert>" >> ~/$1.ovpn
    cat /opt/etc/openvpn/easy-rsa/pki/issued/$1.crt >> ~/$1.ovpn
    echo "</cert>" >> ~/$1.ovpn
    echo "<key>" >> ~/$1.ovpn
    cat /opt/etc/openvpn/easy-rsa/pki/private/$1.key >> ~/$1.ovpn
    echo "</key>" >> ~/$1.ovpn
}

echo "Getting your ip address....please wait."
IP=$(wget -qO- ipv4.icanhazip.com)


if [[ -e /opt/etc/openvpn/openvpn.conf ]]; then
    while :
    do
    clear
	echo "Looks like OpenVPN is already installed"
	echo ""
	echo "What do you want to do?"
	echo "   1) Add a cert for a new user"
	echo "   2) Revoke existing user cert"
	echo "   3) Exit"
	read -p "Select an option [1-3]: " option
	case $option in
	    1) 
	    echo ""
	    echo "Tell me a name for the client cert"
	    echo "Please, use one word only, no special characters"
	    read -p "Client name: " -e -i client CLIENT
	    cd /opt/etc/openvpn/easy-rsa/
	    ./easyrsa build-client-full $CLIENT nopass
	    # Generates the custom client.ovpn
	    newclient "$CLIENT"
	    echo ""
	    echo "Client $CLIENT added, certs available at ~/$CLIENT.ovpn"
	    exit
	    ;;
	    2)
	    # This option could be documented a bit better and maybe even be simplimplified
	    # ...but what can I say, I want some sleep too
	    NUMBEROFCLIENTS=$(tail -n +2 /opt/etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	    if [[ "$NUMBEROFCLIENTS" = '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 5
	    fi
	    echo ""
	    echo "Select the existing client certificate you want to revoke"
	    tail -n +2 /opt/etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 
	    if [[ "$NUMBEROFCLIENTS" = '1' ]]; then
		read -p "Select one client [1]: " CLIENTNUMBER
	    else
		read -p "Select one client [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
	    fi
	    CLIENT=$(tail -n +2 /opt/etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
	    cd /opt/etc/openvpn/easy-rsa/
	    ./easyrsa --batch revoke $CLIENT
	    ./easyrsa gen-crl
	    rm -rf pki/reqs/$CLIENT.req
	    rm -rf pki/private/$CLIENT.key
	    rm -rf pki/issued/$CLIENT.crt
	    # And restart
	    /opt/etc/init.d/S20openvpn restart
	    
	    echo ""
	    echo "Certificate for client $CLIENT revoked"
	    exit
	    ;;
	    3) exit;;
	esac
    done
else
    clear
    echo 'Welcome to this quick OpenVPN "road warrior" installer'
    echo ""
    # OpenVPN setup and first user creation
    echo "I need to ask you a few questions before starting the setup"
    echo "You can leave the default options and just press enter if you are ok with them"
    echo ""
    echo "First I need to know the IPv4 address of the network interface you want OpenVPN"
    echo "listening to."
    read -p "IP address: " -e -i $IP IP
    echo ""
    echo "What port do you want for OpenVPN?"
    read -p "Port: " -e -i 1194 PORT
    echo ""
    echo "What DNS do you want to use with the VPN?"
    echo "   1) Current system resolvers"
    echo "   2) OpenDNS"
    echo "   3) Level 3"
    echo "   4) NTT"
    echo "   5) Hurricane Electric"
    echo "   6) Google"
    read -p "DNS [1-6]: " -e -i 1 DNS
    echo ""
    echo "Finally, tell me your name for the client cert"
    echo "Please, use one word only, no special characters"
    read -p "Client name: " -e -i client CLIENT
    echo ""
    echo "Okay, that was all I needed. We are ready to setup your OpenVPN server now"
    read -n1 -r -p "Press any key to continue..."

    # An old version of easy-rsa was available by default in some openvpn packages
    if [[ -d /opt/etc/openvpn/easy-rsa/ ]]; then
	mv /opt/etc/openvpn/easy-rsa/ /opt/etc/openvpn/easy-rsa-old/
    fi
    # Get easy-rsa
    wget --no-check-certificate -O ~/EasyRSA-3.0.1.tgz https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz
    tar xzf ~/EasyRSA-3.0.1.tgz -C ~/
    mv ~/EasyRSA-3.0.1/ /opt/etc/openvpn/
    mv /opt/etc/openvpn/EasyRSA-3.0.1/ /opt/etc/openvpn/easy-rsa/
    chown -R root:root /opt/etc/openvpn/easy-rsa/
    rm -rf ~/EasyRSA-3.0.1.tgz
    cd /opt/etc/openvpn/easy-rsa/
    # Create the PKI, set up the CA, the DH params and the server + client certificates
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa build-server-full server nopass
    ./easyrsa build-client-full $CLIENT nopass
    ./easyrsa gen-crl
    # Move the stuff we need
    cp pki/ca.crt pki/private/ca.key pki/dh.pem pki/issued/server.crt pki/private/server.key /opt/etc/openvpn
    # Generate openvpn.conf
    echo "port $PORT
proto udp
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" > /opt/etc/openvpn/openvpn.conf
    echo 'push "redirect-gateway def1 bypass-dhcp"' >> /opt/etc/openvpn/openvpn.conf
    # DNS
    case $DNS in
	1) 
	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	grep -v '#' /etc/resolv.conf | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
	    echo "push \"dhcp-option DNS $line\"" >> /opt/etc/openvpn/openvpn.conf
	done
	;;
	2)
	echo 'push "dhcp-option DNS 208.67.222.222"' >> /opt/etc/openvpn/openvpn.conf
	echo 'push "dhcp-option DNS 208.67.220.220"' >> /opt/etc/openvpn/openvpn.conf
	;;
	3) 
	echo 'push "dhcp-option DNS 4.2.2.2"' >> /opt/etc/openvpn/openvpn.conf
	echo 'push "dhcp-option DNS 4.2.2.4"' >> /opt/etc/openvpn/openvpn.conf
	;;
	4) 
	echo 'push "dhcp-option DNS 129.250.35.250"' >> /opt/etc/openvpn/openvpn.conf
	echo 'push "dhcp-option DNS 129.250.35.251"' >> /opt/etc/openvpn/openvpn.conf
	;;
	5) 
	echo 'push "dhcp-option DNS 74.82.42.42"' >> /opt/etc/openvpn/openvpn.conf
	;;
	6) 
	echo 'push "dhcp-option DNS 8.8.8.8"' >> /opt/etc/openvpn/openvpn.conf
	echo 'push "dhcp-option DNS 8.8.4.4"' >> /opt/etc/openvpn/openvpn.conf
	;;
    esac
    echo "keepalive 10 120
comp-lzo
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify /opt/etc/openvpn/easy-rsa/pki/crl.pem" >> /opt/etc/openvpn/openvpn.conf

    echo "#!/bin/sh

[ \"\$table\" != "filter" ] && exit 0   # check the table name
iptables -I FORWARD -i br0 -o tun0 -j ACCEPT
iptables -I FORWARD -i tun0 -o br0 -j ACCEPT
iptables -I INPUT -i tun0 -j ACCEPT
iptables -I INPUT -p udp --dport $PORT -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT" >> /opt/etc/ndm/netfilter.d/052-openvpn-filter.sh

chmod +x /opt/etc/ndm/netfilter.d/052-openvpn-filter.sh

echo "#!/bin/sh

[ \"\$table\" != "nat" ] && exit 0   # check the table name
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP" >> /opt/etc/ndm/netfilter.d/053-openvpn-nat.sh

chmod +x /opt/etc/ndm/netfilter.d/053-openvpn-nat.sh

    echo "client
dev tun
proto udp
sndbuf 0
rcvbuf 0
remote $IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
comp-lzo
verb 3" > /opt/etc/openvpn/client-common.txt
    # Generates the custom client.ovpn
    newclient "$CLIENT"
    echo ""
    echo "Finished!"
    echo ""
    echo "Your client config is available at ~/$CLIENT.ovpn"
    echo "If you want to add more clients, you simply need to run this script another time!"
fi

#! /bin/bash

iface="$1"
oface="$2"
dbw=$3
ubw=$4
SIMPLE_SHAPER_VERSION=0.0.1-SNAPSHOT

display_version() {
echo "simpleshaper v $SIMPLE_SHAPER_VERSION 2014"
echo "created by Yahya Alfayad"
}

die_msg() {
echo "usage is:"
echo "sh simpleshaper.sh <input_interface> <output_interface> <download_bandwidth> <upload_bandwidth>"
echo
echo "where:"
echo
echo "<input_interface> : the name of interface which has the internet connection"
echo "<output_interface> : the name of interface of the local network"
echo "<download_bandwidth> : the total internet download bandwidth in KB"
echo "<upload_bandwidth> : the totalinternat upload bandwidth in KB"
echo
echo "or:"
echo "sh simpleshaper status <device>"
}

# show_status <dev>
show_status() {
echo "status:"
tc -s qdisc show dev $1
}

# stop_shaper 
stop_shaper() {
tc qdisc del dev $iface root
iptables -t mangle -F SIMPLESHAPEROUT
iptables -t mangle -D POSTROUTING -o $oface -j SIMPLESHAPEROUT
iptabels -t mangle -D FORWARD -o $oface -j SIMPLESHAPEROUT
iptables -t mangle -X SIMPLESHAPEROUT
}

# shape_upload <dev>
# where <dev> is the interface connected to the internet
shape_upload() {
tc qdisc add dev $1 root handle 1: htb default 22
tc class add dev $1 parent 1: classid 1:1 htb rate ${ubw}kbit
# first class is http browsing class 20
tc class add dev $1 parent 1:1 classid 1:20 htb rate ${$ubw/3}kbit ceil ${ubw}kbit prio 0
# second class is video streaming class 21
tc class add dev $1 parent 1:1 classis 1:21 htb rate ${$ubw/3}kbit ceil ${ubw}kbit prio 1
# third class is file uploading class 22
tc class add dev $1 parent 1:1 classid 1:22 htb rate ${$ubw/3}kbit ceil ${ubw}kbit prio 2

tc qdisc add dev $1 parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev $1 parent 1:21 handle 21: sfq perturb 10
tc qdisc add dev $1 parent 1:22 handle 22: sfq perturb 10

tc filter add dev $1 parent 1:0 prio 0 protocol ip handle 20 fw flowid 1:20
tc filter add dev $1 parent 1:0 prio 0 protocol ip handle 21 fw flowid 1:21
tc filter add dev $1 parent 1:0 prio 0 protocol ip handle 22 fw flowid 1:22

# create shaper chain
iptables -t mangle -N SIMPLESHAPEROUT
iptables -t mangle -I POSTROUTING -o $1 -j SIMPLESHAPEROUT
iptables -t mangle -I FORWARD -o $1 -j SIMPLESHAPEROUT
# mark big files for low priority
iptables -t mangle -A SIMPLESHAPEROUT -p tcp -m connbytes --connbytes 1048576 -j MARK --set-mark 22
# mark icmp for high priority
iptables -t mangle -A SIMPLESHPAEROUT -p icmp -j MARK --set-mark 20
# mark http traffic for high priority
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 80 -j MARK --set-mark 20
# small packets eg: ACKs
iptables -t mangle -A SIMPLESHAPEROUT -p tcp -m length --length :64 -j MARK --set-mark 20
# mark dns traffic for high priority
iptables -t mangle -A SIMPLESHAPEROUT -p udp --dport 53 -j MARK --set-mark 20
# mark dhcp traffic for high priority
iptables -t mangle -A SIMPLESHAPEROUT -p udp --dport 67 -j MARK --set-mark 20
iptables -t mangle -A SIMPLESHAPEROUT -p udp --sport 68 -j MARK --set-mark 20

# mark email traffic for high priority
# SMTP
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 25 -j MARK --set-mark 20
# IMAP
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 143 -j MARK --set-mark 20
# IMAP-SSL
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 993 -j MARK --set-mark 20
# POP3
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 110 -j MARK --set-mark 20
# POP3-SSL
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 995 -j MARK --set-mark 20
# LDAP
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 389 -j MARK --set-mark 20
# LDAP-SSL
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 636 -j MARK --set-mark 20

# Mark FTP Traffic
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 21 -j MARK --set-mark 22

# mark udp traffic for medium priority
iptables -t mangle -A SIMPLESHAPEROUT -p udp -j MARK --set-mark 21
# mark non http traffic for low priority
iptables -t mangle -A SIMPLESHAPEROUT -p tcp ! --dport 80 -jMARK --set-mark 22
}

if [ "$1" == "status" ] && [ ! -z "$2" ]
then
show_status $2
exit 0
fi

if [ -z "$1" ] ||  [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] 
then
display_version
die_msg
fi


#! /bin/bash

iface="$1"
oface="$2"
dbw=$3
ubw=$4

display_version() {
echo "simpleshaper v 1.0 2014"
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
iptables -t mangle -D POSTROUTING -i $iface -o $oface -j SIMPLESHAPEROUT
iptables -t mangle -X SIMPLESHAPEROUT
}

# shape_upload <dev>
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
iptables -t mangle -I POSTROUTING -i $iface -o $oface -j SIMPLESHAPEROUT

iptables -t mangle -A SIMPLESHAPEROUT -p tcp -m connbytes --connbytes 1048576 -j MARK --set-mark 22
iptables -t mangle -A SIMPLESHAPEROUT -p tcp --dport 80 -j MARK --set-mark 20
iptables -t mangle -A SIMPLESHAPEROUT -p tcp -m length --length :64 -j MARK --set-mark 20
iptables -t mangle -A SIMPLESHAPEROUT -p udp -j MARK --set-mark 21
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


#!/bin/bash

echo "Beforehand, turn on Internet Sharing"
echo ""
echo ""

# List all utunX interfaces with details
echo "Available utunX (VPN) interfaces:"
utun_list=()
i=1
while read -r line; do
    iface=$(echo "$line" | awk '{print $1}' | sed 's/://')
    # Gather details for this interface
    block=$(ifconfig $iface)
    ipv4=$(echo "$block" | grep 'inet ' | awk '{print $2}')
    ipv6=$(echo "$block" | grep 'inet6 ' | awk '{print $2}')
    p2p=$(echo "$block" | grep 'inet ' | awk '/-->/ {print $2 " --> " $4}')
    echo "$i) $iface"
    [ -n "$ipv4" ] && echo "   IPv4: $ipv4"
    [ -n "$ipv6" ] && echo "   IPv6: $ipv6"
    [ -n "$p2p" ] && echo "   P2P: $p2p"
    utun_list+=("$iface")
    i=$((i+1))
done < <(ifconfig | grep -E '^utun[0-9]+:')

# Prompt for VPN interface
read -p "Select the number for your VPN interface: " vpn_idx
vpn_iface=${utun_list[$((vpn_idx-1))]}

# List all active interfaces for Internet Sharing
echo "Active network interfaces:"
active_ifaces=()
i=1
while read -r iface; do
    if ifconfig "$iface" | grep -q "status: active"; then
        echo "$i) $iface"
        active_ifaces+=("$iface")
        i=$((i+1))
    fi
done < <(ifconfig | grep '^[a-z0-9]' | awk -F: '{print $1}' | sort | uniq)

if [ ${#active_ifaces[@]} -eq 0 ]; then
    echo "No active interfaces found."
fi

# Prompt for selection as before
read -p "Select the number for your Internet Sharing (WiFi/bridge) interface: " idx
bridge_iface=${active_ifaces[$((idx-1))]}

# Confirm selections
echo "Selected VPN interface: $vpn_iface"
echo "Selected Internet Sharing interface: $bridge_iface"

# Create NAT rule file
cat <<EOF > pf-nat.conf
nat on $vpn_iface from $bridge_iface:network to any -> ($vpn_iface)
EOF

# Enable IP forwarding and apply NAT rules
sudo sysctl -w net.inet.ip.forwarding=1
sudo pfctl -F all
sudo pfctl -f pf-nat.conf -e

echo ""
echo ""
echo "NAT routing enabled. To disable, run: sudo pfctl -d"
echo "To start/stop DNS forwarding using dnsmasq.conf, run either: 'sudo brew services start dnsmasq' OR 'sudo brew services stop dnsmasq'"
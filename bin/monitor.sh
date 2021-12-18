#!/bin/bash
clear
readonly BOLD=$'\e[1m'
readonly RED=$'\e[1;31m'
readonly GREEN=$'\e[1;32m'
readonly RESET=$'\e[0m'
readonly YMD=$(date '+%y/%m/%d %H:%M:%S')
unset tecreset os architecture kernelrelease internalip externalip nameserver loadaverage
sh ./cpu.sh >/tmp/cpustate

# Define Variable tecreset
tecreset=$(tput sgr0)

# Check if connected to Internet or not
ping -c 1 google.com &>/dev/null && echo -e "$GREEN  Internet: $tecreset Connected" || echo -e "$GREEN  Internet: $tecreset Disconnected"

# Check OS Type
os=$(uname -o)
echo -e "$GREEN  Operating System Type :" $tecreset $os

# Check OS Release Version and Name
echo -n -e "$GREEN  OS :" $tecreset && cat /etc/os-release | grep "PRETTY_NAME" | cut -f2 -d\"

# Check Architecture
architecture=$(uname -m)
echo -e "$GREEN  Architecture :" $tecreset $architecture

# Check Kernel Release
kernelrelease=$(uname -r)
echo -e "$GREEN  Kernel Release :" $tecreset $kernelrelease

# Check hostname
echo -e "$GREEN  Hostname :" $tecreset $HOSTNAME

# Check Internal IP
internalip=$(hostname -I)
echo -e "$GREEN  Internal IP :" $tecreset $internalip

# Check External IP
externalip=$(
  curl -s ipecho.net/plain
  echo
)
echo -e "$GREEN  External IP : $tecreset "$externalip

# Check DNS
nameservers=$(cat /etc/resolv.conf | sed '1 d' | awk '{print $2}')
echo -e "$GREEN  Name Servers :" $tecreset $nameservers

# Check Logged In Users
who >/tmp/who
echo -e "$GREEN  Logged In users :" $tecreset && cat /tmp/who

# Check RAM and SWAP Usages
free -h | grep -v + >/tmp/ramcache
echo -e "$GREEN  Ram Usages :" $tecreset
cat /tmp/ramcache | grep -v "Swap"
echo -e "$GREEN  Swap Usages :" $tecreset
cat /tmp/ramcache | grep -v "Mem"

# Check CPU Usages
echo -e "$GREEN  CPU Usages :" $tecreset
cat /tmp/cpunames
echo ""
cat /tmp/cpustates
echo ""

# Check Disk Usages
df -h | grep 'Filesystem\|/dev/vda*' >/tmp/diskusage
echo -e "$GREEN  Disk Usages :" $tecreset
cat /tmp/diskusage

# Check Load Average
loadaverage=$(top -n 1 -b | grep "load average:" | awk '{print $10 $11 $12}')
echo -e "$GREEN  Load Average :" $tecreset $loadaverage

# Check System Uptime
tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
echo -e "$GREEN  System Uptime Days/(HH:MM) :" $tecreset $tecuptime

# Unset Variables
unset tecreset os architecture kernelrelease internalip externalip nameserver loadaverage

# Remove Temporary Files
rm /tmp/who /tmp/ramcache /tmp/diskusage /tmp/cpunames /tmp/cpustates -f

#!/bin/bash
# Wazuh Active Response — Suricata IP Auto-Block Script
# File location: /var/ossec/active-response/bin/suricata-drop.sh
# Author: Rakibul Islam Joy | Security Engineer | Unified IT
# Purpose: Automatically block attacker IPs detected by Suricata IDS via iptables
#
# How it works:
# 1. Suricata detects suspicious traffic and writes alert to eve.json
# 2. Wazuh Agent reads eve.json and forwards to Wazuh Manager
# 3. Rule 86701 fires (level 7) for any Suricata alert
# 4. Manager sends active-response command to this agent
# 5. This script reads the alert JSON from stdin (Wazuh 4.x method)
# 6. Extracts src_ip from the alert data
# 7. Checks if IP is already blocked — skips duplicate iptables entries
# 8. Blocks the IP using iptables and logs the action
#
# IMPORTANT: Wazuh 4.x sends alert JSON via stdin — NOT as $1/$2/$3/$4 arguments.
# Scripts that read command-line args will fail with "Cannot read srcip from data".
#
# FIX for duplicate blocking:
# Using iptables -I without checking first causes the same IP to be inserted
# multiple times (once per alert). This script checks first and skips if already blocked.

LOG=/var/ossec/logs/active-responses.log

# Read the full alert JSON sent by Wazuh Manager via stdin
read -r INPUT

# Extract the attacker's source IP from the nested JSON structure
SRC_IP=$(echo "$INPUT" | grep -oP '"parameters".*?"alert".*?"data".*?"src_ip":"\K[^"]+' | head -1)

if [ -z "$SRC_IP" ]; then
    echo "$(date) - suricata-drop: Cannot find src_ip in alert (may be non-IP alert like Ethertype unknown)" >> $LOG
    exit 1
fi

# Check if this IP is already blocked — prevent duplicate iptables entries
if iptables -L INPUT -n | grep -q "$SRC_IP"; then
    echo "$(date) - suricata-drop: $SRC_IP already blocked, skipping" >> $LOG
    exit 0
fi

echo "$(date) - suricata-drop: Blocking IP $SRC_IP" >> $LOG
iptables -I INPUT -s $SRC_IP -j DROP
iptables -I FORWARD -s $SRC_IP -j DROP

exit 0

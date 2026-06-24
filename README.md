# Wazuh + Suricata IDS Integration
### Network Intrusion Detection & Auto-Block

> **Author:** Rakibul Islam Joy — Security Engineer | Unified IT  
> **GitHub:** [github.com/rakibuljoy](https://github.com/rakibuljoy)  
> **LinkedIn:** [linkedin.com/in/rakibul-islam-joy-4166a3242](https://linkedin.com/in/rakibul-islam-joy-4166a3242)  
> **Tested on:** Wazuh 4.14.5 | Suricata 8.0.5 | Ubuntu 22.04

---

## What This Does

This integration connects **Suricata IDS** with **Wazuh SIEM** to automatically detect and block network attacks in real-time.

```
Attack arrives on network
        ↓
Suricata monitors traffic on ens33 (50,861 rules)
        ↓
Suspicious packet detected → alert written to eve.json
        ↓
Wazuh Agent reads eve.json → forwards to Wazuh Manager
        ↓
Custom rule 86701 fires (Level 7)
        ↓
suricata-drop.sh runs → iptables blocks attacker IP
        ↓
Alert visible in Wazuh Dashboard ✅
```

---

## Environment

| Component | Details |
|---|---|
| Wazuh Manager | Ubuntu Server 22.04 (wazuh-soc) |
| Wazuh Agent | Ubuntu Desktop 22.04 (rakib-virtual-machine) |
| Wazuh Version | 4.14.5 |
| Suricata Version | 8.0.5 |
| Network Interface | ens33 |

---

## Files in This Repository

| File | Where it goes | Purpose |
|---|---|---|
| `suricata-drop.sh` | Agent: `/var/ossec/active-response/bin/` | Auto-blocks attacker IP via iptables |
| `suricata_local_rules.xml` | Manager: `/var/ossec/etc/rules/local_rules.xml` | Raises Suricata alert level to 7 |
| `ossec_conf_suricata_snippet.xml` | Manager: `/var/ossec/etc/ossec.conf` | Active response config |

---

## Quick Setup

### Step 1 — Install Suricata on Agent

```bash
sudo add-apt-repository ppa:oisf/suricata-stable -y
sudo apt update

# If suricata-update conflict appears:
sudo apt remove suricata-update -y

sudo apt install suricata -y
sudo suricata-update
```

### Step 2 — Set Interface in suricata.yaml

```bash
sudo nano /etc/suricata/suricata.yaml
# Set: af-packet: - interface: ens33
# Set: pcap: - interface: ens33
```

### Step 3 — Fix Permissions

```bash
sudo usermod -aG suricata wazuh
sudo systemctl restart wazuh-agent
```

### Step 4 — Add eve.json to Agent ossec.conf

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

### Step 5 — Add Custom Rule on Manager

Copy the contents of `suricata_local_rules.xml` into:
```
/var/ossec/etc/rules/local_rules.xml
```

### Step 6 — Deploy Auto-Block Script on Agent

```bash
sudo cp suricata-drop.sh /var/ossec/active-response/bin/
sudo chmod 750 /var/ossec/active-response/bin/suricata-drop.sh
sudo chown root:wazuh /var/ossec/active-response/bin/suricata-drop.sh
```

### Step 7 — Add Active Response Config on Manager

Copy the contents of `ossec_conf_suricata_snippet.xml` into `/var/ossec/etc/ossec.conf` before `</ossec_config>`.

```bash
sudo systemctl restart wazuh-manager
```

---

## Test the Full Pipeline

```bash
# On the agent:
curl http://testmynids.org/uid/index.html

# Watch for auto-block:
sudo tail -f /var/ossec/logs/active-responses.log
# Expected: suricata-drop: Blocking IP 13.35.20.xx

# Verify iptables:
sudo iptables -L INPUT | grep DROP
```

---

## Key Troubleshooting

| Problem | Fix |
|---|---|
| `suricata-update` conflict during install | `sudo apt remove suricata-update -y` first |
| `Permission denied` reading eve.json | `sudo usermod -aG suricata wazuh` |
| Alert shows level 3 not 7 | Use rule ID **86701** in local_rules.xml (not 86601) |
| `Cannot read srcip from data` | Wrong script running — check `<command>suricata-drop</command>` in ossec.conf |
| 0 rules loaded in Suricata | Run `sudo suricata-update` and restart Suricata |

---

## Dashboard Verification

In Wazuh Dashboard → Security Events, search:
```
rule.groups: suricata
```

You should see alerts with:
- `rule.id: 86701`
- `rule.level: 7`
- `data.alert.signature: GPL ATTACK_RESPONSE id check returned root`

---

## Related Projects

This is part of my ongoing Wazuh SOC integration series:

- ✅ Brute Force Auto-Block (firewall-drop)
- ✅ VirusTotal + FIM + Auto-Removal
- ✅ YARA Malware Detection + Active Response
- ✅ Fail2ban Integration (custom decoders)
- ✅ SMS Alerting via RT Communications API
- ✅ **Suricata IDS + Auto-Block** ← this project

---

*Written from a real production Wazuh environment. Every command tested and confirmed working.*

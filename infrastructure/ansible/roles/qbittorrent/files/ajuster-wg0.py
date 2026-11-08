#!/usr/bin/env python3
import pathlib
import subprocess

uid = subprocess.check_output(["id", "-u", "qbittorrent"], text=True).strip()
path = pathlib.Path("/etc/wireguard/wg0.conf")
text = path.read_text().replace("\r\n", "\n").replace("\r", "\n")
if "PrivateKey =" not in text:
    raise SystemExit("PrivateKey absent")
if "0.0.0.0/0" not in text:
    raise SystemExit("AllowedIPs sans 0.0.0.0/0 — fichier inattendu")
kept = []
for line in text.splitlines():
    if line.startswith(("DNS = ", "Table = ", "FwMark = ", "PostUp = ", "PreDown = ")):
        continue
    kept.append(line)
extra = [
    "Table = 51820",
    "FwMark = 51820",
    f"PostUp = ip rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PostUp = ip rule add uidrange {uid}-{uid} lookup 51820 priority 200",
    f"PostUp = ip -6 rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PostUp = ip -6 rule add uidrange {uid}-{uid} lookup 51820 priority 200",
    "PostUp = ip rule del to <réseau-lan> lookup main priority 100 || true",
    "PostUp = ip rule add to <réseau-lan> lookup main priority 100",
    f"PreDown = ip rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PreDown = ip -6 rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    "PreDown = ip rule del to <réseau-lan> lookup main priority 100 || true",
    "PostUp = ip route replace 10.2.0.1/32 dev wg0",
    "PreDown = ip route del 10.2.0.1/32 dev wg0 || true",
]
out = []
inserted = False
for line in kept:
    out.append(line)
    if line.strip() == "[Interface]" and not inserted:
        out.extend(extra)
        inserted = True
if not inserted:
    raise SystemExit("pas de [Interface]")
path.write_text("\n".join(out) + "\n")
path.chmod(0o600)
for line in out:
    if line.startswith("PrivateKey"):
        print("PrivateKey = [présent]")
    else:
        print(line)

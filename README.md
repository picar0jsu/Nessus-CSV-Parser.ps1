# Pentest.ps1
A simple script that parses Nessus scan output into Nmap automatically.

Performs the following common checks:
- SSH Algorithms
- SSL Ciphers
- SSL Certs
- SMB Protocols
- SMB Security Mode
- RDP Encryption

# Usage
Run the script against a generated Nessus csv output:
```
.\Pentest.ps1 <Nessus Output>.csv
```

# Pentest.ps1
A simple script that parses and verifies Nessus scan output with Nmap automatically. Performs the following checks:
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

# TBC
UDP mode

# Pentest.ps1
A simple script to parse and verify Nessus scan output with Nmap automatically. Performs the following checks:
- SSH Algorithms
- SSL Ciphers
- SSL Certs
- SMB Protocols
- SMB Security Mode
- RDP Encryption

# Usage
Runs on both Windows and Kali powershell (Please SU to root and then execute). Execute the script against a generated Nessus csv output with the following:
```
.\Pentest.ps1 <Nessus Output>.csv
```

# TBC
UDP mode

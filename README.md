# Nessus-CSV-Parser.ps1
A simple cross-platform powershell script to parse and automatically verify Nessus scan output with Nmap automatically. Performs the following checks:
- SSH Algorithms
- SSL Ciphers
- SSL Certs
- SMB Protocols
- SMB Security Mode
- RDP Encryption

# Usage
Works on both Windows and Kali PWSH (Please SU to root and then execute):
```
.\run.ps1 <Nessus Output>.csv
```

# TBC
UDP mode

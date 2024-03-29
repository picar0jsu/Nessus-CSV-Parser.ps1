# v 1.0
# Author: Jonah Tan
# .\run.ps1 <Nessus Output>.csv
 
function nmapscan($hosts, $script, $dir, $protocol)
{
    ForEach($i in $hosts) 
    {
        ForEach($j in $i) 
        {
            $output = $dir + "/" + $j.Host + "_" + $j.Port + "_" + $script + ".nmap"
            $result += & nmap -Pn $protocol -p $j.Port --script $script -oN $output $j.Host
        }
    }
    #return $result
}

# CSV Extraction
Write-Host "(+) Extracting from Nessus CSV File"
$file = $args[0]
$csv = Import-Csv $file

$ssl = $csv | Where-Object { $_.Name -eq 'Service Detection' } | Where-Object { $_."Plugin Output" -Like "A web server is running on this port through *" }
$ssh = $csv | Where-Object { $_.Name -eq 'Service Detection' } | Where-Object { $_.Port -eq "22" }
$smb = $csv | Where-Object { $_.Name -eq 'Microsoft Windows SMB Service Detection' } | Where-Object { $_.Port -eq "445" }
$rdp = $csv | Where-Object { $_.Name -eq 'Windows Terminal Services Enabled' } | Where-Object { $_.Port -eq "3389" }
$ntp = $csv | Where-Object { $_.Name -eq 'Network Time Protocol (NTP) Mode 6 Scanner' }
$nfs = $csv | Where-Object { $_.Name -eq 'NFS Exported Share Information Disclosure' }
$snmp = $csv | Where-Object { $_.Name -eq 'SNMP Agent Default Community Name (public)' }

# Directories 
$sshpath = "SSH/"
$sslpath = "SSL/"
$cipherspath = $sslpath + "ciphers/"
$certspath = $sslpath + "cert/"
$smbpath = "SMB/"
$protocolpath = $smbpath + "protocols/"
$securitypath = $smbpath + "security/"
$rdppath = "RDP/"
$nfspath = "NFS/"
$ntppath = "NTP/"
$snmppath = "SNMP/"

# Mkdir
$null = New-Item -ItemType Directory -Force -Path $sshpath
$null = New-Item -ItemType Directory -Force -Path $sslpath
$null = New-Item -ItemType Directory -Force -Path $cipherspath
$null = New-Item -ItemType Directory -Force -Path $certspath
$null = New-Item -ItemType Directory -Force -Path $protocolpath
$null = New-Item -ItemType Directory -Force -Path $securitypath
$null = New-Item -ItemType Directory -Force -Path $rdppath
$null = New-Item -ItemType Directory -Force -Path $nfspath
$null = New-Item -ItemType Directory -Force -Path $ntppath
$null = New-Item -ItemType Directory -Force -Path $snmppath

# Nmap Scan (TCP)
$protocol = "-sS"

Write-Host "(+) Scanning for SSH Algorithms"
nmapscan $ssh "ssh2-enum-algos" $sshpath $protocol

Write-Host "(+) Scanning for SSL Ciphers"
nmapscan $ssl "ssl-enum-ciphers" $cipherspath $protocol

Write-Host "(+) Scanning for SSL Certs"
nmapscan $ssl "ssl-cert" $certspath $protocol

Write-Host "(+) Scanning for SMB Protocols"
nmapscan $smb "smb-protocols" $protocolpath $protocol

Write-Host "(+) Scanning for SMB Security Mode"
nmapscan $smb "smb2-security-mode" $securitypath $protocol

Write-Host "(+) Scanning for RDP Encryption"
nmapscan $rdp "rdp-enum-encryption" $rdppath $protocol

# Nmap Scan (UDP)
$protocol = "-sU"

<#

Write-Host "(+) Scanning for NFS Shares"
nmapscan $nfs "nfs-ls" $nfspath $protocol

Write-Host "(+) Scanning for NTP Mode 6"
nmapscan $ntp "nfs-ls" $ntppath $protocol

Write-Host "(+) Scanning for SNMP Public"
nmapscan $ntp "snmp-info" $snmppath $protocol

#>

# SSH Extraction
$files = Get-ChildItem -Path $sshpath -Filter *.nmap -File -Name

foreach ($file in $files)
{
    $inputfile = $sshpath + $file

    # Port Number

    if ($file -match '(?<=_)\d[^_]+(?=_)')
    {
        $port = $Matches[0]
    }
    
    # IP Address
    if ($file -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
    {
        $ip = $Matches[0]
    }
    
    # Weak KEX
    if ((Get-Content -Raw $inputfile) -match '(?<=kex_algorithms: \(.*\))([\s\S]*)(?=server_host_key_algorithms)')
    {
        
        $content = $Matches[0] | ForEach-Object {
            $_.Replace(" ","").Replace("|","").Replace("curve25519-sha256@libssh.org`r`n","").Replace("curve25519-sha256`r`n","").Replace("diffie-hellman-group-exchange-sha256`r`n","").Trim()
        }

        $content = $content -replace "(?s)`r`n\s*$"

        if ($content.Length -ne 0){
            $order = [ordered]@{'Name'='KEX';'IP'=$ip;'Port'=$port;'Content'=$content;}
            New-Object psobject -Property $order | export-csv output-ssh2-enum.csv -append -notypeinformation
        }    
    }

    # Weak HKA
    if ((Get-Content -Raw $inputfile) -match '(?<=server_host_key_algorithms: \(.*\))([\s\S]*)(?=encryption_algorithms)')
    {
        
        $content = $Matches[0] | ForEach-Object {
            $_.Replace(" ","").Replace("|","").Replace("ssh-rsa-cert-v01@openssh.com`r`n","").Replace("ssh-ed25519-cert-v01@openssh.com`r`n","").Replace("ssh-rsa-cert-v00@openssh.com`r`n","").Replace("ssh-rsa`r`n","").Replace("ssh-ed25519`r`n","").Trim()
        }

        $content = $content -replace "(?s)`r`n\s*$"

        if ($content.Length -ne 0){
            $order = [ordered]@{'Name'='HKA';'IP'=$ip;'Port'=$port;'Content'=$content;}
            New-Object psobject -Property $order | export-csv output-ssh2-enum.csv -append -notypeinformation
        }    
    }

    # Weak Ciphers
    if ((Get-Content -Raw $inputfile) -match '(?<=encryption_algorithms: \(.*\))([\s\S]*)(?=mac_algorithms)')
    {
        
        $content = $Matches[0] | ForEach-Object {
            $_.Replace(" ","").Replace("|","").Replace("chacha20-poly1305@openssh.com`r`n","").Replace("aes256-gcm@openssh.com`r`n","").Replace("aes128-gcm@openssh.com`r`n","").Replace("aes256-ctr`r`n","").Replace("aes192-ctr`r`n","").Replace("aes128-ctr`r`n","").Trim()
        }

        $content = $content -replace "(?s)`r`n\s*$"

        if ($content.Length -ne 0){
            $order = [ordered]@{'Name'='Ciphers';'IP'=$ip;'Port'=$port;'Content'=$content;}
            New-Object psobject -Property $order | export-csv output-ssh2-enum.csv -append -notypeinformation
        }    
    }

    # Weak Mac
    if ((Get-Content -Raw $inputfile) -match '(?<=mac_algorithms: \(.*\))([\s\S]*)(?=compression_algorithms)')
    {
        
        $content = $Matches[0] | ForEach-Object {
            $_.Replace(" ","").Replace("|","").Replace("hmac-sha2-512-etm@openssh.com`r`n","").Replace("hmac-sha2-256-etm@openssh.com`r`n","").Replace("umac-128`r`n","").Replace("umac-128-etm@openssh.com`r`n","").Replace("hmac-sha2-512`r`n","").Replace("hmac-sha2-256`r`n","").Replace("umac-128@openssh.com`r`n","").Trim()
        }

        $content = $content -replace "(?s)`r`n\s*$"

        if ($content.Length -ne 0){
            $order = [ordered]@{'Name'='MAC';'IP'=$ip;'Port'=$port;'Content'=$content;}
            New-Object psobject -Property $order | export-csv output-ssh2-enum.csv -append -notypeinformation
        }    
    }
}

# SSL Certs Extraction
$files = Get-ChildItem -Path $certspath -Filter *.nmap -File -Name
foreach ($file in $files)
{
    $inputfile = $certspath + $file

    # Port Number

    if ($file -match '(?<=_)\d[^_]+(?=_)')
    {
        $port = $Matches[0]
    }
    
    # IP Address
    if ($file -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
    {
        $ip = $Matches[0]
    }

    $content = Get-Content $inputfile -Raw

    if ($content -match 'sha1W\w*')
    {
		$content = $content -replace "(?s)`r`n\s*$"
        $order = [ordered]@{'Name'=$file;'IP'=$ip;'Port'=$port;'Content'=$Matches[0];}
        New-Object psobject -Property $order | export-csv output-ssl-cert.csv -append -notypeinformation
    }
}

# SSL Ciphers Extraction
$files = Get-ChildItem -Path $cipherspath -Filter *.nmap -File -Name

foreach ($file in $files)
{
    $inputfile = $cipherspath + $file
    $outfile = $outpath + $file + ".ciphers"
    $ciphers = @()

    # Port Number

    if ($file -match '(?<=_)\d[^_]+(?=_)')
    {
        $port = $Matches[0]
    }
    
    # IP Address
    if ($file -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
    {
        $ip = $Matches[0]
    }

    $content = Get-Content $inputfile -Raw

    # TLS
    if ($content -match 'TLSv1.0\w*')
    {
        $order = [ordered]@{'Name'=$file;'IP'=$ip;'Port'=$port;'Content'=$Matches[0];}
        New-Object psobject -Property $order | export-csv output-tls-1.0.csv -append -notypeinformation
    }

    if ($content -match 'TLSv1.1\w*')
    {
        $order = [ordered]@{'Name'=$file;'IP'=$ip;'Port'=$port;'Content'=$Matches[0];}
        New-Object psobject -Property $order | export-csv output-tls-1.1.csv -append -notypeinformation
    }

    # Ciphers
    foreach($line in Get-Content $inputfile){
        if ($line -match '\w*TLS_\w*')
        {
            $null = $line -match "\w*TLS_\w*"
            $ciphers += $Matches[0]
        }
    }

    $weakciphers = @('TLS_NULL_WITH_NULL_NULL','TLS_RSA_WITH_NULL_MD5','TLS_RSA_WITH_NULL_SHA','TLS_RSA_EXPORT_WITH_RC4_40_MD5','TLS_RSA_WITH_RC4_128_MD5','TLS_RSA_WITH_RC4_128_SHA','TLS_RSA_EXPORT_WITH_RC2_CBC_40_MD5','TLS_RSA_WITH_IDEA_CBC_SHA','TLS_RSA_EXPORT_WITH_DES40_CBC_SHA','TLS_RSA_WITH_DES_CBC_SHA','TLS_RSA_WITH_3DES_EDE_CBC_SHA','TLS_DH_DSS_EXPORT_WITH_DES40_CBC_SHA','TLS_DH_DSS_WITH_DES_CBC_SHA','TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA','TLS_DH_RSA_EXPORT_WITH_DES40_CBC_SHA','TLS_DH_RSA_WITH_DES_CBC_SHA','TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA','TLS_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA','TLS_DHE_DSS_WITH_DES_CBC_SHA','TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA','TLS_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA','TLS_DHE_RSA_WITH_DES_CBC_SHA','TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA','TLS_DH_anon_EXPORT_WITH_RC4_40_MD5','TLS_DH_anon_WITH_RC4_128_MD5','TLS_DH_anon_EXPORT_WITH_DES40_CBC_SHA','TLS_DH_anon_WITH_DES_CBC_SHA','TLS_DH_anon_WITH_3DES_EDE_CBC_SHA','TLS_KRB5_WITH_DES_CBC_SHA','TLS_KRB5_WITH_3DES_EDE_CBC_SHA','TLS_KRB5_WITH_RC4_128_SHA','TLS_KRB5_WITH_IDEA_CBC_SHA','TLS_KRB5_WITH_DES_CBC_MD5','TLS_KRB5_WITH_3DES_EDE_CBC_MD5','TLS_KRB5_WITH_RC4_128_MD5','TLS_KRB5_WITH_IDEA_CBC_MD5','TLS_KRB5_EXPORT_WITH_DES_CBC_40_SHA','TLS_KRB5_EXPORT_WITH_RC2_CBC_40_SHA','TLS_KRB5_EXPORT_WITH_RC4_40_SHA','TLS_KRB5_EXPORT_WITH_DES_CBC_40_MD5','TLS_KRB5_EXPORT_WITH_RC2_CBC_40_MD5','TLS_KRB5_EXPORT_WITH_RC4_40_MD5','TLS_PSK_WITH_NULL_SHA','TLS_DHE_PSK_WITH_NULL_SHA','TLS_RSA_PSK_WITH_NULL_SHA','TLS_RSA_WITH_AES_128_CBC_SHA','TLS_DH_DSS_WITH_AES_128_CBC_SHA','TLS_DH_RSA_WITH_AES_128_CBC_SHA','TLS_DHE_DSS_WITH_AES_128_CBC_SHA','TLS_DHE_RSA_WITH_AES_128_CBC_SHA','TLS_DH_anon_WITH_AES_128_CBC_SHA','TLS_RSA_WITH_AES_256_CBC_SHA','TLS_DH_DSS_WITH_AES_256_CBC_SHA','TLS_DH_RSA_WITH_AES_256_CBC_SHA','TLS_DHE_DSS_WITH_AES_256_CBC_SHA','TLS_DHE_RSA_WITH_AES_256_CBC_SHA','TLS_DH_anon_WITH_AES_256_CBC_SHA','TLS_RSA_WITH_NULL_SHA256','TLS_RSA_WITH_AES_128_CBC_SHA256','TLS_RSA_WITH_AES_256_CBC_SHA256','TLS_DH_DSS_WITH_AES_128_CBC_SHA256','TLS_DH_RSA_WITH_AES_128_CBC_SHA256','TLS_DHE_DSS_WITH_AES_128_CBC_SHA256','TLS_RSA_WITH_CAMELLIA_128_CBC_SHA','TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA','TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA','TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA','TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA','TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA','TLS_DHE_RSA_WITH_AES_128_CBC_SHA256','TLS_DH_DSS_WITH_AES_256_CBC_SHA256','TLS_DH_RSA_WITH_AES_256_CBC_SHA256','TLS_DHE_DSS_WITH_AES_256_CBC_SHA256','TLS_DHE_RSA_WITH_AES_256_CBC_SHA256','TLS_DH_anon_WITH_AES_128_CBC_SHA256','TLS_DH_anon_WITH_AES_256_CBC_SHA256','TLS_RSA_WITH_CAMELLIA_256_CBC_SHA','TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA','TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA','TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA','TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA','TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA','TLS_PSK_WITH_RC4_128_SHA','TLS_PSK_WITH_3DES_EDE_CBC_SHA','TLS_PSK_WITH_AES_128_CBC_SHA','TLS_PSK_WITH_AES_256_CBC_SHA','TLS_DHE_PSK_WITH_RC4_128_SHA','TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA','TLS_DHE_PSK_WITH_AES_128_CBC_SHA','TLS_DHE_PSK_WITH_AES_256_CBC_SHA','TLS_RSA_PSK_WITH_RC4_128_SHA','TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA','TLS_RSA_PSK_WITH_AES_128_CBC_SHA','TLS_RSA_PSK_WITH_AES_256_CBC_SHA','TLS_RSA_WITH_SEED_CBC_SHA','TLS_DH_DSS_WITH_SEED_CBC_SHA','TLS_DH_RSA_WITH_SEED_CBC_SHA','TLS_DHE_DSS_WITH_SEED_CBC_SHA','TLS_DHE_RSA_WITH_SEED_CBC_SHA','TLS_DH_anon_WITH_SEED_CBC_SHA','TLS_RSA_WITH_AES_128_GCM_SHA256','TLS_RSA_WITH_AES_256_GCM_SHA384','TLS_DH_RSA_WITH_AES_128_GCM_SHA256','TLS_DH_RSA_WITH_AES_256_GCM_SHA384','TLS_DHE_DSS_WITH_AES_128_GCM_SHA256','TLS_DHE_DSS_WITH_AES_256_GCM_SHA384','TLS_DH_DSS_WITH_AES_128_GCM_SHA256','TLS_DH_DSS_WITH_AES_256_GCM_SHA384','TLS_DH_anon_WITH_AES_128_GCM_SHA256','TLS_DH_anon_WITH_AES_256_GCM_SHA384','TLS_PSK_WITH_AES_128_GCM_SHA256','TLS_PSK_WITH_AES_256_GCM_SHA384','TLS_RSA_PSK_WITH_AES_128_GCM_SHA256','TLS_RSA_PSK_WITH_AES_256_GCM_SHA384','TLS_PSK_WITH_AES_128_CBC_SHA256','TLS_PSK_WITH_AES_256_CBC_SHA384','TLS_PSK_WITH_NULL_SHA256','TLS_PSK_WITH_NULL_SHA384','TLS_DHE_PSK_WITH_AES_128_CBC_SHA256','TLS_DHE_PSK_WITH_AES_256_CBC_SHA384','TLS_DHE_PSK_WITH_NULL_SHA256','TLS_DHE_PSK_WITH_NULL_SHA384','TLS_RSA_PSK_WITH_AES_128_CBC_SHA256','TLS_RSA_PSK_WITH_AES_256_CBC_SHA384','TLS_RSA_PSK_WITH_NULL_SHA256','TLS_RSA_PSK_WITH_NULL_SHA384','TLS_RSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA256','TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA256','TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA256','TLS_RSA_WITH_CAMELLIA_256_CBC_SHA256','TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA256','TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA256','TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA256','TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA256','TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA256','TLS_SM4_GCM_SM3','TLS_SM4_CCM_SM3','TLS_EMPTY_RENEGOTIATION_INFO_SCSV','TLS_AES_128_CCM_8_SHA256','TLS_FALLBACK_SCSV','TLS_ECDH_ECDSA_WITH_NULL_SHA','TLS_ECDH_ECDSA_WITH_RC4_128_SHA','TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA','TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA','TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA','TLS_ECDHE_ECDSA_WITH_NULL_SHA','TLS_ECDHE_ECDSA_WITH_RC4_128_SHA','TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA','TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA','TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA','TLS_ECDH_RSA_WITH_NULL_SHA','TLS_ECDH_RSA_WITH_RC4_128_SHA','TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA','TLS_ECDH_RSA_WITH_AES_128_CBC_SHA','TLS_ECDH_RSA_WITH_AES_256_CBC_SHA','TLS_ECDHE_RSA_WITH_NULL_SHA','TLS_ECDHE_RSA_WITH_RC4_128_SHA','TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA','TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA','TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA','TLS_ECDH_anon_WITH_NULL_SHA','TLS_ECDH_anon_WITH_RC4_128_SHA','TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA','TLS_ECDH_anon_WITH_AES_128_CBC_SHA','TLS_ECDH_anon_WITH_AES_256_CBC_SHA','TLS_SRP_SHA_WITH_3DES_EDE_CBC_SHA','TLS_SRP_SHA_RSA_WITH_3DES_EDE_CBC_SHA','TLS_SRP_SHA_DSS_WITH_3DES_EDE_CBC_SHA','TLS_SRP_SHA_WITH_AES_128_CBC_SHA','TLS_SRP_SHA_RSA_WITH_AES_128_CBC_SHA','TLS_SRP_SHA_DSS_WITH_AES_128_CBC_SHA','TLS_SRP_SHA_WITH_AES_256_CBC_SHA','TLS_SRP_SHA_RSA_WITH_AES_256_CBC_SHA','TLS_SRP_SHA_DSS_WITH_AES_256_CBC_SHA','TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256','TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384','TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256','TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384','TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256','TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384','TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256','TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384','TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256','TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384','TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256','TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384','TLS_ECDHE_PSK_WITH_RC4_128_SHA','TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA','TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA','TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA','TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256','TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384','TLS_ECDHE_PSK_WITH_NULL_SHA','TLS_ECDHE_PSK_WITH_NULL_SHA256','TLS_ECDHE_PSK_WITH_NULL_SHA384','TLS_RSA_WITH_ARIA_128_CBC_SHA256','TLS_RSA_WITH_ARIA_256_CBC_SHA384','TLS_DH_DSS_WITH_ARIA_128_CBC_SHA256','TLS_DH_DSS_WITH_ARIA_256_CBC_SHA384','TLS_DH_RSA_WITH_ARIA_128_CBC_SHA256','TLS_DH_RSA_WITH_ARIA_256_CBC_SHA384','TLS_DHE_DSS_WITH_ARIA_128_CBC_SHA256','TLS_DHE_DSS_WITH_ARIA_256_CBC_SHA384','TLS_DHE_RSA_WITH_ARIA_128_CBC_SHA256','TLS_DHE_RSA_WITH_ARIA_256_CBC_SHA384','TLS_DH_anon_WITH_ARIA_128_CBC_SHA256','TLS_DH_anon_WITH_ARIA_256_CBC_SHA384','TLS_ECDHE_ECDSA_WITH_ARIA_128_CBC_SHA256','TLS_ECDHE_ECDSA_WITH_ARIA_256_CBC_SHA384','TLS_ECDH_ECDSA_WITH_ARIA_128_CBC_SHA256','TLS_ECDH_ECDSA_WITH_ARIA_256_CBC_SHA384','TLS_ECDHE_RSA_WITH_ARIA_128_CBC_SHA256','TLS_ECDHE_RSA_WITH_ARIA_256_CBC_SHA384','TLS_ECDH_RSA_WITH_ARIA_128_CBC_SHA256','TLS_ECDH_RSA_WITH_ARIA_256_CBC_SHA384','TLS_RSA_WITH_ARIA_128_GCM_SHA256','TLS_RSA_WITH_ARIA_256_GCM_SHA384','TLS_DHE_RSA_WITH_ARIA_128_GCM_SHA256','TLS_DHE_RSA_WITH_ARIA_256_GCM_SHA384','TLS_DH_RSA_WITH_ARIA_128_GCM_SHA256','TLS_DH_RSA_WITH_ARIA_256_GCM_SHA384','TLS_DHE_DSS_WITH_ARIA_128_GCM_SHA256','TLS_DHE_DSS_WITH_ARIA_256_GCM_SHA384','TLS_DH_DSS_WITH_ARIA_128_GCM_SHA256','TLS_DH_DSS_WITH_ARIA_256_GCM_SHA384','TLS_DH_anon_WITH_ARIA_128_GCM_SHA256','TLS_DH_anon_WITH_ARIA_256_GCM_SHA384','TLS_ECDHE_ECDSA_WITH_ARIA_128_GCM_SHA256','TLS_ECDHE_ECDSA_WITH_ARIA_256_GCM_SHA384','TLS_ECDH_ECDSA_WITH_ARIA_128_GCM_SHA256','TLS_ECDH_ECDSA_WITH_ARIA_256_GCM_SHA384','TLS_ECDHE_RSA_WITH_ARIA_128_GCM_SHA256','TLS_ECDHE_RSA_WITH_ARIA_256_GCM_SHA384','TLS_ECDH_RSA_WITH_ARIA_128_GCM_SHA256','TLS_ECDH_RSA_WITH_ARIA_256_GCM_SHA384','TLS_PSK_WITH_ARIA_128_CBC_SHA256','TLS_PSK_WITH_ARIA_256_CBC_SHA384','TLS_DHE_PSK_WITH_ARIA_128_CBC_SHA256','TLS_DHE_PSK_WITH_ARIA_256_CBC_SHA384','TLS_RSA_PSK_WITH_ARIA_128_CBC_SHA256','TLS_RSA_PSK_WITH_ARIA_256_CBC_SHA384','TLS_PSK_WITH_ARIA_128_GCM_SHA256','TLS_PSK_WITH_ARIA_256_GCM_SHA384','TLS_DHE_PSK_WITH_ARIA_128_GCM_SHA256','TLS_DHE_PSK_WITH_ARIA_256_GCM_SHA384','TLS_RSA_PSK_WITH_ARIA_128_GCM_SHA256','TLS_RSA_PSK_WITH_ARIA_256_GCM_SHA384','TLS_ECDHE_PSK_WITH_ARIA_128_CBC_SHA256','TLS_ECDHE_PSK_WITH_ARIA_256_CBC_SHA384','TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_CBC_SHA384','TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384','TLS_ECDHE_RSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_ECDHE_RSA_WITH_CAMELLIA_256_CBC_SHA384','TLS_ECDH_RSA_WITH_CAMELLIA_128_CBC_SHA256','TLS_ECDH_RSA_WITH_CAMELLIA_256_CBC_SHA384','TLS_RSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_RSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_DHE_RSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_DHE_RSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_DH_RSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_DH_RSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_DHE_DSS_WITH_CAMELLIA_128_GCM_SHA256','TLS_DHE_DSS_WITH_CAMELLIA_256_GCM_SHA384','TLS_DH_DSS_WITH_CAMELLIA_128_GCM_SHA256','TLS_DH_DSS_WITH_CAMELLIA_256_GCM_SHA384','TLS_DH_anon_WITH_CAMELLIA_128_GCM_SHA256','TLS_DH_anon_WITH_CAMELLIA_256_GCM_SHA384','TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_ECDH_ECDSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_ECDH_ECDSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_ECDHE_RSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_ECDHE_RSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_ECDH_RSA_WITH_CAMELLIA_128_GCM_SHA256','TLS_ECDH_RSA_WITH_CAMELLIA_256_GCM_SHA384','TLS_PSK_WITH_CAMELLIA_128_GCM_SHA256','TLS_PSK_WITH_CAMELLIA_256_GCM_SHA384','TLS_DHE_PSK_WITH_CAMELLIA_128_GCM_SHA256','TLS_DHE_PSK_WITH_CAMELLIA_256_GCM_SHA384','TLS_RSA_PSK_WITH_CAMELLIA_128_GCM_SHA256','TLS_RSA_PSK_WITH_CAMELLIA_256_GCM_SHA384','TLS_PSK_WITH_CAMELLIA_128_CBC_SHA256','TLS_PSK_WITH_CAMELLIA_256_CBC_SHA384','TLS_DHE_PSK_WITH_CAMELLIA_128_CBC_SHA256','TLS_DHE_PSK_WITH_CAMELLIA_256_CBC_SHA384','TLS_RSA_PSK_WITH_CAMELLIA_128_CBC_SHA256','TLS_RSA_PSK_WITH_CAMELLIA_256_CBC_SHA384','TLS_ECDHE_PSK_WITH_CAMELLIA_128_CBC_SHA256','TLS_ECDHE_PSK_WITH_CAMELLIA_256_CBC_SHA384','TLS_RSA_WITH_AES_128_CCM','TLS_RSA_WITH_AES_256_CCM','TLS_RSA_WITH_AES_128_CCM_8','TLS_RSA_WITH_AES_256_CCM_8','TLS_DHE_RSA_WITH_AES_128_CCM_8','TLS_DHE_RSA_WITH_AES_256_CCM_8','TLS_PSK_WITH_AES_128_CCM','TLS_PSK_WITH_AES_256_CCM','TLS_PSK_WITH_AES_128_CCM_8','TLS_PSK_WITH_AES_256_CCM_8','TLS_PSK_DHE_WITH_AES_128_CCM_8','TLS_PSK_DHE_WITH_AES_256_CCM_8','TLS_ECDHE_ECDSA_WITH_AES_128_CCM','TLS_ECDHE_ECDSA_WITH_AES_256_CCM','TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8','TLS_ECDHE_ECDSA_WITH_AES_256_CCM_8','TLS_ECCPWD_WITH_AES_128_GCM_SHA256','TLS_ECCPWD_WITH_AES_256_GCM_SHA384','TLS_ECCPWD_WITH_AES_128_CCM_SHA256','TLS_ECCPWD_WITH_AES_256_CCM_SHA384','TLS_SHA256_SHA256','TLS_SHA384_SHA384','TLS_GOSTR341112_256_WITH_KUZNYECHIK_CTR_OMAC','TLS_GOSTR341112_256_WITH_MAGMA_CTR_OMAC','TLS_GOSTR341112_256_WITH_28147_CNT_IMIT','TLS_GOSTR341112_256_WITH_KUZNYECHIK_MGM_L','TLS_GOSTR341112_256_WITH_MAGMA_MGM_L','TLS_GOSTR341112_256_WITH_KUZNYECHIK_MGM_S','TLS_GOSTR341112_256_WITH_MAGMA_MGM_S','TLS_PSK_WITH_CHACHA20_POLY1305_SHA256','TLS_RSA_PSK_WITH_CHACHA20_POLY1305_SHA256','TLS_ECDHE_PSK_WITH_AES_128_CCM_8_SHA256')
    
    $content = Compare-Object $ciphers $weakciphers -PassThru -IncludeEqual -ExcludeDifferent | Out-String
    $content = $content -replace "(?s)`r`n\s*$"

    if ($content.Length -ne 0){
        $order = [ordered]@{'Name'=$file;'IP'=$ip;'Port'=$port;'Content'=$content;}
        New-Object psobject -Property $order | export-csv output-ssl-enum-ciphers.csv -append -notypeinformation
    }  
}

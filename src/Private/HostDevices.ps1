# ---------------------------------------------------------------------------
# Host cihazlari: koprulenebilir ag adaptorleri ve USB cihazlari.
# ---------------------------------------------------------------------------

function ConvertFrom-VBoxBlocks {
    <#
    .SYNOPSIS
        VBoxManage'in "Anahtar: deger" bicimli, bos satirla ayrilmis blok ciktisini
        hashtable listesine cevirir ("list bridgedifs", "list usbhost").
    #>
    param([string[]]$Lines)

    $blocks  = New-Object System.Collections.Generic.List[hashtable]
    $current = @{}

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($current.Count -gt 0) { $blocks.Add($current); $current = @{} }
            continue
        }

        $idx = $line.IndexOf(':')
        if ($idx -lt 1) { continue }

        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()

        # Ilk gorulen kazanir; bloklar tekrar eden alan adlari icerebiliyor
        if (-not $current.ContainsKey($key)) { $current[$key] = $val }
    }
    if ($current.Count -gt 0) { $blocks.Add($current) }

    return $blocks
}

function Get-BridgedInterfaces {
    <#
    .SYNOPSIS
        Koprulenebilir host ag adaptorlerini dondurur (kablosuz olanlar isaretli).
    #>
    $r = Invoke-VBoxRead -Arguments @('list', 'bridgedifs')
    $out = New-Object System.Collections.Generic.List[object]

    foreach ($b in (ConvertFrom-VBoxBlocks -Lines $r.Lines)) {
        if (-not $b['Name']) { continue }
        $out.Add([pscustomobject]@{
            Name      = $b['Name']
            Wireless  = ($b['Wireless'] -eq 'Yes')
            Status    = $b['Status']
            IPAddress = $b['IPAddress']
            NetMask   = $b['NetworkMask']
            Mac       = $b['HardwareAddress']
        })
    }
    return $out
}

function Get-HostUsbDevices {
    <#
    .SYNOPSIS
        Host'a takili USB cihazlarini VID/PID ve okunabilir etiketle dondurur.
    .NOTES
        Degisken adi olarak $pid KULLANILAMAZ - PowerShell'de salt okunur
        otomatik degiskendir (process ID) ve atama calisma zamaninda patlar.
    #>
    $r = Invoke-VBoxRead -Arguments @('list', 'usbhost')
    $out = New-Object System.Collections.Generic.List[object]

    foreach ($b in (ConvertFrom-VBoxBlocks -Lines $r.Lines)) {
        if (-not $b['UUID']) { continue }

        $vendId = ''; $prodId = ''
        if ($b['VendorId']  -match '0x([0-9a-fA-F]{4})') { $vendId = $Matches[1].ToUpper() }
        if ($b['ProductId'] -match '0x([0-9a-fA-F]{4})') { $prodId = $Matches[1].ToUpper() }

        $parts = @(@($b['Manufacturer'], $b['Product']) | Where-Object { $_ })
        $label = '(isimsiz cihaz)'
        if ($parts.Count -gt 0) { $label = ($parts -join ' ') }

        $out.Add([pscustomobject]@{
            Uuid      = $b['UUID']
            VendorId  = $vendId
            ProductId = $prodId
            Serial    = $b['SerialNumber']
            Label     = $label
            State     = $b['Current State']
        })
    }
    return $out
}

function Get-Subnet {
    <#
    .SYNOPSIS
        IP + maskeden ag adresi uretir. Bridged modda host ile ayni L2 segmentine
        dusuldugunu tespit etmek icin kullanilir.
    .OUTPUTS
        "172.16.111.0/255.255.255.0" bicimi, ya da cozulemezse $null.
    #>
    param([string]$Ip, [string]$Mask)

    if (-not $Ip -or -not $Mask) { return $null }
    try {
        $a = ([ipaddress]$Ip).GetAddressBytes()
        $m = ([ipaddress]$Mask).GetAddressBytes()
        if ($a.Length -ne 4 -or $m.Length -ne 4) { return $null }

        $n = New-Object byte[] 4
        for ($i = 0; $i -lt 4; $i++) { $n[$i] = $a[$i] -band $m[$i] }
        return (([ipaddress]$n).IPAddressToString + '/' + $Mask)
    } catch {
        return $null
    }
}

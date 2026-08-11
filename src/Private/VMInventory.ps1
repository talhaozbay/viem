# ---------------------------------------------------------------------------
# VM envanteri: VirtualBox'tan makine listesi ve makine ayarlarini okur.
# ---------------------------------------------------------------------------

function Get-VMInfo {
    <#
    .SYNOPSIS
        "showvminfo --machinereadable" ciktisini anahtar/deger hashtable'ina cevirir.
    .OUTPUTS
        Hashtable. VM bulunamazsa bos hashtable.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $r = Invoke-VBoxRead -Arguments @('showvminfo', $Name, '--machinereadable')
    $map = @{}
    if (-not $r.Ok) { return $map }

    foreach ($line in $r.Lines) {
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { continue }

        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()

        # Degerler cogunlukla tirnak icinde gelir: key="value"
        if ($val.Length -ge 2 -and $val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        $map[$key] = $val
    }
    return $map
}

function Get-VMList {
    <#
    .SYNOPSIS
        Kayitli tum VM'leri calisma durumlariyla birlikte dondurur.
    .OUTPUTS
        Name / Uuid / Running alanlarina sahip nesneler.
    #>
    $r = Invoke-VBoxRead -Arguments @('list', 'vms')
    if (-not $r.Ok) { throw "VM listesi alinamadi: $($r.Output)" }

    $running = @{}
    $rr = Invoke-VBoxRead -Arguments @('list', 'runningvms')
    foreach ($line in $rr.Lines) {
        if ($line -match '^\s*"(?<n>.*)"\s+\{(?<u>[0-9a-fA-F-]+)\}\s*$') { $running[$Matches['n']] = $true }
    }

    $result = New-Object System.Collections.Generic.List[object]
    foreach ($line in $r.Lines) {
        if ($line -match '^\s*"(?<n>.*)"\s+\{(?<u>[0-9a-fA-F-]+)\}\s*$') {
            $result.Add([pscustomobject]@{
                Name    = $Matches['n']
                Uuid    = $Matches['u']
                Running = [bool]$running[$Matches['n']]
            })
        }
    }
    return $result
}

function Get-VMNetworkSummary {
    <#
    .SYNOPSIS
        VM listesinde gostermek icin aktif NIC'lerin kisa ozetini uretir.
    .EXAMPLE
        "nic1:bridged(Intel Wi-Fi 6 AX203)"
    #>
    param([Parameter(Mandatory)][hashtable]$Info)

    $nets = @()
    for ($n = 1; $n -le 8; $n++) {
        $mode = $Info["nic$n"]
        if (-not $mode -or $mode -eq 'none') { continue }

        $detail = switch ($mode) {
            'bridged'  { $Info["bridgeadapter$n"] }
            'intnet'   { $Info["intnet$n"] }
            'hostonly' { $Info["hostonlyadapter$n"] }
            default    { '' }
        }
        if ($detail) { $nets += "nic${n}:$mode($detail)" } else { $nets += "nic${n}:$mode" }
    }

    if ($nets.Count -eq 0) { return 'ag yok' }
    return ($nets -join ', ')
}

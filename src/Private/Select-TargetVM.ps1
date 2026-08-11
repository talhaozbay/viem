# ---------------------------------------------------------------------------
# ADIM 1 - Izole edilecek VM'in secilmesi.
# ---------------------------------------------------------------------------

function Select-TargetVM {
    <#
    .SYNOPSIS
        VM'leri listeler ve kullanicidan secim alir. -VMName verilmisse menuyu atlar.
    .OUTPUTS
        Secilen VM adi (string), ya da iptal/bulunamama durumunda $null.
    #>
    param([string]$VMName)

    $vms = @(Get-VMList)
    if ($vms.Count -eq 0) {
        Write-Fail 'Hic VirtualBox VM bulunamadi.'
        return $null
    }

    # Etkilesimsiz yol: ad parametreden geldi
    if ($VMName) {
        $match = @($vms | Where-Object { $_.Name -eq $VMName })
        if ($match.Count -eq 0) {
            $names = ($vms | ForEach-Object { $_.Name }) -join ', '
            Write-Fail "'$VMName' adinda bir VM yok. Mevcut olanlar: $names"
            return $null
        }
        Write-Ok "Secilen VM (parametreden): $($match[0].Name)"
        return $match[0].Name
    }

    # Etkilesimli yol: numarali menu
    Write-Host ''
    $i = 0
    foreach ($vm in $vms) {
        $i++
        $info = Get-VMInfo -Name $vm.Name

        $state      = $info['VMState']
        $stateColor = 'DarkGray'
        if ($vm.Running) { $state = 'CALISIYOR'; $stateColor = 'Yellow' }

        Write-Host ("  [{0}] " -f $i) -ForegroundColor White -NoNewline
        Write-Host $vm.Name -ForegroundColor Cyan -NoNewline
        Write-Host ("  - {0}" -f $state) -ForegroundColor $stateColor
        Write-Host ("        OS: {0}" -f $info['ostype']) -ForegroundColor DarkGray
        Write-Host ("        Ag: {0}" -f (Get-VMNetworkSummary -Info $info)) -ForegroundColor DarkGray
    }

    $sel = Read-Selection -Prompt 'Izole edilecek VM numarasi' -Max $vms.Count -AllowQuit
    if ($sel -lt 0) {
        Write-Info 'Iptal edildi.'
        return $null
    }

    Write-Ok "Secilen VM: $($vms[$sel - 1].Name)"
    return $vms[$sel - 1].Name
}

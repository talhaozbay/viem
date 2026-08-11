# ---------------------------------------------------------------------------
# ADIM 2 - Guc durumu.
#
# "modifyvm" yalnizca kapali VM'de calisir. 'saved' durumdaki VM'de de calismaz;
# once kaydedilmis durumun silinmesi gerekir.
# ---------------------------------------------------------------------------

function Confirm-PowerState {
    <#
    .SYNOPSIS
        Hedef VM'i ayar degisikligine hazir hale getirir (gerekirse kapatir).
    .OUTPUTS
        Ayarlar uygulanabilir durumdaysa $true, iptal/basarisizlikta $false.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )

    $info  = Get-VMInfo -Name $Name
    $state = $info['VMState']

    # --- Kaydedilmis durum ---
    if ($state -eq 'saved') {
        Write-Warn 'VM kaydedilmis durumda (saved). Ayar degistirmek icin bu durum silinmelidir.'

        $doDiscard = [bool]$Force
        if (-not $doDiscard) {
            $doDiscard = Read-YesNo -Prompt 'Kaydedilmis durum silinsin mi? (VM kapali duruma doner)' -DefaultYes $false
        }
        if (-not $doDiscard) { Write-Info 'Iptal edildi.'; return $false }

        $r = Invoke-VBoxWrite -Arguments @('discardstate', $Name)
        if ($r.Ok) {
            Write-Ok 'Kaydedilmis durum silindi.'
        } elseif (-not $script:DryRunMode) {
            Write-Fail "Kaydedilmis durum silinemedi: $($r.Output)"
            return $false
        }

        $state = (Get-VMInfo -Name $Name)['VMState']
    }

    # --- Zaten kapali ---
    if ($state -eq 'poweroff' -or $state -eq 'aborted') {
        Write-Ok 'VM kapali - ayarlar uygulanabilir.'
        return $true
    }

    # --- Calisiyor ---
    Write-Warn "VM su anda '$state' durumunda. Ayarlar sadece kapali VM'e uygulanabilir."

    if ($script:DryRunMode) {
        Write-Info 'DRY-RUN: VM kapatilmayacak, akisin geri kalani simule ediliyor.'
        return $true
    }

    $choice = 1
    if ($Force) {
        Write-Info '-Force verildi: ACPI ile kapatiliyor.'
    } else {
        Write-Host ''
        Write-Host '  [1] ACPI kapatma sinyali gonder ve bekle (guest icinde duzgun kapanir)' -ForegroundColor White
        Write-Host '  [2] Zorla kapat (poweroff - guest icinde veri kaybi olabilir)' -ForegroundColor White
        Write-Host '  [3] Iptal et' -ForegroundColor White

        $choice = Read-Selection -Prompt 'Seciminiz' -Max 3
        if ($choice -eq 3) { Write-Info 'Iptal edildi.'; return $false }
    }

    if ($choice -eq 1) {
        $null = Invoke-VBoxWrite -Arguments @('controlvm', $Name, 'acpipowerbutton')
        Write-Info 'ACPI kapatma sinyali gonderildi, 60 saniyeye kadar bekleniyor...'

        $waited = 0
        while ($waited -lt 60) {
            Start-Sleep -Seconds 3
            $waited += 3
            if ((Get-VMInfo -Name $Name)['VMState'] -eq 'poweroff') { break }
        }
    }

    # ACPI ise yaramadiysa ya da kullanici zorla kapatmayi sectiyse
    if ((Get-VMInfo -Name $Name)['VMState'] -ne 'poweroff') {
        Write-Warn 'VM hala kapanmadi, zorla kapatiliyor...'
        $null = Invoke-VBoxWrite -Arguments @('controlvm', $Name, 'poweroff')
        Start-Sleep -Seconds 3
    }

    $state = (Get-VMInfo -Name $Name)['VMState']
    if ($state -ne 'poweroff' -and $state -ne 'aborted') {
        Write-Fail "VM kapatilamadi (durum: $state). Islem durduruldu."
        return $false
    }

    Write-Ok 'VM kapatildi - ayarlar uygulanabilir.'
    return $true
}

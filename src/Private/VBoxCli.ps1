# ---------------------------------------------------------------------------
# VBoxManage cagri katmani.
#
#   Invoke-VBoxRead  : salt okunur; DryRun modunda da HER ZAMAN calisir
#   Invoke-VBoxWrite : degisiklik yazar; DryRun modunda sadece komutu gosterir
#   Set-Control      : tek bir modifyvm ayarini uygular ve sonucu kaydeder
#
# Modul kapsamli durum ($script:) Invoke-VMIsolation icinde ilklendirilir.
# ---------------------------------------------------------------------------

function Resolve-VBoxManage {
    <#
    .SYNOPSIS
        VBoxManage.exe yolunu bulur: acik parametre -> PATH -> registry -> bilinen konumlar.
    #>
    param([string]$Explicit)

    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit) { return (Resolve-Path -LiteralPath $Explicit).Path }
        throw "Belirtilen VBoxManage yolu bulunamadi: $Explicit"
    }

    $cmd = Get-Command 'VBoxManage.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    foreach ($key in 'HKLM:\SOFTWARE\Oracle\VirtualBox', 'HKLM:\SOFTWARE\WOW6432Node\Oracle\VirtualBox') {
        try {
            $reg = Get-ItemProperty -Path $key -ErrorAction Stop
            if ($reg.InstallDir) {
                $candidate = Join-Path $reg.InstallDir 'VBoxManage.exe'
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
        } catch { }
    }

    foreach ($p in @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe"
    )) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }

    throw 'VBoxManage.exe bulunamadi. -VBoxManagePath ile tam yolu belirtin.'
}

function Invoke-VBoxRead {
    <#
    .SYNOPSIS
        VBoxManage'i calistirir ve ciktisini dondurur. Salt okunur cagrilar icin.
    .NOTES
        PowerShell 5.1'de native exe stderr'ini 2>&1 ile yakalamak ErrorRecord
        uretir ve $? degerini bozar; bu yuzden basari tespiti $LASTEXITCODE ile
        yapilir ve ErrorRecord'lar metne cevrilir.
    #>
    param([Parameter(Mandatory)][string[]]$Arguments)

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = & $script:VBoxManage @Arguments 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev

    $lines = @($raw | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ }
    })

    return [pscustomobject]@{
        Ok     = ($code -eq 0)
        Code   = $code
        Lines  = $lines
        Output = ($lines -join "`n").Trim()
    }
}

function Invoke-VBoxWrite {
    <#
    .SYNOPSIS
        Degisiklik yapan VBoxManage cagrisi. DryRun modunda yalnizca komutu yazdirir.
    #>
    param([Parameter(Mandatory)][string[]]$Arguments)

    if ($script:DryRunMode) {
        $shown = @($Arguments | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        })
        Write-Host "       [DRY] VBoxManage $($shown -join ' ')" -ForegroundColor DarkGray
        return [pscustomobject]@{ Ok = $true; Code = 0; Lines = @(); Output = '' }
    }

    return Invoke-VBoxRead -Arguments $Arguments
}

function Set-Control {
    <#
    .SYNOPSIS
        Hedef VM uzerinde tek bir modifyvm ayarini uygular ve sonucu ozet listelerine yazar.
    .PARAMETER Tolerate
        Basarisizlik kritik degilse; hata yerine uyari uretir ve ozete "basarisiz" olarak girmez.
    #>
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$ModifyArgs,
        [switch]$Tolerate
    )

    $r = Invoke-VBoxWrite -Arguments (@('modifyvm', $script:TargetVM) + $ModifyArgs)

    if ($r.Ok) {
        Write-Ok $Label
        $null = $script:Applied.Add($Label)
    } elseif ($Tolerate) {
        Write-Warn "$Label -> atlandi ($($r.Output))"
    } else {
        Write-Fail "$Label -> HATA: $($r.Output)"
        $null = $script:Failed.Add($Label)
    }
}

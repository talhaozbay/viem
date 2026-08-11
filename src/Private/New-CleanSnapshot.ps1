# ---------------------------------------------------------------------------
# ADIM 6 - Temiz durum snapshot'i.
#
# Zararli calistirmadan ONCE alinan snapshot, her analiz sonrasi makineyi
# saniyeler icinde temiz duruma dondurmeyi saglar.
# ---------------------------------------------------------------------------

function New-CleanSnapshot {
    <#
    .SYNOPSIS
        Izolasyon uygulandiktan sonra "clean" snapshot alir.
    .PARAMETER NoSnapshot
        Verilirse soru sorulmaz ve snapshot atlanir.
    #>
    param([switch]$NoSnapshot)

    Write-Info 'Zararli yazilim calistirmadan ONCE bir snapshot almak, her analizden sonra'
    Write-Info 'makineyi saniyeler icinde temiz duruma dondurmenizi saglar.'

    if ($NoSnapshot) {
        Write-Info '-NoSnapshot verildi, snapshot atlandi.'
        return
    }

    if (-not (Read-YesNo -Prompt 'Simdi bir "clean" snapshot alinsin mi?' -DefaultYes $true)) {
        Write-Info 'Snapshot atlandi.'
        return
    }

    $snapName = "clean-isolated-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    $r = Invoke-VBoxWrite -Arguments @(
        'snapshot', $script:TargetVM, 'take', $snapName,
        '--description', 'VMIsolator ile izole edilmis temiz durum'
    )

    if ($r.Ok) {
        Write-Ok "Snapshot alindi: $snapName"
        $null = $script:Notes.Add("Analiz sonrasi geri donmek icin: VBoxManage snapshot `"$($script:TargetVM)`" restore `"$snapName`"")
    } else {
        Write-Fail "Snapshot alinamadi: $($r.Output)"
    }
}

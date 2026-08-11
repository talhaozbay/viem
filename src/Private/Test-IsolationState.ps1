# ---------------------------------------------------------------------------
# ADIM 5 - Dogrulama.
#
# Uygulanan her ayar VM konfigurasyonundan GERI OKUNUR. "Komut hata vermedi"
# ile "ayar gercekten yazildi" ayni sey degildir; bu adim ikincisini kanitlar.
# ---------------------------------------------------------------------------

function Test-IsolationState {
    <#
    .SYNOPSIS
        Hedef VM'in izolasyon ayarlarini dogrular ve her birini raporlar.
    #>
    param(
        [Parameter(Mandatory)][object]$Plan,
        [switch]$KeepParavirt
    )

    $v = Get-VMInfo -Name $script:TargetVM

    Test-VMSetting -Map $v -Keys @('clipboard')                -Expected @('disabled')   -Label 'clipboard'
    Test-VMSetting -Map $v -Keys @('clipboard_file_transfers') -Expected @('off')        -Label 'clipboard dosya transferi'
    Test-VMSetting -Map $v -Keys @('draganddrop')              -Expected @('disabled')   -Label 'drag and drop'
    Test-VMSetting -Map $v -Keys @('accelerate3d')             -Expected @('off')        -Label '3D hizlandirma'
    Test-VMSetting -Map $v -Keys @('audio_enabled', 'audio')   -Expected @('off','none') -Label 'ses'
    Test-VMSetting -Map $v -Keys @('vrde')                     -Expected @('off')        -Label 'VRDE'
    Test-VMSetting -Map $v -Keys @('nested-hw-virt')           -Expected @('off')        -Label 'ic ice sanallastirma'
    Test-VMSetting -Map $v -Keys @('tracing-enabled')          -Expected @('off')        -Label 'tracing'
    Test-VMSetting -Map $v -Keys @('uart1')                    -Expected @('off')        -Label 'seri port 1'
    Test-VMSetting -Map $v -Keys @('lpt1')                     -Expected @('off')        -Label 'paralel port 1'

    if ($Plan.Mode -eq 'usbwifi') {
        Test-VMSetting -Map $v -Keys @('xhci') -Expected @('on') -Label 'USB 3.0 (passthrough icin)'
    } else {
        Test-VMSetting -Map $v -Keys @('usb')  -Expected @('off') -Label 'USB 1.1'
        Test-VMSetting -Map $v -Keys @('ehci') -Expected @('off') -Label 'USB 2.0'
        Test-VMSetting -Map $v -Keys @('xhci') -Expected @('off') -Label 'USB 3.0'
    }

    if (-not $KeepParavirt) {
        Test-VMSetting -Map $v -Keys @('paravirtprovider') -Expected @('none') -Label 'paravirt provider'
    }

    Test-NoSharedFolders -Map $v
    Write-ActiveNicSummary -Map $v
}

function Test-VMSetting {
    <#
    .SYNOPSIS
        Tek bir konfigurasyon anahtarini beklenen degerlerle karsilastirir.
    .PARAMETER Keys
        Aday anahtarlar; ilk bulunan kullanilir. VirtualBox surumleri arasinda
        anahtar adlari degisebildigi icin liste alir.
    #>
    param(
        [hashtable]$Map,
        [string[]]$Keys,
        [string[]]$Expected,
        [string]$Label
    )

    $found = $null
    foreach ($k in $Keys) {
        if ($Map.ContainsKey($k)) { $found = $Map[$k]; break }
    }

    if ($null -eq $found) {
        Write-Info "$Label -> anahtar bulunamadi (atlandi)"
        return
    }

    if ($Expected -contains $found) {
        Write-Ok "$Label = $found"
    } else {
        Write-Fail "$Label = $found  (beklenen: $($Expected -join '/'))"
    }
}

function Test-NoSharedFolders {
    param([hashtable]$Map)

    $leftovers = @($Map.Keys | Where-Object { $_ -match '^SharedFolderNameMachineMapping\d+$' })
    if ($leftovers.Count -eq 0) {
        Write-Ok 'paylasilan klasor = yok'
    } else {
        Write-Fail "paylasilan klasor hala var: $($leftovers.Count) adet"
    }
}

function Write-ActiveNicSummary {
    param([hashtable]$Map)

    $active = @()
    for ($n = 1; $n -le 8; $n++) {
        if ($Map["nic$n"] -and $Map["nic$n"] -ne 'none') { $active += "nic${n}=$($Map["nic$n"])" }
    }

    if ($active.Count -eq 0) {
        Write-Ok 'sanal ag karti = yok'
    } else {
        Write-Ok "sanal ag karti = $($active -join ', ')"
    }
}

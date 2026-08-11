# ---------------------------------------------------------------------------
# Kapanis ozeti.
#
# Ozet, aracin NE YAPMADIGINI da soyler. Kalan riskleri gizlemek, kullanicida
# olmayan bir guvenlik hissi yaratir - izolasyon araclarinda en tehlikeli hata budur.
# ---------------------------------------------------------------------------

function Write-IsolationSummary {
    <#
    .SYNOPSIS
        Uygulanan ayarlarin, notlarin ve kalan risklerin ozetini yazar.
    #>
    param([Parameter(Mandatory)][object]$Plan)

    Write-Title 'OZET'

    $modeText = switch ($Plan.Mode) {
        'off'     { 'Ag YOK - tam izole' }
        'intnet'  { "Dahili ag (intnet: $($Plan.IntnetName)) - host ve internet erisimi yok" }
        'bridged' { "Bridged -> $($Plan.BridgeInterface.Name)" }
        'usbwifi' { "USB passthrough -> $($Plan.UsbDevice.Label)" }
    }

    $failColor = 'Green'
    if ($script:Failed.Count -gt 0) { $failColor = 'Red' }

    Write-Host ''
    Write-Host "  VM              : $($script:TargetVM)" -ForegroundColor Cyan
    Write-Host "  Ag modu         : $modeText"           -ForegroundColor Cyan
    Write-Host "  Uygulanan ayar  : $($script:Applied.Count)" -ForegroundColor Green
    Write-Host "  Basarisiz ayar  : $($script:Failed.Count)"  -ForegroundColor $failColor

    if ($script:Failed.Count -gt 0) {
        Write-Host ''
        Write-Host '  Basarisiz olanlar:' -ForegroundColor Red
        foreach ($f in $script:Failed) { Write-Host "    - $f" -ForegroundColor Red }
    }

    if ($script:Notes.Count -gt 0) {
        Write-Host ''
        Write-Host '  NOTLAR:' -ForegroundColor Yellow
        foreach ($n in $script:Notes) { Write-Host "    * $n" -ForegroundColor Yellow }
    }

    Write-ResidualRisks -Mode $Plan.Mode

    Write-Host ''
    Write-Host "  VM'i baslatmak icin:" -ForegroundColor White
    Write-Host "    VBoxManage startvm `"$($script:TargetVM)`"" -ForegroundColor DarkGray
    Write-Host ''
}

function Write-ResidualRisks {
    <#
    .SYNOPSIS
        Aracin kapatamadigi, kullanicinin kendisinin halletmesi gereken riskler.
    #>
    param([Parameter(Mandatory)][string]$Mode)

    Write-Host ''
    Write-Host '  KALAN RISKLER (arac bunlari cozemez, siz halletmelisiniz):' -ForegroundColor Magenta
    Write-Host '    * Guest Additions guest icinde kuruluysa host-guest kanali acik kalir.' -ForegroundColor Magenta
    Write-Host '      Zararli analizi icin guest icinden KALDIRIN.' -ForegroundColor Magenta
    Write-Host '    * Snapshot ve VDI dosyalari host diskinde durur; sifreleme kullanin.' -ForegroundColor Magenta

    if ($Mode -eq 'bridged') {
        Write-Host '    * Bridged modda host surucu yigini trafik yolundadir ve VM,' -ForegroundColor Magenta
        Write-Host '      adaptorun bagli oldugu agdaki her cihaza (hostunuz dahil) erisebilir.' -ForegroundColor Magenta
        Write-Host '      Adaptoru MUTLAKA hostunuzdan ayri bir aga baglayin (or. telefon hotspot).' -ForegroundColor Magenta
    }

    if ($Mode -eq 'usbwifi') {
        Write-Host '    * USB denetleyicisi acik - VirtualBox USB emulasyonu bir saldiri yuzeyidir.' -ForegroundColor Magenta
        Write-Host '    * Adaptor VM icindeyken host o cihazi kullanamaz.' -ForegroundColor Magenta
    }

    Write-Host '    * VirtualBox surumunuzu guncel tutun; VM-escape yamalari buradan gelir.' -ForegroundColor Magenta
}

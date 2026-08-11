# ---------------------------------------------------------------------------
# ADIM 3 - Ag modunun ve (gerekiyorsa) adaptorun belirlenmesi.
#
# Izolasyon sirasi:
#   off     - VM icinde hic ag karti yok                        (en izole)
#   usbwifi - harici kablosuz adaptor dogrudan VM'e (passthrough)
#   intnet  - yalnizca dahili ag; host ve internet gorunmez
#   bridged - host adaptoru uzerinden koprule                   (en az izole)
# ---------------------------------------------------------------------------

function Resolve-NetworkPlan {
    <#
    .SYNOPSIS
        Kullanicidan (ya da parametrelerden) ag modunu ve adaptoru cozer.
    .OUTPUTS
        Mode / BridgeInterface / UsbDevice / IntnetName alanlarina sahip plan nesnesi,
        ya da iptal/hata durumunda $null.
    #>
    param(
        [string]$Network,
        [string]$Adapter,
        [Parameter(Mandatory)][string]$IntnetName
    )

    $mode       = $Network
    $bridgeIf   = $null
    $usbDev     = $null
    $intnetName = $IntnetName

    # --- 3a) Modu belirle ---
    if ($mode) {
        Write-Ok "Ag modu (parametreden): $mode"
    } else {
        $result = Select-NetworkMode -DefaultIntnetName $intnetName
        $mode       = $result.Mode
        $intnetName = $result.IntnetName
    }

    # --- 3b) usbwifi: hangi USB cihazi? ---
    if ($mode -eq 'usbwifi') {
        $usbDev = Select-UsbAdapter -Adapter $Adapter
        if (-not $usbDev) { return $null }
    }

    # --- 3c) bridged: hangi host adaptoru? ---
    if ($mode -eq 'bridged') {
        $bridgeIf = Select-BridgedAdapter -Adapter $Adapter
        if (-not $bridgeIf) { return $null }
        Write-BridgedIsolationWarning -Interface $bridgeIf
    }

    if ($mode -eq 'intnet') { Write-Ok "Dahili ag adi: $intnetName" }

    return [pscustomobject]@{
        Mode            = $mode
        BridgeInterface = $bridgeIf
        UsbDevice       = $usbDev
        IntnetName      = $intnetName
    }
}

function Select-NetworkMode {
    <#
    .SYNOPSIS
        "Internete baglansin mi?" sorusunu ve alt secenekleri yonetir.
    #>
    param([Parameter(Mandatory)][string]$DefaultIntnetName)

    $intnetName = $DefaultIntnetName

    if (-not (Read-YesNo -Prompt 'Bu VM internete baglansin mi?' -DefaultYes $false)) {
        Write-Host ''
        Write-Host '  Internetsiz mod secenekleri:' -ForegroundColor White
        Write-Host '  [1] Ag adaptoru tamamen KAPALI  (en yuksek izolasyon - onerilen)' -ForegroundColor Green
        Write-Host '      VM icinde hicbir ag karti gorunmez.' -ForegroundColor DarkGray
        Write-Host "  [2] Yalnizca dahili ag / intnet  (VM'ler birbirini gorur, host ve internet gorunmez)" -ForegroundColor White
        Write-Host '      Coklu makineli lab kurmak icin (or. kurban + saldirgan VM).' -ForegroundColor DarkGray

        if ((Read-Selection -Prompt 'Seciminiz' -Max 2) -eq 1) {
            return [pscustomobject]@{ Mode = 'off'; IntnetName = $intnetName }
        }

        $intnetName = Read-TextWithDefault -Prompt 'Dahili ag adi' -Default $intnetName
        return [pscustomobject]@{ Mode = 'intnet'; IntnetName = $intnetName }
    }

    Write-Host ''
    Write-Host '  Internet baglanti yontemi:' -ForegroundColor White
    Write-Host '  [1] USB passthrough - kablosuz adaptoru dogrudan VM icine ver  (EN IZOLE)' -ForegroundColor Green
    Write-Host '      Host cekirdegi VM trafigini hic islemez, host ag yigini devre disi kalir.' -ForegroundColor DarkGray
    Write-Host '      Guest icinde adaptorun surucusu gerekir (Kali/Ubuntu cogunu tanir).' -ForegroundColor DarkGray
    Write-Host '  [2] Bridged - host adaptoru uzerinden koprule  (KOLAY, daha az izole)' -ForegroundColor Yellow
    Write-Host '      Host surucu yigini trafik yolunda kalir; VM adaptorun agina L2 katilir.' -ForegroundColor DarkGray

    if ((Read-Selection -Prompt 'Seciminiz' -Max 2) -eq 1) {
        return [pscustomobject]@{ Mode = 'usbwifi'; IntnetName = $intnetName }
    }
    return [pscustomobject]@{ Mode = 'bridged'; IntnetName = $intnetName }
}

function Select-UsbAdapter {
    <#
    .SYNOPSIS
        VM'e passthrough edilecek USB cihazini secer.
    .PARAMETER Adapter
        Verilirse VID:PID olarak eslestirilir (or. "0BDA:8812"), menu atlanir.
    #>
    param([string]$Adapter)

    $devices = @(Get-HostUsbDevices)
    if ($devices.Count -eq 0) {
        Write-Fail 'Host uzerinde USB cihaz bulunamadi. Kablosuz adaptoru takip tekrar deneyin.'
        return $null
    }

    if ($Adapter) {
        $wanted = $Adapter.Replace(':', '').Trim().ToUpper()
        $hit = @($devices | Where-Object { ($_.VendorId + $_.ProductId) -eq $wanted })
        if ($hit.Count -eq 0) {
            Write-Fail "VID:PID '$Adapter' host USB cihazlari arasinda yok."
            foreach ($d in $devices) { Write-Info "  $($d.VendorId):$($d.ProductId)  $($d.Label)" }
            return $null
        }
        Write-Ok "Secilen USB cihaz: $($hit[0].Label) ($($hit[0].VendorId):$($hit[0].ProductId))"
        return $hit[0]
    }

    Write-Host ''
    Write-Host '  Host USB cihazlari:' -ForegroundColor White
    $k = 0
    foreach ($d in $devices) {
        $k++
        Write-Host ("  [{0}] {1}" -f $k, $d.Label) -ForegroundColor Cyan
        Write-Host ("      VID:PID {0}:{1}   durum: {2}" -f $d.VendorId, $d.ProductId, $d.State) -ForegroundColor DarkGray
    }
    Write-Warn 'Harici KABLOSUZ adaptorunuzu secin (klavye/mouse/kamera secmeyin!).'

    $choice = Read-Selection -Prompt 'Kablosuz adaptor numarasi' -Max $devices.Count
    $picked = $devices[$choice - 1]
    Write-Ok "Secilen USB cihaz: $($picked.Label) ($($picked.VendorId):$($picked.ProductId))"
    return $picked
}

function Select-BridgedAdapter {
    <#
    .SYNOPSIS
        Koprulenecek host adaptorunu secer. Menude once kablosuz olanlar gosterilir.
    #>
    param([string]$Adapter)

    $ifs = @(Get-BridgedInterfaces)
    if ($ifs.Count -eq 0) {
        Write-Fail 'Koprulenebilir adaptor yok.'
        return $null
    }

    if ($Adapter) {
        $hit = @($ifs | Where-Object { $_.Name -eq $Adapter })
        if ($hit.Count -eq 0) { $hit = @($ifs | Where-Object { $_.Name -like "*$Adapter*" }) }
        if ($hit.Count -eq 0) {
            Write-Fail "'$Adapter' adinda koprulenebilir adaptor yok."
            foreach ($x in $ifs) { Write-Info "  $($x.Name)" }
            return $null
        }
        Write-Ok "Secilen adaptor: $($hit[0].Name)"
        return $hit[0]
    }

    $choices = @($ifs | Where-Object { $_.Wireless })
    if ($choices.Count -eq 0) {
        Write-Warn 'Kablosuz adaptor bulunamadi. Tum adaptorler listeleniyor.'
        Write-Warn 'Harici USB kablosuz adaptorunuz takili degilse simdi takip yeniden calistirin.'
        $choices = $ifs
    }

    Write-Host ''
    Write-Host '  Koprulenebilir adaptorler:' -ForegroundColor White
    $k = 0
    foreach ($ifc in $choices) {
        $k++
        $tag = 'kablolu'
        if ($ifc.Wireless) { $tag = 'KABLOSUZ' }
        Write-Host ("  [{0}] {1}" -f $k, $ifc.Name) -ForegroundColor Cyan
        Write-Host ("      {0} | durum: {1} | IP: {2}" -f $tag, $ifc.Status, $ifc.IPAddress) -ForegroundColor DarkGray
    }

    $choice = Read-Selection -Prompt 'Kullanilacak adaptor numarasi' -Max $choices.Count
    Write-Ok "Secilen adaptor: $($choices[$choice - 1].Name)"
    return $choices[$choice - 1]
}

function Write-BridgedIsolationWarning {
    <#
    .SYNOPSIS
        Bridged modun izolasyon sinirlarini kullaniciya acikca soyler.
    .DESCRIPTION
        Secilen adaptor host uzerinde aktifse VM, host ile ayni L2 segmentine katilir;
        bu durumda "harici adaptor kullaniyorum" hissi yaniltici olur.
    #>
    param([Parameter(Mandatory)][object]$Interface)

    if (-not $Interface.Wireless) {
        Write-Warn 'Secilen adaptor KABLOSUZ degil - muhtemelen hostunuzun ana baglantisi.'
        $null = $script:Notes.Add("Koprulenen adaptor ($($Interface.Name)) kablosuz degil; harici adaptor kullanmak istiyorsaniz yanlis secim yapmis olabilirsiniz.")
    }

    $chosenSubnet = Get-Subnet -Ip $Interface.IPAddress -Mask $Interface.NetMask
    if ($chosenSubnet) {
        Write-Warn "Bu adaptor host uzerinde AKTIF ve $($Interface.IPAddress) adresine sahip."
        Write-Warn 'VM bu aga koprulendiginde host ile AYNI L2 segmentinde olacak;'
        Write-Warn 'zararli yazilim hostunuzu ARP/port taramasi ile gorebilir.'
        $null = $script:Notes.Add("Bridged adaptor ($($Interface.Name)) host ile ayni agda ($($Interface.IPAddress)) - gercek izolasyon icin adaptoru AYRI bir aga (or. telefon hotspot) baglayin.")
    }

    # Host'un birden fazla bacakla ayni agda olup olmadigini da kontrol et
    $others = @(Get-BridgedInterfaces | Where-Object {
        $_.Name -ne $Interface.Name -and $_.Status -eq 'Up' -and $_.IPAddress -and $_.IPAddress -ne '0.0.0.0'
    })
    foreach ($o in $others) {
        $s = Get-Subnet -Ip $o.IPAddress -Mask $o.NetMask
        if ($s -and $chosenSubnet -and $s -eq $chosenSubnet) {
            Write-Fail "DIKKAT: '$($o.Name)' de ayni subnette ($s). Host coklu bacakla ayni agda."
        }
    }
}

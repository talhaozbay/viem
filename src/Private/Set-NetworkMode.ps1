# ---------------------------------------------------------------------------
# ADIM 4b - Ag yapilandirmasi.
#
# Once TUM sanal NIC'ler sifirlanir, sonra yalnizca istenen mod acilir.
# Boylece VM'de unutulmus ikinci bir adaptor kalmaz.
# ---------------------------------------------------------------------------

function Set-NetworkMode {
    <#
    .SYNOPSIS
        Plan nesnesine gore VM'in ag yapilandirmasini uygular.
    #>
    param(
        [Parameter(Mandatory)][object]$Plan,
        [switch]$KeepMac
    )

    Write-Section 'Ag yapilandirmasi'
    Reset-AllNics

    switch ($Plan.Mode) {
        'off' {
            Write-Ok 'Ag modu: TAM IZOLE - VM icinde ag karti yok'
            $null = $script:Applied.Add('Ag: tamamen kapali')
        }
        'intnet' {
            Set-Control -Label "Ag modu: dahili ag (intnet = $($Plan.IntnetName))" -ModifyArgs @('--nic1', 'intnet')
            Set-Control -Label "Dahili ag adi: $($Plan.IntnetName)"                -ModifyArgs @('--intnet1', $Plan.IntnetName)
            Set-Control -Label 'Promiscuous mod: deny'                             -ModifyArgs @('--nic-promisc1', 'deny')
            Set-Control -Label 'Kablo bagli'                                       -ModifyArgs @('--cable-connected1', 'on')
            if (-not $KeepMac) {
                Set-Control -Label 'MAC adresi yenilendi' -ModifyArgs @('--mac-address1', 'auto') -Tolerate
            }
        }
        'bridged' {
            Set-Control -Label 'Ag modu: bridged'                                   -ModifyArgs @('--nic1', 'bridged')
            Set-Control -Label "Koprulenen adaptor: $($Plan.BridgeInterface.Name)"  -ModifyArgs @('--bridge-adapter1', $Plan.BridgeInterface.Name)
            Set-Control -Label 'Promiscuous mod: deny (VM komsu trafigi dinleyemez)' -ModifyArgs @('--nic-promisc1', 'deny')
            Set-Control -Label 'Kablo bagli'                                        -ModifyArgs @('--cable-connected1', 'on')
            if (-not $KeepMac) {
                Set-Control -Label 'MAC adresi yenilendi (host ile iliskilendirilemez)' -ModifyArgs @('--mac-address1', 'auto') -Tolerate
            }
        }
        'usbwifi' {
            Write-Ok 'Ag modu: sanal NIC YOK - internet yalnizca USB kablosuz adaptorden'
            $null = $script:Applied.Add('Ag: sanal NIC yok, USB passthrough')
            Add-UsbPassthroughFilter -Device $Plan.UsbDevice
        }
    }
}

function Reset-AllNics {
    <#
    .SYNOPSIS
        nic1..nic8'i "none" yapar.
    #>
    for ($n = 1; $n -le 8; $n++) {
        $null = Invoke-VBoxWrite -Arguments @('modifyvm', $script:TargetVM, "--nic$n", 'none')
    }
    Write-Ok 'Tum ag adaptorleri (nic1-nic8) sifirlandi'
    $null = $script:Applied.Add('Tum ag adaptorleri sifirlandi')
}

function Add-UsbPassthroughFilter {
    <#
    .SYNOPSIS
        Secilen kablosuz adaptorun VM baslatildiginda otomatik olarak VM'e
        baglanmasi icin USB filtresi ekler.
    .NOTES
        Idempotent: ayni isimli eski filtreler once kaldirilir, yoksa her
        calistirmada birikirler. machinereadable anahtarlari 1-tabanli
        (USBFilterName1), "usbfilter remove" komutu ise 0-tabanli index alir.
    #>
    param([Parameter(Mandatory)][object]$Device)

    $filterName = "isolated-wifi-$($Device.VendorId)$($Device.ProductId)"

    Remove-DuplicateUsbFilters -FilterName $filterName

    $addArgs = @(
        'usbfilter', 'add', '0',
        '--target', $script:TargetVM,
        '--name', $filterName,
        '--vendorid', $Device.VendorId,
        '--productid', $Device.ProductId
    )

    $r = Invoke-VBoxWrite -Arguments $addArgs
    if (-not $r.Ok) {
        # Bazi surumler --action parametresini zorunlu tutar
        $r = Invoke-VBoxWrite -Arguments ($addArgs + @('--action', 'hold'))
    }

    if ($r.Ok) {
        Write-Ok "USB filtresi eklendi: $filterName ($($Device.VendorId):$($Device.ProductId))"
        $null = $script:Applied.Add("USB filtresi: $filterName")
        $null = $script:Notes.Add('VM baslatildiginda kablosuz adaptor otomatik olarak VM icine gecer ve HOST uzerinde kaybolur. Host o adaptorle internete cikamaz - beklenen davranis budur.')
    } else {
        Write-Fail "USB filtresi eklenemedi: $($r.Output)"
        $null = $script:Failed.Add('USB filtresi eklenemedi')
    }
}

function Remove-DuplicateUsbFilters {
    <#
    .SYNOPSIS
        Verilen isimdeki mevcut USB filtrelerini kaldirir (yuksek index'ten basa dogru).
    #>
    param([Parameter(Mandatory)][string]$FilterName)

    $existing = Get-VMInfo -Name $script:TargetVM

    $dupIdx = @()
    for ($fi = 1; $fi -le 64; $fi++) {
        if ($existing["USBFilterName$fi"] -eq $FilterName) { $dupIdx += ($fi - 1) }
    }

    # Silme islemi index'leri kaydirdigi icin sondan basa gidilir
    foreach ($ix in @($dupIdx | Sort-Object -Descending)) {
        $r = Invoke-VBoxWrite -Arguments @('usbfilter', 'remove', "$ix", '--target', $script:TargetVM)
        if ($r.Ok) { Write-Info "Eski USB filtresi kaldirildi (index $ix)" }
    }
}

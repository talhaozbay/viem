# ---------------------------------------------------------------------------
# ADIM 4 - Izolasyon ayarlarinin uygulanmasi.
#
# Iki eksen:
#   1) Host <-> Guest veri kanallari  - zararlinin hosta veri tasimasini engeller
#   2) Saldiri yuzeyi azaltma         - VM-escape icin kullanilabilecek emule
#                                       cihaz/arayuzleri kaldirir
# ---------------------------------------------------------------------------

function Set-IsolationControl {
    <#
    .SYNOPSIS
        Ag disindaki tum izolasyon ayarlarini hedef VM'e uygular.
    .PARAMETER Mode
        Ag modu; USB denetleyicilerinin acik mi kapali mi kalacagini belirler.
    #>
    param(
        [Parameter(Mandatory)][string]$Mode,
        [switch]$KeepParavirt
    )

    Set-HostGuestChannel
    Set-AttackSurface -KeepParavirt:$KeepParavirt
    Set-UsbController -Mode $Mode
    Disable-HostTimeSync
}

function Set-HostGuestChannel {
    <#
    .SYNOPSIS
        Pano, surukle-birak ve paylasilan klasor kanallarini kapatir.
    #>
    Write-Section 'Host <-> Guest veri kanallari'

    # NOT: --clipboard-file-transfers "enabled|disabled" alir, "on|off" DEGIL.
    Set-Control -Label 'Pano (clipboard) paylasimi kapatildi'    -ModifyArgs @('--clipboard-mode', 'disabled')
    Set-Control -Label 'Pano dosya transferi kapatildi'          -ModifyArgs @('--clipboard-file-transfers', 'disabled')
    Set-Control -Label 'Surukle-birak (drag and drop) kapatildi' -ModifyArgs @('--drag-and-drop', 'disabled')

    Remove-AllSharedFolders
}

function Remove-AllSharedFolders {
    <#
    .SYNOPSIS
        VM'de tanimli tum paylasilan klasorleri kaldirir.
    #>
    $info = Get-VMInfo -Name $script:TargetVM

    $shares = @()
    foreach ($key in $info.Keys) {
        if ($key -match '^SharedFolderNameMachineMapping\d+$') { $shares += $info[$key] }
    }

    if ($shares.Count -eq 0) {
        Write-Ok 'Paylasilan klasor yok (zaten temiz)'
        $null = $script:Applied.Add('Paylasilan klasor yok')
        return
    }

    foreach ($s in $shares) {
        $r = Invoke-VBoxWrite -Arguments @('sharedfolder', 'remove', $script:TargetVM, '--name', $s)
        if ($r.Ok) {
            Write-Ok "Paylasilan klasor kaldirildi: $s"
            $null = $script:Applied.Add("Paylasilan klasor kaldirildi: $s")
        } else {
            Write-Fail "Paylasilan klasor kaldirilamadi: $s ($($r.Output))"
            $null = $script:Failed.Add("Paylasilan klasor: $s")
        }
    }
}

function Set-AttackSurface {
    <#
    .SYNOPSIS
        VM-escape icin kullanilabilecek emule cihazlari ve host arayuzlerini kapatir.
    #>
    param([switch]$KeepParavirt)

    Write-Section 'Saldiri yuzeyi azaltma'

    # 3D hizlandirma VirtualBox'ta en cok VM-escape CVE'si cikan bilesendir.
    Set-Control -Label '3D hizlandirma kapatildi (bilinen VM-escape yuzeyi)' -ModifyArgs @('--accelerate-3d', 'off')
    Set-Control -Label 'Ses (audio) kapatildi'              -ModifyArgs @('--audio-enabled', 'off')
    Set-Control -Label 'Ses surucusu none yapildi'          -ModifyArgs @('--audio-driver', 'none')            -Tolerate
    Set-Control -Label 'Uzak masaustu (VRDE) kapatildi'     -ModifyArgs @('--vrde', 'off')
    Set-Control -Label 'Ic ice sanallastirma kapatildi'     -ModifyArgs @('--nested-hw-virt', 'off')
    Set-Control -Label 'VM tracing kapatildi'               -ModifyArgs @('--tracing-enabled', 'off')          -Tolerate
    Set-Control -Label 'VM tracing guest erisimi kapatildi' -ModifyArgs @('--tracing-allow-vm-access', 'off')  -Tolerate
    Set-Control -Label 'Ekran kaydi kapatildi'              -ModifyArgs @('--recording', 'off')                -Tolerate

    # Seri/paralel portlar host uzerinde bir pipe ya da dosyaya baglanabilir
    for ($u = 1; $u -le 4; $u++) {
        Set-Control -Label "Seri port $u kapatildi" -ModifyArgs @("--uart$u", 'off') -Tolerate
    }
    for ($l = 1; $l -le 2; $l++) {
        Set-Control -Label "Paralel port $l kapatildi" -ModifyArgs @("--lpt$l", 'off') -Tolerate
    }

    if ($KeepParavirt) {
        Write-Info 'Paravirt provider degistirilmedi (-KeepParavirt)'
        return
    }

    Set-Control -Label 'Paravirtualization provider = none (host arayuzu kaldirildi)' -ModifyArgs @('--paravirt-provider', 'none')
    $null = $script:Notes.Add('Paravirt provider "none" yapildi - guest performansi dusebilir. Geri almak icin: -KeepParavirt ile calistirin veya --paravirt-provider default.')
}

function Set-UsbController {
    <#
    .SYNOPSIS
        USB denetleyicilerini kapatir; yalnizca usbwifi modunda xHCI acik birakilir.
    .NOTES
        VirtualBox 7.1+ ile USB 2.0/3.0 base pakettedir; Extension Pack gerekmez.
    #>
    param([Parameter(Mandatory)][string]$Mode)

    Write-Section 'USB'

    if ($Mode -eq 'usbwifi') {
        Set-Control -Label 'USB 3.0 (xHCI) acik - kablosuz adaptor passthrough icin gerekli' -ModifyArgs @('--usb-xhci', 'on')
        Set-Control -Label 'USB 1.1 (OHCI) kapatildi'   -ModifyArgs @('--usb-ohci', 'off')        -Tolerate
        Set-Control -Label 'USB 2.0 (EHCI) kapatildi'   -ModifyArgs @('--usb-ehci', 'off')        -Tolerate
        Set-Control -Label 'USB kart okuyucu kapatildi' -ModifyArgs @('--usb-card-reader', 'off') -Tolerate

        $null = $script:Notes.Add('USB denetleyicisi acik birakildi (kablosuz adaptor icin). Bu ek bir saldiri yuzeyidir; sadece secilen adaptor VM icine baglanacak sekilde filtre eklendi.')
        return
    }

    Set-Control -Label 'USB 1.1 (OHCI) kapatildi'   -ModifyArgs @('--usb-ohci', 'off')        -Tolerate
    Set-Control -Label 'USB 2.0 (EHCI) kapatildi'   -ModifyArgs @('--usb-ehci', 'off')        -Tolerate
    Set-Control -Label 'USB 3.0 (xHCI) kapatildi'   -ModifyArgs @('--usb-xhci', 'off')        -Tolerate
    Set-Control -Label 'USB kart okuyucu kapatildi' -ModifyArgs @('--usb-card-reader', 'off') -Tolerate
}

function Disable-HostTimeSync {
    <#
    .SYNOPSIS
        Guest Additions kanali uzerinden host saatinin guest'e sizmasini engeller.
    #>
    $r = Invoke-VBoxWrite -Arguments @(
        'setextradata', $script:TargetVM,
        'VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', '1'
    )

    if ($r.Ok) {
        Write-Ok 'Host saat senkronizasyonu kapatildi'
        $null = $script:Applied.Add('Host saat senkronizasyonu kapatildi')
    } else {
        Write-Warn "Host saat senkronizasyonu kapatilamadi ($($r.Output))"
    }
}

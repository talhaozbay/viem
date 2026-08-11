# ---------------------------------------------------------------------------
# Ana akis. Adimlari sirayla calistirir ve modul kapsamli durumu yonetir.
# ---------------------------------------------------------------------------

function Invoke-VMIsolation {
    <#
    .SYNOPSIS
        Bir VirtualBox VM'ini ana makineden maksimum duzeyde izole eder.

    .DESCRIPTION
        Alti adimda calisir:
          1. VM secimi
          2. Guc durumu (modifyvm kapali VM gerektirir)
          3. Ag modu ve adaptor secimi
          4. Izolasyon ayarlarinin uygulanmasi
          5. Uygulanan ayarlarin VM konfigurasyonundan geri okunarak dogrulanmasi
          6. Temiz durum snapshot'i

    .PARAMETER VBoxManagePath
        VBoxManage.exe otomatik bulunamazsa tam yol.

    .PARAMETER DryRun
        Hicbir degisiklik yazmaz, yalnizca calistirilacak komutlari gosterir.

    .PARAMETER KeepParavirt
        Paravirtualization provider'i "none" yapmaz (guest performansi icin).

    .PARAMETER KeepMac
        NIC MAC adresini yeniden uretmez.

    .PARAMETER VMName
        Verilirse VM secim menusu atlanir.

    .PARAMETER Network
        Verilirse ag modu sorusu atlanir: off | intnet | bridged | usbwifi

    .PARAMETER Adapter
        bridged icin host adaptor adi, usbwifi icin VID:PID (or. 0BDA:8812).

    .PARAMETER IntnetName
        Dahili ag adi (yalnizca intnet modunda).

    .PARAMETER NoSnapshot
        Snapshot sorusunu atlar.

    .PARAMETER Force
        VM calisiyorsa sormadan kapatir; kaydedilmis durumu sormadan siler.

    .EXAMPLE
        Invoke-VMIsolation
        Etkilesimli mod.

    .EXAMPLE
        Invoke-VMIsolation -VMName 'win10-lab' -Network off -NoSnapshot
        Tam izole, agsiz, soru sormadan.

    .EXAMPLE
        Invoke-VMIsolation -VMName 'win10-lab' -Network usbwifi -Adapter '0BDA:8812'
        Harici USB kablosuz adaptorle izole internet.
    #>
    [CmdletBinding()]
    param(
        [string]$VBoxManagePath,
        [switch]$DryRun,
        [switch]$KeepParavirt,
        [switch]$KeepMac,
        [string]$VMName,
        [ValidateSet('off', 'intnet', 'bridged', 'usbwifi')]
        [string]$Network,
        [string]$Adapter,
        [string]$IntnetName = 'malware-lab',
        [switch]$NoSnapshot,
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    # --- Modul kapsamli durum ---
    # Bu degiskenler tum ozel fonksiyonlar tarafindan paylasilir.
    $script:DryRunMode = [bool]$DryRun
    $script:TargetVM   = $null
    $script:Applied    = New-Object System.Collections.Generic.List[string]
    $script:Failed     = New-Object System.Collections.Generic.List[string]
    $script:Notes      = New-Object System.Collections.Generic.List[string]

    Write-Title 'VirtualBox VM IZOLASYON ARACI'
    if ($script:DryRunMode) { Write-Warn 'DRY-RUN modu: hicbir degisiklik yazilmayacak.' }

    $script:VBoxManage = Resolve-VBoxManage -Explicit $VBoxManagePath
    Write-Info "VBoxManage : $script:VBoxManage"
    Write-Info "Surum      : $((Invoke-VBoxRead -Arguments @('--version')).Output)"

    # --- ADIM 1: VM secimi ---
    Write-Step 'ADIM 1/6 - Izole edilecek sanal makineyi secin'
    $script:TargetVM = Select-TargetVM -VMName $VMName
    if (-not $script:TargetVM) { return }

    # --- ADIM 2: Guc durumu ---
    Write-Step 'ADIM 2/6 - Guc durumu'
    if (-not (Confirm-PowerState -Name $script:TargetVM -Force:$Force)) { return }

    # --- ADIM 3: Ag plani ---
    Write-Step 'ADIM 3/6 - Internet baglantisi'
    $plan = Resolve-NetworkPlan -Network $Network -Adapter $Adapter -IntnetName $IntnetName
    if (-not $plan) { return }

    # --- ADIM 4: Izolasyon ayarlari ---
    Write-Step 'ADIM 4/6 - Izolasyon ayarlari uygulaniyor'
    Set-IsolationControl -Mode $plan.Mode -KeepParavirt:$KeepParavirt
    Set-NetworkMode -Plan $plan -KeepMac:$KeepMac

    # --- ADIM 5: Dogrulama ---
    Write-Step 'ADIM 5/6 - Dogrulama'
    if ($script:DryRunMode) {
        Write-Info 'DRY-RUN modunda dogrulama atlandi.'
    } else {
        Test-IsolationState -Plan $plan -KeepParavirt:$KeepParavirt
    }

    # --- ADIM 6: Snapshot ---
    Write-Step 'ADIM 6/6 - Temiz durum snapshot'
    New-CleanSnapshot -NoSnapshot:$NoSnapshot

    Write-IsolationSummary -Plan $plan
}

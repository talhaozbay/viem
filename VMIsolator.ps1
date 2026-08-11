#Requires -Version 5.1
<#
.SYNOPSIS
    VirtualBox VM Izolasyon Araci - zararli yazilim analizi / pentest laboratuvari
    icin bir VM'i ana makineden maksimum duzeyde izole eder.

.DESCRIPTION
    Bu dosya yalnizca giris noktasidir: src/ altindaki VMIsolator modulunu yukler
    ve Invoke-VMIsolation'i cagirir. Isin tamami modulde yapilir.

.PARAMETER VBoxManagePath
    VBoxManage.exe otomatik bulunamazsa tam yol.

.PARAMETER DryRun
    Hicbir degisiklik yapmaz, sadece calistirilacak komutlari gosterir.

.PARAMETER KeepParavirt
    Paravirtualization provider'i "none" yapmaz (performans icin mevcut halde birakir).

.PARAMETER KeepMac
    NIC MAC adresini yeniden uretmez.

.PARAMETER VMName
    Verilirse VM secim menusu atlanir ve dogrudan bu VM kullanilir.

.PARAMETER Network
    Verilirse ag modu sorusu atlanir. off | intnet | bridged | usbwifi

.PARAMETER Adapter
    -Network bridged icin host adaptor adi, usbwifi icin VID:PID (or. 0BDA:8812).

.PARAMETER IntnetName
    Dahili ag adi (yalnizca intnet modunda).

.PARAMETER NoSnapshot
    Snapshot sorusunu atlar.

.PARAMETER Force
    VM calisiyorsa sormadan kapatir.

.EXAMPLE
    .\VMIsolator.ps1
    Etkilesimli mod: VM'leri listeler, secim ister.

.EXAMPLE
    .\VMIsolator.ps1 -DryRun
    Hicbir sey degistirmeden ne yapilacagini gosterir.

.EXAMPLE
    .\VMIsolator.ps1 -VMName "win10-lab" -Network off -NoSnapshot
    Tam izole, agsiz, soru sormadan.

.EXAMPLE
    .\VMIsolator.ps1 -VMName "win10-lab" -Network usbwifi -Adapter "0BDA:8812"
    Harici USB kablosuz adaptorle izole internet.

.LINK
    https://github.com/talhaozbay/VMIsolator
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

# Turkce karakterlerin konsolda dogru gorunmesi icin
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$manifest = Join-Path $PSScriptRoot 'src\VMIsolator.psd1'
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "Modul bulunamadi: $manifest  (src/ klasoru bu betikle ayni dizinde olmali)"
}

# -Force: her calistirmada taze yukle, onbellekte kalmis eski surum kullanilmasin
Import-Module $manifest -Force

Invoke-VMIsolation @PSBoundParameters

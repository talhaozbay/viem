# ---------------------------------------------------------------------------
# VMIsolator modul yukleyicisi.
#
# Private/ ve Public/ altindaki tum .ps1 dosyalarini modul kapsamina alir.
# Yalnizca Public/ altindaki fonksiyonlar disariya acilir; Private/ icindekiler
# modul icinde kalir ve global ad alanini kirletmez.
#
# Ozel fonksiyonlar $script: kapsamli durumu paylasir (VBoxManage yolu, DryRun
# bayragi, hedef VM, uygulanan/basarisiz ayar listeleri). Dot-source edildikleri
# icin bu kapsam modulun kendisidir.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$publicFiles  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($privateFiles + $publicFiles)) {
    try {
        . $file.FullName
    } catch {
        throw "Modul dosyasi yuklenemedi: $($file.Name) -> $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function ($publicFiles | ForEach-Object { $_.BaseName })

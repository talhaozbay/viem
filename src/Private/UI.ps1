# ---------------------------------------------------------------------------
# Konsol cikti yardimcilari.
# Tum kullanici arayuzu metni buradan gecer; renk/format tek yerden yonetilir.
# ---------------------------------------------------------------------------

function Write-Title {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
}

function Write-Step    { param([string]$Text) Write-Host ''; Write-Host ">> $Text" -ForegroundColor White }
function Write-Ok      { param([string]$Text) Write-Host "   [+] $Text" -ForegroundColor Green }
function Write-Fail    { param([string]$Text) Write-Host "   [-] $Text" -ForegroundColor Red }
function Write-Warn    { param([string]$Text) Write-Host "   [!] $Text" -ForegroundColor Yellow }
function Write-Info    { param([string]$Text) Write-Host "   [i] $Text" -ForegroundColor DarkGray }
function Write-Section { param([string]$Text) Write-Host ''; Write-Host "   -- $Text --" -ForegroundColor DarkCyan }

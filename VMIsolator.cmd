@echo off
rem ===========================================================================
rem  VMIsolator baslatici
rem
rem  Windows'ta .ps1 dosyalari guvenlik geregi Not Defteri ile iliskilendirilmistir;
rem  cift tiklayinca calismaz. Bu dosya cift tiklanabilir ve PowerShell'i dogru
rem  parametrelerle cagirir:
rem
rem    -NoProfile          : kullanicinin profil betikleri karismasin
rem    -ExecutionPolicy Bypass : sadece BU surec icin; sistem ayari degismez
rem
rem  Kullanim:
rem    VMIsolator.cmd                         (cift tiklayin - etkilesimli mod)
rem    VMIsolator.cmd -DryRun
rem    VMIsolator.cmd -VMName "win10-lab" -Network off -NoSnapshot
rem ===========================================================================

setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [-] powershell.exe bulunamadi. Windows PowerShell 5.1 gereklidir.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0VMIsolator.ps1" (
    echo.
    echo   [-] VMIsolator.ps1 bulunamadi. Bu dosya proje klasorunde olmali.
    echo.
    pause
    exit /b 1
)

rem Internetten indirilen dosyalar "Mark of the Web" ile isaretlenir ve
rem PowerShell bunlari engelleyebilir. Sessizce kaldiriyoruz.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-ChildItem -LiteralPath '%~dp0.' -Recurse -Include *.ps1,*.psm1,*.psd1 | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0VMIsolator.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

rem Parametresiz calistirildiysa (cift tiklama) pencere hemen kapanmasin
if "%~1"=="" (
    echo.
    echo   Kapatmak icin bir tusa basin...
    pause >nul
)

endlocal & exit /b %EXITCODE%

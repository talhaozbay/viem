# ---------------------------------------------------------------------------
# Etkilesimli girdi okuma.
#
# Her ikisi de sinirli sayida deneme yapar: stdin kapaliysa (CI, pipe, zamanlanmis
# gorev) Read-Host aninda bos doner ve sonsuz donguye girilmesi engellenir.
# ---------------------------------------------------------------------------

function Read-Selection {
    <#
    .SYNOPSIS
        1..Max arasinda bir sayi okur.
    .OUTPUTS
        Secilen sayi; -AllowQuit ile 'q' girilirse -1.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][int]$Max,
        [switch]$AllowQuit
    )

    $hint = " (1-$Max)"
    if ($AllowQuit) { $hint = " (1-$Max, q=cikis)" }

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        Write-Host ''
        $raw = ''
        try { $raw = [string](Read-Host "$Prompt$hint") } catch { $raw = '' }
        $raw = $raw.Trim()

        if ($AllowQuit -and ($raw -eq 'q' -or $raw -eq 'Q')) { return -1 }

        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $Max) { return $n }

        Write-Warn 'Gecersiz secim, tekrar deneyin.'
    }

    throw 'Gecerli bir secim alinamadi (5 deneme). Etkilesimsiz calistirmak icin -VMName / -Network parametrelerini kullanin.'
}

function Read-YesNo {
    <#
    .SYNOPSIS
        Evet/hayir sorusu okur. Bos girdi varsayilani secer.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$DefaultYes = $false
    )

    $suffix = ' [e/H]'
    if ($DefaultYes) { $suffix = ' [E/h]' }

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        Write-Host ''
        $raw = ''
        try { $raw = [string](Read-Host "$Prompt$suffix") } catch { $raw = '' }
        $raw = $raw.Trim().ToLower()

        if ($raw -eq '') { return $DefaultYes }
        if ($raw -eq 'e' -or $raw -eq 'evet' -or $raw -eq 'y' -or $raw -eq 'yes') { return $true }
        if ($raw -eq 'h' -or $raw -eq 'hayir' -or $raw -eq 'n' -or $raw -eq 'no') { return $false }

        Write-Warn "Lutfen 'e' veya 'h' girin."
    }
    return $DefaultYes
}

function Read-TextWithDefault {
    <#
    .SYNOPSIS
        Serbest metin okur; bos birakilirsa varsayilani dondurur.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$Default
    )

    Write-Host ''
    $raw = ''
    try { $raw = [string](Read-Host "$Prompt [$Default]") } catch { $raw = '' }
    $raw = $raw.Trim()

    if ($raw) { return $raw }
    return $Default
}

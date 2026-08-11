@{
    RootModule        = 'VMIsolator.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'ad11c728-fbbb-47f8-adeb-c222c5e3ea42'

    Author            = 'talha.ozbay'
    Description       = 'VirtualBox VM izolasyon araci - zararli yazilim analizi ve pentest laboratuvari icin bir VM i ana makineden maksimum duzeyde izole eder.'

    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @('Invoke-VMIsolation')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('VirtualBox', 'Security', 'MalwareAnalysis', 'Sandbox', 'Isolation', 'Pentest')
            ProjectUri = 'https://github.com/talhaozbay/VMIsolator'
        }
    }
}

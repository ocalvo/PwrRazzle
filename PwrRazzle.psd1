@{
    ## Module Info
    ModuleVersion      = '1.0.0'
    Description        = 'Setup Razzle for Windows App developement'
    GUID               = '563978bc-d4fd-4c00-99f1-05afd5df0219'
    HelpInfoURI        = 'https://github.com/ocalvo/PwrRazzle'

    ## Module Components
    RootModule         = @("PwrRazzle.psm1")
    ScriptsToProcess   = @()
    TypesToProcess     = @()
    FormatsToProcess   = @()
    FileList           = @()

    ## Public Interface
    CmdletsToExport    = ''
    FunctionsToExport  = @(
        "Execute-Razzle",
        "Get-BuildErrors",
        "Edit-BuildErrors")
    VariablesToExport  = @()
    AliasesToExport    = @("razzle")
    # DscResourcesToExport = @()
    # DefaultCommandPrefix = ''

    ## Requirements
    # CompatiblePSEditions = @()
    PowerShellVersion      = '3.0'
    # PowerShellHostName     = ''
    # PowerShellHostVersion  = ''
    RequiredModules        = @()
    RequiredAssemblies     = @()
    ProcessorArchitecture  = 'None'
    DotNetFrameworkVersion = '2.0'
    CLRVersion             = '2.0'

    ## Author
    Author             = 'https://github.com/ocalvo'
    CompanyName        = ''
    Copyright          = ''

    ## Private Data
    PrivateData        = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @("productivity","razzle","VS","vsshell", "vs-shell", "msbuild")

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/ocalvo/PwrRazzle'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @"
## 2022-08-11 - Version 1.0.0

- Move Get-BuildErrors to https://github.com/ocalvo/PwrDev

## 2022-03-16 - Version 0.0.7

- Dont try to enter dev shell if dev shell already active
- Add option to disable symbolic links creation

## 2021-09-15 - Version 0.0.6

Remove more hard code paths

## 2021-09-15 - Version 0.0.5

Fix an issue where msbuild.cmd may fail with PowerShell core

## 2021-09-15 - Version 0.0.4

Fix issue with razzle alias

## 2021-09-10 - Version 0.0.3

Fix an issue with Get-BuildErrors and Edit-BuildErrors

## 2021-09-10 - Version 0.0.2

Remove not needed gif

## 2021-09-10 - Version 0.0.1

Initial release

"@
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}

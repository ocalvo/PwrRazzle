param(
  [Parameter(Mandatory=$false)][String]$vsVersion = "Enterprise",
  [Parameter(Mandatory=$false)][String]$vsYear = "2022"
)

$devEnvCmd = get-command devenv.exe*
if ($null -ne $devEnvCmd)
{
   Write-Host "Already Under DevShell"
   .$PSScriptRoot\MSBuild-Alias.ps1
}

$installPath = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -prerelease -all -products * -property installationpath
$vsVersions = $installPath |
  Select-Object @{Name='Version';Expression={Split-Path $_ -Leaf | Select-Object -First 1}},
    @{Name='Year';Expression={Split-Path (Split-Path $_) -Leaf | Select-Object -First 1}},
    @{Name='Path';Expression={$_}}

Write-Host "Found the following versions:"
Write-Host $vsVersions

$ver = $vsVersions | Where-Object {($_.Version -eq $vsVersion) -and ($_.Year -eq $vsYear) } | Select-Object -First 1
Write-Host "Match the following versions:"
$ver |% {
  Write-Host ("  "+$_)
}

if ($null -eq $ver)
{
  throw "Visual Studio version $vsVersion not found"
}

if ($ver.Length -gt 1)
{
  throw "Multiple Visual Studio versions match"
}

$devShellModule = Join-Path $ver.Path "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Write-Host "Loading module $devShellModule"
Import-Module $devShellModule
$vsVerPath = $ver.Path
Write-Host "Loading VS Shell from $vsVerPath"
Enter-VsDevShell -VsInstallPath $vsVerPath -SkipAutomaticLocation

.$PSScriptRoot\MSBuild-Alias.ps1


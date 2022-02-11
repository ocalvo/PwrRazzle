param(
  [Parameter(Mandatory=$false)][String]$vsVersion = "Preview",
  [Parameter(Mandatory=$false)][String]$vsYear = "2019",
  [Parameter(Mandatory=$false)][switch]$x64 = $false
)

$installPath = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -prerelease -all -products * -property installationpath
$vsVersions = $installPath |
  Select-Object @{Name='Version';Expression={Split-Path $_ -Leaf | Select-Object -First 1}},
    @{Name='Year';Expression={Split-Path $_ | Split-Path -Leaf | Select-Object -Last 1}},
    @{Name='Path';Expression={$_}}

$bitness = "*86*"
if ($x64.IsPresent)
{
  $bitness = ""
}
$startPath = (get-item ("env:ProgramFiles"+$bitness)).Value
$ver = $vsVersions | Where-Object {($_.Version -eq $vsVersion) -and ($_.Year -eq $vsYear) -and ($_.Path.StartsWith($startPath)) }
Write-Host "Found the following versions:"
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


#################################
#
# Razzle scripts
# ocalvo@microsoft.com
#
[CmdletBinding()]
param (
  $flavor="fre",
  $arch="x64",
  $device=$null,
  $binariesPrefix = "c:\bin",
  $vsVersion = "Enterprise",
  $vsYear = "2022",
  $ddDir = $env:LOCALAPPDATA,
  [switch]$noSymbolicLinks = $true,
  [switch]$bl_ok,
  [switch]$DevBuild,
  [switch]$opt,
  [switch]$noDeep,
  [switch]$nobtok,
  [switch]$gitVersionCheck,
  [switch]$autoMount,
  [switch]$Async,
  [int]$commitLookUp=20,
  [switch]$fast = $true,
  [switch]$noprompt = $true,
  $enlistment = $env:SDXROOT)

##
## Support to get out and get in of razzle
##

$global:ddIni = ($ddDir+"\dd.ini")

function Check-GSudo
{
  if ($null -eq (get-command gsudo -ErrorAction Ignore))
  {
    winget install gsudo
    $env:path += ";C:\Program Files (x86)\gsudo\"
  }
  gsudo cache on -p 0
}

if (!($noSymbolicLinks.IsPresent))
{
  Check-GSudo
}

if ($null -eq $enlistment)
{
  Write-Verbose "Reading last enlistment from $global:ddIni"
  if (test-path $global:ddIni)
  {
    $ddIniData = (Get-Content $global:ddIni)
    $enlistment = $ddIniData | Select -First 1
    Write-Verbose "Found enlistment:'$enlistment'"
    $data = $ddIniData | Select -Skip 1 -First 1
    if ($null -ne $data) {
      Write-Verbose "Override arch to $data from ddIni"
      $arch = $data
    }
    $data = $ddIniData | Select -Skip 2 -First 1
    if ($null -ne $data) {
      Write-Verbose "Override flavor to $data from ddIni"
      $flavor = $data
    }
  }
  else
  {
    throw "Enlistment parameter not specified"
  }
}

if (test-path $enlistment)
{
  Set-Location $enlistment
  Push-Location $enlistment
}

if ($null -ne $env:_BuildArch) {$arch=$env:_BuildArch;}
if ($null -ne $env:_BuildType) {$flavor=$env:_BuildType;}

Set-Alias UnRazzle Execute-OutsideRazzle -Scope Global;

[hashtable]$razzleKind = [ordered]@{
  DevDiv = "\src\tools\razzle.ps1";
  Windows = "\developer\razzle.ps1";
  Lifted = "\init.cmd";
  Phone = "\wm\tools\bat\WPOpen.ps1" }

function Get-RazzleProbeDir($kind, $srcDir)
{
    return ($srcDir+$razzleKind[$kind])
}

function Get-RazzleKind($srcDir)
{
  $kind = $razzleKind.Keys | Where-Object { (test-path (Get-RazzleProbeDir $_ $srcDir)) } | Select-Object -First 1
  return $kind
}

function global:Get-RazzleProbes()
{
  [string[]]$razzleProbe = $null

  if ((test-path $ddIni) -and ($null -eq $enlistment))
  {
    $enlistment = (get-content $ddIni)
    $razzleProbe += $enlistment
    return $razzleProbe
  }
  else
  {
    if (($null -ne $enlistment) -and (test-path $enlistment))
    {
      $razzleProbe += $enlistment
      return $razzleProbe
    }
  }

  throw "Enlistment not provided"
}

function __Get-BranchName($razzleDirName)
{
  $branch = (git branch | Where-Object { $_.StartsWith("*") } | select -first 1 )
  if ($null -ne $branch)
  {
    $branch = $branch.Split("/") | select -last 1
    if ($null -ne $branch)
    {
      return $branch;
    }
  }
  return $razzleDirName;
}

function global:Get-BranchCustomId()
{
    [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    if ($null -ne $branch)
    {
      return ($branch.Split("/") | select -last 1)
    }
}

function Invoke-RazzleAsync {

}

function Execute-FastRazzle {
  Write-Verbose "Fast razzle using $env:EnlistmentEnv"
  if (Test-path $env:EnlistmentEnv) {
    Get-Content $env:EnlistmentEnv | ConvertFrom-Json |% { $k=$_.Name; $v=$_.Value; Set-Item -Path env:$k -Value $v }
    $setRazzle = "$srcDir/utilities/psrazzle/setrazzle.ps1"
    if (Test-Path $setRazzle) {
      .$setRazzle
    }
  }
}

function Execute-Razzle-Internal($flavor="chk",$arch="x86",$enlistment)
{
  if ( ($gitVersionCheck.IsPresent) )
  {
    Write-Verbose "Checking git version..."
    gvfs upgrade
  }

  $popDir = Get-Location

  $razzleProbe = (Get-RazzleProbes)
  $binaries = $binariesPrefix

  foreach ($driveEnlistRoot in $razzleProbe)
  {
    if (test-path $driveEnlistRoot)
    {
      $razzleDirName = split-path $driveEnlistRoot -leaf
      $depotRoot = $driveEnlistRoot
      Write-Verbose "Probing $depotRoot..."

      if ($depotRoot -like "*\os*\src" -and $autoMount.IsPresent)
      {
        Write-Verbose "gvfs mount $depotRoot..."
        Check-GSudo
        gsudo Start-Service GVFS.Service
        gvfs mount $depotRoot
      }

      $srcDir = $depotRoot;
      Write-Verbose "Searching for razzle kind in $srcDir"
      $global:kind = Get-RazzleKind $srcDir
      if ($null -ne $kind)
      {
        Write-Verbose "Found razzle kind: $kind"
        Push-Location $srcDir
        $razzle = (Get-RazzleProbeDir $kind $srcDir)
        if ( test-path $razzle )
        {
          Write-Verbose "Found razzle script: $razzle"
          if (!($popDir.Path.StartsWith($depotRoot)))
          {
             $podDir = $null
          }

          Write-Verbose "Store $srcDir,$arch,$flavor in $ddIni"
          Set-Content $ddIni $srcDir
          Add-Content $ddIni $arch
          Add-Content $ddIni $flavor

          $env:RazzleOptions = ""
          if (!($opt.IsPresent))
          {
            $env:RazzleOptions += " no_opt "
          }

          if ( ($DevBuild.IsPresent) )
          {
            $env:RazzleOptions += " dev_build "
          }

          $binaries = ($binariesPrefix+(__Get-BranchName $razzleDirName))
          $tempDir = ($binaries + "\temp")

          if ($noDeep.IsPresent)
          {
            $env:RazzleOptions += " binaries_dir " + $binaries + "\bin "
            $env:RazzleOptions += " object_dir " + $binaries + "\obj "
            $env:RazzleOptions += " public_dir " + $binaries + "\public "
            $env:RazzleOptions += " output_dir " + $binaries + "\out "
            $env:RazzleOptions += " temp " + $tempDir
          }

          Write-Verbose "Adding razzle commands line arguments"

          if ($nobtok.IsPresent)
          {
            $env:RazzleOptions += " no_bl_ok "
          }

          $env:_XROOT = $srcDir.Trim("\")
          $env:_XOSROOT = (get-item "$srcDir\..\").FullName
          Write-Verbose "Razzle Fast mode: $fast"

          $commitId = (git rev-parse HEAD)
          if ($fast) {
             $lastCommits = git log -n $commitLookUp --pretty=format:"%H"
             $lastEnvId = $lastCommits | Where-Object { Test-Path "$env:_XOSROOT\$_.$arch.$flavor.env.json" } | Select -First 1
             if (($null -ne $lastEnvId) -and ($lastEnvId -ne $commitId)) {
                 $commitId = $lastEnvId
             }
          }
          $env:EnlistmentEnv = "$env:_XOSROOT\$commitId.$arch.$flavor.env.json"

          $perlCmd = "$env:_XOSROOT\tools\perl\bin\perl.exe"
          $perlExists = (Test-Path $perlCmd)
          Push-Location "$env:_XOSROOT\src"
          if ($Async) {
            Execute-FastRazzle
            Set-Location $PSScriptRoot
            $global:RazzleJob = Start-ThreadJob -ScriptBlock {
              param(
                $razzle,
                $arch,
                $flavor,
                $binaries,
                $depotRoot,
                $noPrompt,
                $noSymbolicLinks,
                $args)
              .".\Execute-RealRazzle.ps1" -razzle $razzle -arch $arch -flavor $flavor -binaries $binaries -depotRoot $depotRoot -noPrompt:$noPrompt -noSymbolicLinks:$noSymbolicLinks @args
            } -ArgumentList ($razzle, $arch, $flavor, $binaries, $depotRoot, ($noPrompt.IsPresent), $true, $args)
          } elseif ( ($null -ne $env:EnlistmentEnv) -and (Test-Path $env:EnlistmentEnv) -and ($fast) -and ($perlExists)) {
            Execute-FastRazzle
          } else {
            ."$PSScriptRoot\Execute-RealRazzle.ps1" -razzle:$razzle -arch $arch -flavor $flavor -binaries $binaries -depotRoot $depotRoot -noPrompt:($noPrompt.IsPresent) -noSymbolicLinks:($noSymbolicLinks.IsPresent) @args
          }

          Pop-Location
          if ($null -ne $popDir)
          {
            Set-Location $popDir
          }

          return
        }
        Write-Verbose $razzle
      }
    }
  }
  throw "Razzle not found"
}

if (!(test-path "$binariesPrefix\Symbols"))
{
   mkdir "$binariesPrefix\Symbols" | Out-Null
}

if (!(test-path "$binariesPrefix\SymCache"))
{
   mkdir "$binariesPrefix\SymCache" | Out-Null
}

if (!(test-path "$binariesPrefix\Temp"))
{
   mkdir "$binariesPrefix\Temp" | Out-Null
}

Execute-Razzle-Internal -flavor $flavor -arch $arch -enlistment $enlistment

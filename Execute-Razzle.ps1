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
  [int]$commitLookUp=20,
  [switch]$fast = $true,
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
  if (test-path $global:ddIni)
  {
     $enlistment = (Get-Content $global:ddIni)
  }
  else
  {
     throw "Enlistment parameter not specified"
  }
}

if (test-path $enlistment)
{
  Set-Location $enlistment
  pushd $enlistment
}

if ($null -ne $env:_BuildArch) {$arch=$env:_BuildArch;}
if ($null -ne $env:_BuildType) {$flavor=$env:_BuildType;}

function global:Execute-OutsideRazzle
{
  param([ScriptBlock] $script)

  Undo-Razzle;
  try
  {
    & $script;
  }
  finally
  {
    Redo-Razzle;
  }
}

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
  $kind = $razzleKind.Keys | where { (test-path (Get-RazzleProbeDir $_ $srcDir)) } | Select-Object -First 1
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
    if (($enlistment -ne $null) -and (test-path $enlistment))
    {
      $razzleProbe += $enlistment
      return $razzleProbe
    }
  }

  throw "Enlistment not provided"
}

function __Get-BranchName($razzleDirName)
{
  $branch = (git branch | where { $_.StartsWith("*") } | select -first 1 )
  if ($branch -ne $null)
  {
    $branch = $branch.Split("/") | select -last 1
    if ($branch -ne $null)
    {
      return $branch;
    }
  }
  return $razzleDirName;
}

function global:New-RazzleLink($linkName, $binaries)
{
  if ($noSymbolicLinks.IsPresent)
  {
     return;
  }
  Write-Verbose "Linking $linkName -> $binaries ..."

  if (!(test-path $binaries))
  {
     Write-Verbose "Making new dir $binaries"
     mkdir $binaries | Out-Null
  }

  $currentTarget = $null
  if (test-path $linkName)
  {
     $currentTarget = (Get-Item $linkName).Target
  }
  if (($currentTarget -eq $null) -or ($currentTarget -ne $binaries))
  {
     Write-Verbose "Making new link $linkName -> $binaries"
     gsudo New-Item $linkName -ItemType SymbolicLink -Target $binaries -Force
  }
}

function global:Get-BranchCustomId()
{
    [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    if ($null -ne $branch)
    {
      return ($branch.Split("/") | select -last 1)
    }
}

function global:Retarget-Razzle
{
    Write-Verbose "Retarget-Razzle"

    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    Write-Verbose ("Retargeting common paths")

    New-RazzleLink "c:\Symbols" "$binariesPrefix\Symbols"
    New-RazzleLink "c:\Symcache" "$binariesPrefix\Symbols"
    New-RazzleLink "c:\Sym" "$binariesPrefix\Symbols"
    #New-RazzleLink $env:temp "$binariesPrefix\Temp"
    New-RazzleLink $env:HOMEDRIVE$env:HOMEPATH\.nuget "$binariesPrefix\NuGet"
    New-RazzleLink "c:\Temp" "$binariesPrefix\Temp"
    New-RazzleLink "c:\Logs" "$binariesPrefix\Logs"
    New-RazzleLink "c:\CrashDumps" "$binariesPrefix\CrashDumps"
    New-RazzleLink "c:\ProgramData\dbg\Sym" "$binariesPrefix\Symbols"
    New-RazzleLink "c:\ProgramData\dbg\Src" "$binariesPrefix\src"

    Write-Verbose ("Retargeting done")
}

function global:Retarget-OSRazzle($binariesRoot, $srcRoot = $env:OSBuildRoot)
{
    Write-Verbose "Retarget-OSRazzle"

    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    Write-Verbose ("Retargeting $srcRoot -> $binariesRoot")

    Push-Location ($srcRoot+"\src")
    $binRoot = $srcRoot.Replace("f:","w:")
    $binRoot = $binRoot.Replace("F:","w:")
    $binRoot = $binRoot.Replace("c:\src","w:")
    $binRoot = $binRoot.Replace("C:\src","w:")
    Write-Verbose "Branch binRoot is $binRoot"
    Pop-Location

    New-RazzleLink "$binariesPrefix\os" $binRoot
    New-RazzleLink ($srcRoot+"\bin") ($binRoot+"\bin")
    New-RazzleLink ($srcRoot+"\bldcache") ($binRoot+"\bldcache")
    New-RazzleLink ($srcRoot+"\bldout") ($binRoot+"\bldout")
    New-RazzleLink ($srcRoot+"\cdg") ($binRoot+"\cdg")
    New-RazzleLink ($srcRoot+"\intl") ($binRoot+"\intl")
    New-RazzleLink ($srcRoot+"\engcache") ($binRoot+"\engcache")
    New-RazzleLink ($srcRoot+"\pgo") ($binRoot+"\pgo")
    New-RazzleLink ($srcRoot+"\public") ($binRoot+"\public")
    New-RazzleLink ($srcRoot+"\pubpkg") ($binRoot+"\pubpkg")
    New-RazzleLink ($srcRoot+"\obj") ($binRoot+"\obj")
    New-RazzleLink ($srcRoot+"\osdep") ($binRoot+"\osdep")
    New-RazzleLink ($srcRoot+"\out") ($binRoot+"\out")
    New-RazzleLink ($srcRoot+"\Temp") ($binRoot+"\Temp")
    New-RazzleLink ($srcRoot+"\tools") ($binRoot+"\tools")
    New-RazzleLink ($srcRoot+"\utilities") ($binRoot+"\utilities")

    New-RazzleLink ($binRoot+"\src") ($srcRoot+"\src")
    New-RazzleLink ($srcRoot+"\TestPayload") ($binRoot+"\TestPayload")

    Write-Verbose ("Retargeting done")
}

function global:Retarget-LiftedRazzle
{
    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    $_srcName = Split-Path $enlistment -Leaf
    $binRoot = ($binariesPrefix+"\"+$_srcName)
    $srcRoot = ("c:\src\"+$_srcName)
    Write-Verbose "Branch binRoot is $binRoot, srcRoot is $srcRoot"

    New-RazzleLink ($srcDir+"\packages") ("$binariesPrefix\NuGet\packages")
    New-RazzleLink ($srcDir+"\buildOutput") ($binRoot)
    New-RazzleLink ($srcDir+"\TestPayload") ($binRoot+"\TestPayLoad")
    New-RazzleLink ($srcDir+"\bin") ($binRoot+"\bin")
    New-RazzleLink ($srcDir+"\obj") ($binRoot+"\obj")
    New-RazzleLink ($srcDir+"\temp") ($binRoot+"\temp")
    New-RazzleLink ($srcDir+"\log") ($binRoot+"\out")
}

function Execute-Razzle-Internal($flavor="chk",$arch="x86",$enlistment)
{
  if ( ($gitVersionCheck.IsPresent) )
  {
    Write-Verbose "Checking git version..."
    gvfs upgrade
  }

  $popDir = Get-Location

  #Undo-Razzle

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

          Write-Verbose "Store $srcDir in $ddIni"
          set-content $ddIni $srcDir

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

          Retarget-Razzle

          Write-Verbose "Adding razzle commands line arguments"

          if ($nobtok.IsPresent)
          {
            $env:RazzleOptions += " no_bl_ok "
          }

          $phoneOptions = ""
          if ( $kind -eq "Phone" )
          {
            $uConfig = ($ddDir + '\DefaultWindowsSettings.uconfig')
            if (test-path $uConfig)
            {
              $phoneOptions += " uconfig=" + $uConfig + " "
            }

            $phoneOptions += (" UConfig_Razzle_Parameters=`""+$env:RazzleOptions+"`" ")
          }

          $env:_XROOT = $srcDir.Trim("\")
          $env:_XOSROOT = (get-item "$srcDir\..\").FullName
          Write-Verbose "Razzle Fast mode: $fast"
          if ($fast) {
             $lastCommits = git log -n $commitLookUp --pretty=format:"%H"
             $lastEnvId = $lastCommits | where { Test-Path "$env:_XOSROOT\$_.env.json" } | Select -First 1
             $commitId = (git rev-parse HEAD)
             if (($null -ne $lastEnvId) -and ($lastEnvId -ne $commitId)) {
                 $commitId = $lastEnvId
             }
             $env:EnlistmentEnv = "$env:_XOSROOT\$commitId.env.json"
          }

          if ( (Test-Path $env:EnlistmentEnv) -and $fast.IsPresent) {
            Write-Verbose "Fast razzle using $env:EnlistmentEnv"
            Get-Content $env:EnlistmentEnv | ConvertFrom-Json |% { $k=$_.Name; $v=$_.Value; Set-Item -Path env:$k -Value $v }
          } else {
            Remove-Item "$env:_XOSROOT\*.env.json"
            if ( $kind -eq "Phone" ) {
              Write-Verbose "Phone: $razzle $device $arch$flavor $phoneOptions"
              .$razzle $device ($arch+$flavor) $phoneOptions @args
            }
            elseif ( $kind -eq "Lifted" ) {
              Write-Verbose "Lifted: $razzle $initParams"
              Retarget-LiftedRazzle
              Push-Location $env:SDXROOT
              Enter-VSShell -vsVersion $vsVersion -vsYear $vsYear
              Write-Verbose ".$razzle $arch$flavor"
              $initParams = (($arch+$flavor),"/2019")
              $initParams = (($arch+$flavor))
              Invoke-CmdScript -script $razzle -parameters $initParams
              .$PSScriptRoot\MSBuild-Alias.ps1 -msBuildAlias
            }
            else {
              Write-Verbose "Windows: $razzle"
              Retarget-OSRazzle $binaries (Get-item $depotRoot).Parent.FullName
              $arch = $arch.Replace("x64","amd64")

              $setRazzlePs1Dir = "$env:_XROOT\developer\$env:USERNAME"
              Write-Verbose "Reseting setrazzle.ps1: $setRazzlePs1Dir"
              mkdir $setRazzlePs1Dir -ErrorAction Ignore | Out-Null
              $setRazzlePs1 = "$setRazzlePs1Dir\setrazzle.ps1"
              Set-Content "" -Path $setRazzlePs1
              Write-Verbose ".$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt $args"
              .$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt @args
            }
            $envData = Get-ChildItem env: | Select -Property Name,Value
            $envData | ConvertTo-Json -Depth 2 | Set-Content $env:EnlistmentEnv
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

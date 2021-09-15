#################################
#
# Razzle scripts
# ocalvo@microsoft.com
#
param (
  $flavor="fre",
  $arch="x86",
  $device=$null,
  $binaries = "c:\bin",
  $vsVersion = "Enterprise",
  $ddDir = $env:LOCALAPPDATA,
  [switch]$symbolicLinks = $true,
  [switch]$bl_ok,
  [switch]$oacr,
  [switch]$opt,
  [switch]$noDeep,
  [switch]$nobtok,
  [switch]$gitVersionCheck,
  $enlistment = $env:SDXROOT)

##
## Support to get out and get in of razzle
##

$global:ddIni = ($ddDir+"\dd.ini")

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
if (!(test-path $enlistment))
{
  sudo Unlock-MyBitlocker
}

if (test-path $enlistment)
{
  Set-Location $enlistment
  pushd $enlistment
}

if ($null -ne $env:_BuildArch) {$arch=$env:_BuildArch;}
if ($null -ne $env:_BuildType) {$flavor=$env:_BuildType;}

$global:UnRazzleEnv = (Get-ChildItem env:*);
$global:RazzleEnv = $null;

function global:Undo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:UnRazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value > $null 2> $null
  }
}

function global:Redo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:RazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value > $null 2> $null
  }
}

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
function Get-Batchfile ($file)
{
  $cmd = "echo off & `"$file`" & set"
  cmd /c $cmd | Foreach-Object {
    $p, $v = $_.split('=')
    Set-Item -path env:$p -value $v
  }
}

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
  $kind = $razzleKind.Keys |
    where {
      (test-path (Get-RazzleProbeDir $_ $srcDir))
    } |
      select -first 1
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

function Get-BranchName($razzleDirName)
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
  if (!($symbolicLinks.IsPresent))
  {
     return;
  }
  echo "Linking $linkName -> $binaries ..."

  if (!(test-path $binaries))
  {
     echo "Making new dir $binaries"
     mkdir $binaries > $null
  }

  $currentTarget = $null
  if (test-path $linkName)
  {
     $currentTarget = (Get-Item $linkName).Target
  }
  if (($currentTarget -eq $null) -or ($currentTarget -ne $binaries))
  {
     echo "Making new link $linkName -> $binaries"
     sudo New-Item $linkName -ItemType SymbolicLink -Target $binaries -Force
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

function Remove-InvalidFileNameChars
{
  param([Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
      [String]$Name
  )
  return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), ' ')
}

function global:Retarget-Razzle
{
    Write-Output ("Retargeting common paths")

    New-RazzleLink "c:\Symbols" "c:\bin\Symbols"
    New-RazzleLink "c:\Symcache" "c:\bin\Symbols"
    New-RazzleLink "c:\Sym" "c:\bin\Symbols"
    #New-RazzleLink $env:temp "c:\bin\Temp"
    New-RazzleLink $env:HOMEDRIVE$env:HOMEPATH\.nuget c:\bin\NuGet
    New-RazzleLink "c:\Temp" "c:\bin\Temp"
    New-RazzleLink "c:\Logs" "c:\bin\Logs"
    New-RazzleLink "c:\CrashDumps" "c:\bin\CrashDumps"
    New-RazzleLink "c:\VHDs" "c:\bin\VHDs"
    New-RazzleLink "c:\Debuggers" "c:\dd\Debuggers"
    New-RazzleLink "c:\dd\Debuggers\Sym" "c:\bin\Symbols"
    New-RazzleLink "c:\dd\Debuggers\Wow64\Sym" "c:\bin\Symbols"
    New-RazzleLink "c:\ProgramData\dbg\Sym" "c:\bin\Symbols"
    New-RazzleLink "c:\ProgramData\dbg\Src" "c:\bin\src"
    New-RazzleLink "c:\Polaris" "c:\bin\Polaris"

    Write-Output ("Retargeting done")
}

function global:Retarget-OSRazzle($binariesRoot, $srcRoot = $env:OSBuildRoot)
{
    Write-Output ("Retargeting $srcRoot -> $binariesRoot")

    Push-Location ($srcRoot+"\src")
    $binRoot = $srcRoot.Replace("f:","w:")
    $binRoot = $binRoot.Replace("F:","w:")
    $binRoot = $binRoot.Replace("c:\src","w:")
    $binRoot = $binRoot.Replace("C:\src","w:")
    Write-Output "Branch binRoot is $binRoot"
    Pop-Location

    New-RazzleLink "c:\bin\os" $binRoot
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


    $enlistNumber = $srcRoot.Substring($srcRoot.LastIndexOf("os")+2,1)
    $workspaceFolder = "F:\os$enlistNumber"
    $realWorkspaceFile = "$workspaceFolder\os$enlistNumber.code-workspace"
    if (test-path $realWorkspaceFile)
    {
      $title = Get-WindowTitleSuffix
      $title = $enlistNumber + " " + $title
      $fileName = Remove-InvalidFileNameChars $title
      $workSpaceFile = "$workspaceFolder\$fileName.code-workspace"
      if (!(test-path $workSpaceFile))
      {
        #sudo new-item -ItemType SymbolicLink $workSpaceFile -Target $realWorkspaceFile
      }
      $otherLinks = Get-ChildItem $workspaceFolder\*.code-workspace | Where-Object -Property LinkType -eq SymbolicLink | Where-Object -Property BaseName -ne $fileName
      if ($null -ne $otherLinks)
      {
        $otherLinks | ForEach-Object { $item = $_;  Write-Warning ("Deleting "+$item.FullName); $item.Delete() }
      }
    }

    Write-Output ("Retargeting done")
}

function global:Retarget-LiftedRazzle
{
    $_srcName = Split-Path $enlistment -Leaf
    $binRoot = ("c:\bin\"+$_srcName)
    $srcRoot = ("c:\src\"+$_srcName)
    Write-Output "Branch binRoot is $binRoot, srcRoot is $srcRoot"

    New-RazzleLink ($srcDir+"\packages") ("c:\bin\NuGet\packages")
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
    Write-Host "Checking git version..."
    gvfs upgrade
    #open-elevated -wait cmd /c '\\ntdev\sourcetools\release\Setup.cmd' -Canary
  }

  $popDir = Get-Location

  Undo-Razzle

  $razzleProbe = (Get-RazzleProbes)

  foreach ($driveEnlistRoot in $razzleProbe)
  {
    echo $driveEnlistRoot
    if (test-path $driveEnlistRoot)
    {
      $razzleDirName = split-path $driveEnlistRoot -leaf
      $depotRoot = $driveEnlistRoot
      Write-Host "Probing $depotRoot..."

      if ($depotRoot -like "*\os*\src")
      {
        Write-Host "gvfs mount $depotRoot..."
        sudo Start-Service GVFS.Service
        gvfs mount $depotRoot
      }

      $srcDir = $depotRoot;
      $global:kind = Get-RazzleKind $srcDir
      if ($null -ne $kind)
      {
        Push-Location $srcDir
        $razzle = (Get-RazzleProbeDir $kind $srcDir)
        if ( test-path $razzle )
        {
          if (!($popDir.Path.StartsWith($depotRoot)))
          {
             $podDir = $null
          }

          set-content $ddIni $srcDir

          $env:RazzleOptions = ""
          if (!($opt.IsPresent))
          {
            $env:RazzleOptions += " no_opt "
          }

          if ( !($oacr.IsPresent) )
          {
            $env:RazzleOptions += " no_oacr "
          }

          $binaries += $razzleDirName
          $binaries = ("c:\bin\"+(Get-BranchName $razzleDirName))
          $tempDir = ($binaries + "\temp")

          if ($noDeep.IsPresent)
          {
            $env:RazzleOptions += " binaries_dir " + $binaries + "\bin "
            $env:RazzleOptions += " object_dir " + $binaries + "\obj "
            $env:RazzleOptions += " public_dir " + $binaries + "\public "
            $env:RazzleOptions += " output_dir " + $binaries + "\out "
            $env:RazzleOptions += "  temp " + $tempDir
          }
          Retarget-Razzle

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

          [string]$extraArgs
          $args |ForEach-Object { $extraArgs += " " + $_ }

          if (test-path ('~\Documents\'+$env:__PSShellDir+'\Razzle\'))
          {
            $extraArgs += (" developer_dir ~\Documents\"+$env:__PSShellDir+"\Razzle\ ")
          }

          $env:_XROOT = $srcDir.Trim("\")

          if ( $kind -eq "Phone" ) {
            .$razzle $device ($arch+$flavor) $phoneOptions $extraArgs
          }
          elseif ( $kind -eq "Lifted" ) {
            Retarget-LiftedRazzle
            Push-Location $env:SDXROOT
            Enter-VSShell -vsVersion $vsVersion
            Write-Output ".$razzle $arch$flavor"
            $initParams = (($arch+$flavor),"/2019")
            $initParams = (($arch+$flavor))
            Invoke-CmdScript -script $razzle -parameters $initParams
            .$PSScriptRoot\MSBuild-Alias.ps1 -msBuildAlias
          }
          else {
            Retarget-OSRazzle $binaries (Get-item $depotRoot).Parent.FullName
            Write-Output ".$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt"
            .$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt
          }

          $global:RazzleEnv = (Get-ChildItem env:*);

          $env:_NT_SYMBOL_PATH+=(';'+$env:_nttree+'\symbols.pri\retail\dll')
          $env:CG_TEMP = ($env:TEMP+"\CatGates")
          if (test-path env:LANG)
          {
            Remove-Item env:LANG
          }
          Pop-Location
          if ($null -ne $popDir)
          {
            Set-Location $popDir
          }

          $title = Get-WindowTitleSuffix
          Write-Host ("Branch:"+$title) -ForegroundColor Yellow
          return
        }
        Write-Output $razzle
      }
    }
  }
  throw "Razzle not found"
}

if (!(test-path "c:\bin\Symbols"))
{
   mkdir c:\bin\Symbols
}

if (!(test-path "c:\bin\SymCache"))
{
   mkdir c:\bin\SymCache
}

if (!(test-path "c:\bin\Temp"))
{
   mkdir c:\bin\Temp
}

Execute-Razzle-Internal -flavor $flavor -arch $arch -enlistment $enlistment


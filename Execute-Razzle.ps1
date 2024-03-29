﻿#################################
#
# Razzle scripts
# ocalvo@microsoft.com
#
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
  [switch]$verbose,
  $enlistment = $env:SDXROOT)

##
## Support to get out and get in of razzle
##

$global:ddIni = ($ddDir+"\dd.ini")

#$env:MSBUILD_VERBOSITY="binlog"

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

$global:UnRazzleEnv = (Get-ChildItem env:*);
$global:RazzleEnv = $null;

function global:Undo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:UnRazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value -Force
  }
}

function global:Redo-Razzle
{
  Remove-Item env:*;
  foreach ($env_entry in $global:RazzleEnv)
  {
    New-Item -Path env: -Name $env_entry.Name  -Value $env_entry.Value -Force
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
  if ($verbose.IsPresent) {
    Write-Host "Linking $linkName -> $binaries ..."
  }

  if (!(test-path $binaries))
  {
     if ($verbose.IsPresent) {
       Write-Host "Making new dir $binaries"
     }
     mkdir $binaries > $null
  }

  $currentTarget = $null
  if (test-path $linkName)
  {
     $currentTarget = (Get-Item $linkName).Target
  }
  if (($currentTarget -eq $null) -or ($currentTarget -ne $binaries))
  {
     if ($verbose.IsPresent) {
       Write-Host "Making new link $linkName -> $binaries"
     }
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
    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    if ($verbose.IsPresent) {
      Write-Host ("Retargeting common paths")
    }

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

    if ($verbose.IsPresent) {
      Write-Host ("Retargeting done")
    }
}

function global:Retarget-OSRazzle($binariesRoot, $srcRoot = $env:OSBuildRoot)
{
    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    if ($verbose.IsPresent) {
      Write-Host ("Retargeting $srcRoot -> $binariesRoot")
    }

    Push-Location ($srcRoot+"\src")
    $binRoot = $srcRoot.Replace("f:","w:")
    $binRoot = $binRoot.Replace("F:","w:")
    $binRoot = $binRoot.Replace("c:\src","w:")
    $binRoot = $binRoot.Replace("C:\src","w:")
    if ($verbose.IsPresent) {
      Write-Host "Branch binRoot is $binRoot"
    }
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
        #gsudo new-item -ItemType SymbolicLink $workSpaceFile -Target $realWorkspaceFile
      }
      $otherLinks = Get-ChildItem $workspaceFolder\*.code-workspace | Where-Object -Property LinkType -eq SymbolicLink | Where-Object -Property BaseName -ne $fileName
      if ($null -ne $otherLinks)
      {
        $otherLinks | ForEach-Object { $item = $_;  Write-Warning ("Deleting "+$item.FullName); $item.Delete() }
      }
    }

    if ($verbose.IsPresent) {
      Write-Host ("Retargeting done")
    }
}

function global:Retarget-LiftedRazzle
{
    if ($noSymbolicLinks.IsPresent) {
      return;
    }

    $_srcName = Split-Path $enlistment -Leaf
    $binRoot = ($binariesPrefix+"\"+$_srcName)
    $srcRoot = ("c:\src\"+$_srcName)
    if ($verbose.IsPresent) {
      Write-Host "Branch binRoot is $binRoot, srcRoot is $srcRoot"
    }

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
    if ($verbose.IsPresent) {
      Write-Host "Checking git version..."
    }
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
      if ($verbose.IsPresent) {
        Write-Host "Probing $depotRoot..."
      }

      if ($depotRoot -like "*\os*\src")
      {
        if ($verbose.IsPresent) {
          Write-Host "gvfs mount $depotRoot..."
        }
        Check-GSudo
        gsudo Start-Service GVFS.Service
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
            Enter-VSShell -vsVersion $vsVersion -vsYear $vsYear
            if ($verbose.IsPresent) {
              Write-Host ".$razzle $arch$flavor"
            }
            $initParams = (($arch+$flavor),"/2019")
            $initParams = (($arch+$flavor))
            Invoke-CmdScript -script $razzle -parameters $initParams
            .$PSScriptRoot\MSBuild-Alias.ps1 -msBuildAlias
          }
          else {
            Retarget-OSRazzle $binaries (Get-item $depotRoot).Parent.FullName
            if ($verbose.IsPresent) {
              Write-Host ".$razzle $flavor $arch $env:RazzleOptions $extraArgs noprompt"
            }
            $arch = $arch.Replace("x64","amd64")

            $setRazzlePs1 = "$env:_XROOT\developer\$env:USERNAME\setrazzle.ps1"
            Set-Content "" -Path $setRazzlePs1
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

          if ($null -ne (get-command Get-WindowTitleSuffix*))
          {
            $title = Get-WindowTitleSuffix
            if ($verbose.IsPresent) {
              Write-Host ("Branch:"+$title) -ForegroundColor Yellow
            }
          }
          return
        }
        if ($verbose.IsPresent) {
          Write-Host $razzle
        }
      }
    }
  }
  throw "Razzle not found"
}

if (!(test-path "$binariesPrefix\Symbols"))
{
   mkdir "$binariesPrefix\Symbols"
}

if (!(test-path "$binariesPrefix\SymCache"))
{
   mkdir "$binariesPrefix\SymCache"
}

if (!(test-path "$binariesPrefix\Temp"))
{
   mkdir "$binariesPrefix\Temp"
}

Execute-Razzle-Internal -flavor $flavor -arch $arch -enlistment $enlistment


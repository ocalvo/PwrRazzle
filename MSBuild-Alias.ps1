Param([switch]$msBuildAlias)

$global:lastBuildErrors = $null
if ($null -eq $env:_msBuildPath)
{
  $env:_msBuildPath = (get-command msbuild).Definition
}

$env:_MSBUILD_VERBOSITY = "m"
$env:_VSINSTALLDIR = Split-path ((Split-Path ($env:_msBuildPath) -Parent)+"\..\..\") -Resolve
$env:_MSBUILD_EXTRAPARAMS = "/p:NuGetInteractive=`"true`""

function global:msb()
{
  ps msbuild* | where { $_.StartInfo.EnvironmentVariables['RepoRoot'] -eq $env:RepoRoot } | kill -force
  $global:lastBuildErrors = $null
  $date = [datetime]::Now

  #$dMarker = $date.ToString("yyMMdd-HHmmss.")
  #$logFileName = (".\build"+$dMarker+$env:_BuildType)
  $logFileName = ("build"+$env:_BuildType) # If you change this, update Get-BuildErrors

  .$env:_msBuildPath "/bl:LogFile=$logFileName.binlog" /nologo /v:$env:_MSBUILD_VERBOSITY $env:_MSBUILD_EXTRAPARAMS /m $args "-flp2:LogFile=$logFileName.err;errorsonly" "-flp3:LogFile=$logFileName.wrn;warningsonly"
  $global:lastBuildErrors = Get-BuildErrors
  if ($null -ne $global:lastBuildErrors)
  {
    Write-Warning "Build errors detected:`$lastBuildErrors"
  }
  # Kill lingering msbuild proceses
  # ps msbuild* | where { $_.StartInfo.EnvironmentVariables['RepoRoot'] -eq $env:RepoRoot } | kill -force
}

function global:build()
{
  msb /target:Build $args
}

function global:buildclean()
{
  msb /target:ReBuild $args
}

set-alias b        build -scope global
set-alias bc       buildclean -scope global
if ($msBuildAlias.IsPresent)
{
  set-alias msbuild  build -scope global
  $env:path = ($PSScriptRoot+';'+$env:path)
}

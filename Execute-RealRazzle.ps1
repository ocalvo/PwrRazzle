[CmdLetBinding()]
param(
  $razzle,
  $arch,
  $flavor,
  $binaries,
  $depotRoot,
  [switch]$noPrompt,
  [switch]$noSymbolicLinks)

function New-RazzleLink($linkName, $binaries)
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

function Retarget-OSRazzle($binariesRoot, $srcRoot = $env:OSBuildRoot)
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

function Retarget-Razzle
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

Write-Verbose "Execute-RealRazzle"

Remove-Item "$env:_XOSROOT\*.$arch.$flavor.env.json" -Exclude $env:EnlistmentEnv

Retarget-Razzle
Retarget-OSRazzle $binaries (Get-item $depotRoot).Parent.FullName
$arch = $arch.Replace("x64","amd64")

$setRazzlePs1Dir = "$env:_XROOT\developer\$env:USERNAME"
Write-Verbose "Reseting setrazzle.ps1: $setRazzlePs1Dir"
mkdir $setRazzlePs1Dir -ErrorAction Ignore | Out-Null
$setRazzlePs1 = "$setRazzlePs1Dir\setrazzle.ps1"
Set-Content "" -Path $setRazzlePs1
if ($noPrompt) {
  $args += "noprompt"
}
Write-Verbose ".$razzle $flavor $arch $env:RazzleOptions $args"
.$razzle $flavor $arch $env:RazzleOptions @args

$envData = Get-ChildItem env: | Select-Object -Property Name,Value
$envData | ConvertTo-Json -Depth 2 | Set-Content $env:EnlistmentEnv
Write-Verbose "Stored razzle environment in '$env:EnlistmentEnv'"



. ($PSScriptRoot+'\VSO-Helpers.ps1')

set-alias Execute-Razzle ($PSScriptRoot+'\Execute-Razzle.ps1')            -scope global
set-alias Enter-VSShell ($PSScriptRoot+'\Enter-VSShell.ps1')            -scope global
set-alias Invoke-CmdScript ($PSScriptRoot+'\Invoke-CmdScript.ps1')      -scope global

function global:Get-BuildErrors()
{
    $buildErrorsDir = ".\"
    $buildErrorsFile = ($buildErrorsDir + "build" + $env:_BuildType + ".err")
    if (!(Test-Path $buildErrorsFile))
    {
        return;
    }
    Get-Content .\build$env:_BuildType.err | where-object { $_ -like "*(*)*: error *" } |ForEach-Object {
        $fileStart = $_.IndexOf(">")
        $fileEnd = $_.IndexOf("(")
        $fileName = $_.SubString($fileStart + 1, $fileEnd - $fileStart - 1)
        $lineNumberEnd =  $_.IndexOf(")")
        $lineNumber = $_.SubString($fileEnd + 1, $lineNumberEnd - $fileEnd - 1)
        $errorStart = $_.IndexOf(": ");
        $errorDescription = $_.SubString($errorStart + 2);
        $columnNumberStart= $lineNumber.IndexOf(",")
        if (-1 -ne $columnNumberStart)
        {
            $lineNumber = $lineNumber.substring(0, $columnNumberStart)
        }
        [System.Tuple]::Create($fileName,$lineNumber,$errorDescription)
    }
}
Export-ModuleMember -Function Get-BuildErrors

function global:Open-Editor($fileName,$lineNumber)
{
  if ($null -ne $env:VSCODE_CWD)
  {
    $codeParam = ($fileName+":"+$lineNumber)
    code --goto $codeParam
  }
  elseif ($null -ne (get-command edit))
  {
    edit $fileName ("+"+$lineNumber)
  }
  else
  {
    .$env:SDEDITOR $fileName
  }
}
Export-ModuleMember -Function Open-Editor

function global:Edit-BuildErrors($first=1,$skip=0)
{
  Get-BuildErrors | Select-Object -First $first -Skip $skip |ForEach-Object { Open-Editor $_.Item1 $_.Item2 }
}
Export-ModuleMember -Function Edit-BuildErrors

Export-ModuleMember -Alias Enter-VSShell
Export-ModuleMember -Alias Invoke-CmdScript
Export-ModuleMember -Alias Execute-Razzle

Export-ModuleMember -Function Get-VSOAuth
Export-ModuleMember -Function Unlock-MyBitLocker




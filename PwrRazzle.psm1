
set-alias Execute-Razzle ($PSScriptRoot+'\Execute-Razzle.ps1')            -scope global
set-alias Invoke-CmdScript ($PSScriptRoot+'\Invoke-CmdScript.ps1')      -scope global

Export-ModuleMember -Alias Invoke-CmdScript
Export-ModuleMember -Alias Execute-Razzle

Export-ModuleMember -Function Get-VSOAuth
Export-ModuleMember -Function Unlock-MyBitLocker

set-alias razzle Execute-Razzle -scope global


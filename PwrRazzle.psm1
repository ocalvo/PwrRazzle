
set-alias Execute-Razzle ($PSScriptRoot+'\Execute-Razzle.ps1')            -scope global
set-alias Enter-VSShell ($PSScriptRoot+'\Enter-VSShell.ps1')            -scope global
set-alias Invoke-CmdScript ($PSScriptRoot+'\Invoke-CmdScript.ps1')      -scope global

Export-ModuleMember -Alias Enter-VSShell
Export-ModuleMember -Alias Invoke-CmdScript
Export-ModuleMember -Alias Execute-Razzle

Export-ModuleMember -Function Get-VSOAuth
Export-ModuleMember -Function Unlock-MyBitLocker

set-alias razzle Execute-Razzle -scope global


# PwrRazzle
Setups Razzle environment for Windows Apps development

# Manual Setup

1. Clone the repo into your Modules folder
For PowerShell core
```
git clone https://github.com/ocalvo/PwrRazzle.git "$env:HomeDrive$env:HomePath\Documents\PowerShell\Modules\PwrSudo"
```
For Windows Power Shell
```
git clone https://github.com/ocalvo/PwrRazzle.git "$env:HomeDrive$env:HomePath\Documents\WindowsPowerShell\Modules\PwrSudo"
```
2. Edit your `$profile` file and add the following line:
```
Import-Module PwrRazzle
```

# Usage

```
Execute-Razzle -arch x86 -flavor chk -vsVersion Enterprise -Enlistment c:\xm1
```

# PwrRazzle
Setups Razzle environment for Windows Apps development

# Setup ([via Powershell gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.1))
```
Install-module PwrRazzle -Scope CurrentUser
```

# Manual Setup

1. Clone the repo into your Modules folder:
  - For PowerShell core:
  ```
  git clone https://github.com/ocalvo/PwrRazzle.git "$env:HomeDrive$env:HomePath\Documents\PowerShell\Modules\PwrSudo"
  ```
  - For Windows Power Shell:
  ```
  git clone https://github.com/ocalvo/PwrRazzle.git "$env:HomeDrive$env:HomePath\Documents\WindowsPowerShell\Modules\PwrSudo"
  ```
2. Edit your `$profile` file and add the following line:
```
Import-Module PwrRazzle
```

# Usage

```
Execute-Razzle -arch x86 -flavor chk -vsVersion Enterprise -vsYear 2022 -Enlistment c:\xm1
```

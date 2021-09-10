
$global:knownBugs = @{}

function global:Unlock-MyBitLocker()
{
  if ((Get-BitLockerVolume -MountPoint "F:").LockStatus -eq "Locked")
  {
     Write-Host "Unlocking drive F:..."
     $pass = ConvertTo-SecureString (Get-Content ~\Documents\Passwords\Bitlocker.txt) -AsPlainText -Force
     Unlock-BitLocker -MountPoint "F:" -Password $pass
  }
}

function global:Get-VSOAuth()
{
  if ($null -eq $global:baseAK)
  {
    $accessToken = (Get-Content ~\Documents\Passwords\VSOToken.txt)
    $global:baseAK = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":$AccessToken"))
  }
  return @{
       Authorization = "Basic $baseAK"
  }
}

function global:Get-WorkItemTitle($workId)
{
  [int]$id = 0;
  try
  {
    $id = [int]::Parse($workId);
  }
  catch
  {
    return $workId;
  }

  if($id -eq 0)
  {
    return ""
  }

  if(!($knownBugs.Contains($id)))
  {
    $url = "https://microsoft.visualstudio.com/_apis/wit/workitems?ids=$id&fields=System.Title&api-version=2.2"
    $definition = Invoke-RestMethod -Uri $url -Headers (Get-VSOAuth)
    $titleField = ($definition.Value.Fields | Select-Object -last 1)
    $title = ($titleField | Get-Member | Select-Object -last 1).Definition.Replace("string System.Title=", "")
    $knownBugs.Add($id, $title)
  }

  return $knownBugs[$id];
}

function global:Get-GitBranchState()
{
  sudo Unlock-MyBitLocker;
  1..4 |ForEach-Object {
    Push-Location f:\os$_\src;
    gvfs mount > $null
    $title = Get-BranchCustomId
    $title = Get-WorkItemTitle($title)
    Write-Host ($_.ToString() + " -> " + $branch + " : " + $title)
    Pop-Location
  }
}

function global:Get-BranchCustomId()
{
    $fastCmd = (get-command Get-GitBranchFast) 2> $null
    if ($null -ne $fastCmd)
    {
      [string]$branch = Get-GitBranchFast
    }
    else
    {
      [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    }
    if ($null -ne $branch)
    {
      return ($branch.Split("/") | Select-Object -last 1)
    }
}

function global:Get-WindowTitleSuffix()
{
    $id = (Get-BranchCustomId)
    return (Get-WorkItemTitle $id)
}

function global:Get-WorkItemIdFromBranch($branch)
{
  return ($branch.Split("/") | Select-Object -last 1)
}

function global:Get-GitBranches()
{
    git branch |% {
       $id = (Get-WorkItemIdFromBranch $_);
       return ($_ + " " + (Get-WorkItemTitle $id))
    }
}

function global:Delete-LocalGitBranches()
{
    git branch | Where-Object { !$_.StartsWith("*") } |% {
      git branch -D $_.SubString(2)
    }
}


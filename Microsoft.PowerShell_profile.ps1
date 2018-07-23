$env:PSModulePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Modules" + ";" + $env:PSModulePath

# Enable theme
Import-Module posh-git
# Import-Module DirColors

# $ThemeSettings.MyThemesLocation = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Themes"
# Set-Theme Paradoxical

# For Emacs / bash like ctrl+{a,e,d,k,r} etc commands
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineOption -BellStyle None
Set-PSReadlineOption -ContinuationPrompt ""

# Produce UTF-8 files by default
$PSDefaultParameterValues["Out-File:Encoding"] = "utf8"

# Show selection menu for tab
Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete
Set-PSReadlineKeyHandler -Key Tab -Function Complete
$ErrorView = "CategoryView"

# Aliases
Set-Alias -Name uru -Value uru_rt
Set-Alias -Name gti -Value git
Remove-Item Alias:curl

# History Management
#######################################################

$MaximumHistoryCount = (32KB - 1)

# Load history
if (Test-Path ~\.PowerShellHistory.csv -PathType Leaf) {
  Import-CSV ~\.PowerShellHistory.csv | Add-History
}

# Save history on exit
Register-EngineEvent PowerShell.Exiting -Action {
  Get-History -Count $MaximumHistoryCount | Export-CSV ~\.PowerShellHistory.csv
} | Out-Null

# omniomi's AdvancedHistory https://www.powershellgallery.com/packages/AdvancedHistory
# Import-Module AdvancedHistory
# Enable-AdvancedHistory 'Ctrl+Shift+R'

# Helper Functions
#######################################################

function uptime {
  Get-WmiObject win32_operatingsystem | Select-Object csname, @{LABEL = 'LastBootUpTime';
    EXPRESSION = {$_.ConverttoDateTime($_.lastbootuptime)}
  }
}

function reload-powershell-profile {
  & $profile
}

function Find-File($name) {
  Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
    $place_path = $_.directory
    Write-Output "${place_path}\${_}"
  }
}

function Get-Path {
  ($Env:Path).Split(";")
}

# Native PS5 New-Symlink cmdlet (unlike mklink) still requires elevated permissions
# As of FCU (version 1709 build 16299.19) so fudge a workaround
#function New-Symlink($link, $target) {
#    if ( Test-Path $target -PathType container ) {
#        & "cmd.exe" /C mklink /D $link $target
#    } else {
#        & "cmd.exe" /C mklink $link $target
#    }
#}

# https://blogs.msdn.microsoft.com/commandline/2017/07/28/how-to-determine-what-just-ran-on-windows-console/
# Needs to run in admin console
function Show-ProcessCreation {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [string] $ProcessName = "conhost",

    [Parameter(Position = 1)]
    [int] $Results = 15
  )

  Get-WinEvent Security | Where-Object id -eq 4688 | Where-Object { $_.Properties[5].Value -match $ProcessName } | Select-Object TimeCreated, @{ Label = "ParentProcess"; Expression = { $_.Properties[13].Value } } | Select-Object -First $Results
}

# MIT Kerberos Helpers - nothing exciting but keeps
# $env:PATH shorter, keep hitting the limit
#######################################################
function New-KerberosTicket($principal) {
  if (!$princial -and $env:KRB5_DEFAULT_PRINCIPAL) {
    $principal = $env:KRB5_DEFAULT_PRINCIPAL
  }

  & "C:\\Program Files\\MIT\\Kerberos\\bin\\kinit.exe" -f -p -r 36000 $principal
}

function Show-KerberosTickets {
  & "C:\\Program Files\\MIT\\Kerberos\\bin\\klist.exe"
}


function Remove-KerberosTickets {
  & "C:\\Program Files\\MIT\\Kerberos\\bin\\kdestroy.exe"
}


# Git aliases
#######################################################

function Git-CheckStatus {
  git status -s
}
Set-Alias gs Git-CheckStatus

function Git-Clone {
  param([string]$repository = "", [string]$folder = "")

  git clone $repository
  cd $folder
  git submodule update --init
}
Set-Alias gcl Git-Clone

function Git-CheckoutRemote {
  param([string]$branch = "")
  git checkout -b $branch --track origin/$branch
}
Set-Alias grb Git-CheckoutRemote


# Other Aliases
#######################################################

# Toggles docker command between Linux and Windows containers
function Switch-DockerDaemon {
  & 'C:\Program Files\Docker\Docker\DockerCli.exe' -SwitchDaemon
}


# Unixlike commands
#######################################################

function df {
  Get-Volume
}

function head($file, $lines = 10) {
  Get-Content $file -head $lines
}

function tail($file, $lines = 10) {
  Get-Content $file -tail $lines
}


function Sed($file, $find, $replace) {
  (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function Sed-Recursive($filePattern, $find, $replace) {
  $files = Get-ChildItem . "$filePattern" -rec
  foreach ($file in $files) {
    (Get-Content $file.PSPath) |
      ForEach-Object { $_ -replace "$find", "$replace" } |
      Set-Content $file.PSPath
  }
}

function grep($regex, $dir) {
  if ( $dir ) {
    Get-ChildItem $dir | Select-String $regex
    return
  }
  $input | Select-String $regex
}

function grepv($regex) {
  $input | Where-Object { !$_.Contains($regex) }
}

function which($name) {
  Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
  Set-Item -force -path "env:$name" -value $value;
}

function pkill($name) {
  Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
  Get-Process $name
}

function touch($file) {
  "" | Out-File $file
}

# From https://github.com/keithbloom/powershell-profile/blob/master/Microsoft.PowerShell_profile.ps1
function sudo {
  $file, [string]$arguments = $args;
  $file = which $file -ErrorAction $file
  $psi = New-Object System.Diagnostics.ProcessStartInfo $file;
  $psi.Arguments = $arguments;
  $psi.Verb = "runas";
  $psi.WorkingDirectory = get-location;
  [System.Diagnostics.Process]::Start($psi) >> $null
}

# https://gist.github.com/aroben/5542538
function pstree {
  $ProcessesById = @{}
  foreach ($Process in (Get-WMIObject -Class Win32_Process)) {
    $ProcessesById[$Process.ProcessId] = $Process
  }

  $ProcessesWithoutParents = @()
  $ProcessesByParent = @{}
  foreach ($Pair in $ProcessesById.GetEnumerator()) {
    $Process = $Pair.Value

    if (($Process.ParentProcessId -eq 0) -or !$ProcessesById.ContainsKey($Process.ParentProcessId)) {
      $ProcessesWithoutParents += $Process
      continue
    }

    if (!$ProcessesByParent.ContainsKey($Process.ParentProcessId)) {
      $ProcessesByParent[$Process.ParentProcessId] = @()
    }
    $Siblings = $ProcessesByParent[$Process.ParentProcessId]
    $Siblings += $Process
    $ProcessesByParent[$Process.ParentProcessId] = $Siblings
  }

  function Show-ProcessTree([UInt32]$ProcessId, $IndentLevel) {
    $Process = $ProcessesById[$ProcessId]
    $Indent = " " * $IndentLevel
    if ($Process.CommandLine) {
      $Description = $Process.CommandLine
    }
    else {
      $Description = $Process.Caption
    }

    Write-Output ("{0,6}{1} {2}" -f $Process.ProcessId, $Indent, $Description)
    foreach ($Child in ($ProcessesByParent[$ProcessId] | Sort-Object CreationDate)) {
      Show-ProcessTree $Child.ProcessId ($IndentLevel + 4)
    }
  }

  Write-Output ("{0,6} {1}" -f "PID", "Command Line")
  Write-Output ("{0,6} {1}" -f "---", "------------")

  foreach ($Process in ($ProcessesWithoutParents | Sort-Object CreationDate)) {
    Show-ProcessTree $Process.ProcessId 0
  }
}

function unzip ($file) {
  $dirname = (Get-Item $file).Basename
  Write-Output ("Extracting", $file, "to", $dirname)
  New-Item -Force -ItemType directory -Path $dirname
  Expand-Archive $file -OutputPath $dirname -ShowProgress
}

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

Function Install-Application($Url, $flags) {
    $LocalTempDir = $env:TEMP
    $Installer = "Installer.exe"
    (new-object  System.Net.WebClient).DownloadFile($Url, "$LocalTempDir\$Installer")
    & "$LocalTempDir\$Installer" $flags
    $Process2Monitor = "Installer"
    Do {
        $ProcessesFound = Get-Process | ? { $Process2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name
        If ($ProcessesFound) { Write-Host "." -NoNewline -ForegroundColor Yellow; Start-Sleep -Seconds 2 } 
        else { Write-Host "Done" -ForegroundColor Cyan; rm "$LocalTempDir\$Installer" -ErrorAction SilentlyContinue }
    } 
    Until (!$ProcessesFound)
}

function Get-ClassFiles {
    $PurpleTeamPath = "$env:USERPROFILE\PurpleTeaming"
    if (Test-Path $PurpleTeamPath) { Remove-Item -Path $PurpleTeamPath -Recurse -Force -ErrorAction Stop | Out-Null }
    New-Item -ItemType directory -Path $PurpleTeamPath | Out-Null
    $url = "https://github.com/clr2of8/PurpleTeaming/archive/refs/heads/main.zip"
    $path = Join-Path $PurpleTeamPath "$main.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $url -OutFile $path
    expand-archive -LiteralPath $path -DestinationPath "$PurpleTeamPath" -Force:$Force
    $mainFolderUnzipped = Join-Path  $PurpleTeamPath "PurpleTeaming-main"
    Get-ChildItem -Path $mainFolderUnzipped -Recurse | Move-Item -Destination $PurpleTeamPath
    Remove-Item $mainFolderUnzipped -Recurse -Force
    Remove-Item $path -Recurse
}

function Set-Bookmarks {
    $bookmarksFile = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    if (-Not (Test-Path $bookmarksFile)) {
        Invoke-WebRequest "https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/Bookmarks" -OutFile "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    }
    Invoke-WebRequest "https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/Bookmarks" -OutFile "$env:Temp\Bookmarks"

    # only update the bookmark file and restart Chrome if there was a change
    if ((Get-Content $bookmarksFile -raw) -ne (Get-Content "$env:Temp\Bookmarks" -raw)) {
        $newJsonData | Set-Content $bookmarksFile
        Stop-Process -Name "chrome" -Force
    } 
}
    
# install Chrome (must be admin)
$property = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction Ignore
if ( -not ($property -and $property.'(Default)')) {
    Write-Host "Installing Chrome" -ForegroundColor Cyan
    $flags = '/silent', '/install'
    Install-Application 'http://dl.google.com/chrome/install/375.126/chrome_installer.exe' $flags
}

Remove-Item "$env:USERPROFILE\Desktop\Microsoft Edge.lnk" -ErrorAction Ignore
# Add Class Timer module
new-item -Type Directory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Timer" -ErrorAction ignore | out-null
Invoke-WebRequest https://raw.githubusercontent.com/clr2of8/PowerShellForInfoSec/refs/heads/main/Tools/Timer.psm1 -OutFile "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Timer\Timer.psm1" -ErrorAction ignore | out-null

# Installing Chrome Bookmarks
start-process chrome; sleep 3 # must start chrome before bookmarks file exists
Stop-Process -Name "chrome" -Force
Write-Host "Installing Chrome Bookmarks" -ForegroundColor Cyan
Set-Bookmarks
Stop-Process -Name "chrome" -Force

# install Notepad++
if (-not (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*  | where-Object DisplayName -like 'NotePad++*')) {
    Write-Host "Installing Notepad++" -ForegroundColor Cyan
    Install-Application 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.5/npp.8.5.Installer.x64.exe' '/S'
}

# add Desktop shortcuts
Write-Host "Creating Desktop Shortcuts" -ForegroundColor Cyan
Copy-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" "$env:USERPROFILE\Desktop\PowerShell.lnk"
Copy-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" "$env:USERPROFILE\Desktop\Command Prompt.lnk"
Copy-Item 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Notepad++.lnk' "$env:USERPROFILE\Desktop\Notepad++.lnk"

Write-Host "Writing class files to $env:USERPROFILE\PurpleTeaming" -ForegroundColor Cyan
Get-ClassFiles 

# Turn off Automatic Sample Submission in Windows Defender
Write-Host "Turning off Automatic Sample Submission" -ForegroundColor Cyan
PowerShell Set-MpPreference -SubmitSamplesConsent 2

# Turn off screensaver and screen lock features for convenience
Powercfg /Change -monitor-timeout-ac 0
Powercfg /Change -standby-timeout-ac 0

# ToDo: add timer powershell module

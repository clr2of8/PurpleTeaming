function Purple-Redeploy {
    IEX (IWR "https://raw.githubusercontent.com/clr2of8/PurpleTeaming/refs/heads/main/Tools/windows-vm-setup.ps1" -UseBasicParsing)
}

function Purple-InstallVSCode {
    Write-Host "Installing VSCode" -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -Force
    Install-Script -Name Install-VSCode -Force
    Install-VSCode
}

function Purple-PatchCaldera {
    Install-Module -Name Posh-SSH -Force -ErrorAction Ignore
    $password = ConvertTo-SecureString "metarange" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("ubuntu", $password)
    Get-SSHSession | Remove-SSHSession
    $sess = New-SSHSession -ComputerName linux.cloudlab.lan -Credential $cred -Force
    $commands = @(
        "sudo kill -9 `$(sudo lsof -t -i :8888)",
        "sed -i -r ""s/app.frontend.api_base_url: .*$/app.frontend.api_base_url: http:\/\/linux.cloudlab.lan:8888/g"" ~/caldera/conf/local.yml",
        "sed -i -r ""s/app.contact.http: .*$/app.contact.http: http:\/\/linux.cloudlab.lan:8888/g"" ~/caldera/conf/local.yml",
        "cd ~/caldera; .venv//bin//python3 server.py --build",
        "sudo kill -9 `$(sudo lsof -t -i :8888)"
    )
    foreach ($command in $commands) {
        invoke-sshcommand -SSHSession $sess -Command $command -ShowStandardOutputStream -ShowErrorOutputStream -TimeOut 300
    }
    $sess | Remove-SSHSession
}

function Purple-InstallAtomicRedTeam {
    Add-MpPreference -ExclusionPath C:\AtomicRedTeam\
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing);
    Install-AtomicRedTeam -getAtomics
    add-content $profile "Import-Module C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1 -Force"
}

function Purple-InstallMACAT {
    Set-MpPreference -DisableRealtimeMonitoring $true
    Add-MpPreference -ExclusionPath "C:\MACAT\"
    
    # Try to find the latest version by checking common version patterns
    Write-Host "Finding latest MACAT version..." -ForegroundColor Cyan
    
    # Common version patterns to try (you can add more as new versions are released)
    $versionPatterns = @(
        "0.2.3", "0.2.2", "0.2.1", "0.2.0",
        "0.1.9", "0.1.8", "0.1.7", "0.1.6"
    )
    
    $latestMsiUrl = $null
    $fileName = $null
    
    foreach ($version in $versionPatterns) {
        $testUrl = "https://macat.io/download/files/MACAT_$version`_x64_en-US.msi"
        Write-Host "Testing URL: $testUrl" -ForegroundColor Gray
        
        try {
            $response = Invoke-WebRequest -Uri $testUrl -Method Head -UseBasicParsing -TimeoutSec 10
            if ($response.StatusCode -eq 200) {
                $latestMsiUrl = $testUrl
                $fileName = "MACAT_$version`_x64_en-US.msi"
                Write-Host "Found latest version: $fileName" -ForegroundColor Green
                break
            }
        }
        catch {
            # URL doesn't exist, try next version
            continue
        }
    }
    
    if (-not $latestMsiUrl) {
        Write-Error "Could not find any available MACAT version. Please check the downloads page manually."
        return
    }
    
    $msi = "$env:USERPROFILE\Downloads\$fileName"
    
    if (-not (test-path $msi)) {
        Write-Host "Downloading $fileName..." -ForegroundColor Cyan
        Invoke-WebRequest $latestMsiUrl -OutFile $msi
        Write-Host "Download completed: $msi" -ForegroundColor Green
    } else {
        Write-Host "File already exists: $msi" -ForegroundColor Yellow
    }
    
    # Install the MSI
    Write-Host "Installing MACAT..." -ForegroundColor Cyan
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" "
    Write-Host "MACAT installation completed!" -ForegroundColor Green
}



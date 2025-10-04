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

function Purple-GetLinuxVMIP {
    Write-Host "Determining Linux VM IP address..." -ForegroundColor Cyan
    
    try {
        # Use Test-NetConnection to resolve hostname and get IP address
        $testResult = Test-NetConnection "ubuntu.local" -Port 22 -WarningAction SilentlyContinue
        
        if ($testResult.PingSucceeded) {
            Write-Host "VM is reachable!" -ForegroundColor Green
            
            # Extract IPv4 address from the test result
            # The IPv4 address appears in the warning messages
            $ipv4Address = $null
            
            # Try to get IPv4 from the RemoteAddress if it's IPv4
            if ($testResult.RemoteAddress -and $testResult.RemoteAddress -notlike "*:*") {
                $ipv4Address = $testResult.RemoteAddress
            } else {
                # Parse IPv4 from warning messages or use a more direct approach
                $dnsResult = [System.Net.Dns]::GetHostAddresses("ubuntu.local")
                $ipv4Address = ($dnsResult | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1).IPAddressToString
            }
            
            if ($ipv4Address) {
                Write-Host "Linux VM IPv4 address: $ipv4Address" -ForegroundColor Green
                Write-Host "Hostname: ubuntu.local" -ForegroundColor Yellow
                Write-Host "Network interface: $($testResult.InterfaceAlias)" -ForegroundColor Yellow
                Write-Host "Ping RTT: $($testResult.PingReplyDetails.RoundtripTime) ms" -ForegroundColor Yellow
                
                # Test SSH connectivity
                if ($testResult.TcpTestSucceeded) {
                    Write-Host "SSH port 22 is open" -ForegroundColor Green
                } else {
                    Write-Host "SSH port 22 is not responding" -ForegroundColor Yellow
                }
                
                return $ipv4Address
            } else {
                Write-Warning "Could not determine IPv4 address"
                return $null
            }
        } else {
            Write-Error "VM is not reachable via ping"
            return $null
        }
    }
    catch {
        Write-Error "Failed to determine VM IP address: $($_.Exception.Message)"
        return $null
    }
}

function Purple-AddLinuxVMHostsEntry {
    Write-Host "Adding Linux VM entry to Windows hosts file..." -ForegroundColor Cyan
    
    # Get the Linux VM IP address
    $vmIP = Purple-GetLinuxVMIP
    
    if (-not $vmIP) {
        Write-Error "Could not determine Linux VM IP address"
        return
    }
    
    # Define the hosts file path
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostname = "linux.cloudlab.lan"
    
    try {
        # Check if the entry already exists
        $hostsContent = Get-Content $hostsFile -ErrorAction Stop
        $existingEntry = $hostsContent | Where-Object { $_ -match "linux\.cloudlab\.lan" }
        
        if ($existingEntry) {
            Write-Host "Hosts entry already exists: $existingEntry" -ForegroundColor Yellow
            
            # Check if the IP matches
            if ($existingEntry -match $vmIP) {
                Write-Host "IP address is already correct: $vmIP" -ForegroundColor Green
                return
            } else {
                Write-Host "Updating existing entry with new IP: $vmIP" -ForegroundColor Yellow
                # Remove the old entry
                $hostsContent = $hostsContent | Where-Object { $_ -notmatch "linux\.cloudlab\.lan" }
            }
        }
        
        # Add the new entry
        $newEntry = "$vmIP`t$hostname"
        $hostsContent += $newEntry
        
        # Write the updated content back to the hosts file
        $hostsContent | Set-Content $hostsFile -Encoding ASCII
        
        Write-Host "Successfully added hosts entry: $newEntry" -ForegroundColor Green
        Write-Host "You can now use 'linux.cloudlab.lan' to access the VM" -ForegroundColor Green
        
        # Test the new entry
        Write-Host "Testing hostname resolution..." -ForegroundColor Cyan
        $testResult = Test-NetConnection "linux.cloudlab.lan" -Port 22 -WarningAction SilentlyContinue
        
        if ($testResult.PingSucceeded) {
            Write-Host "Hostname 'linux.cloudlab.lan' resolves successfully!" -ForegroundColor Green
        } else {
            Write-Warning "Hostname resolution test failed"
        }
    }
    catch {
        Write-Error "Failed to update hosts file: $($_.Exception.Message)"
        Write-Host "You may need to run PowerShell as Administrator to modify the hosts file" -ForegroundColor Yellow
    }
}



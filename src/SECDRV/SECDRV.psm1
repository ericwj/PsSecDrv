class SecDrvConstants {
	static [string]$DriverName = "SECDRV"
	static [string]$SdkPortalTitle = "Windows Dev Center"
	static [string]$SdkPortalUrl = "https://dev.windows.com/en-us/downloads"
	static [string]$SdkTitle = "Windows Standalone SDK for Windows 10"
	static [string]$SdkUrl = "https://go.microsoft.com/fwlink/p/?LinkId=619296"
	static [string]$VerisignTimestampServerUrl = "http://timestamp.verisign.com/scripts/timstamp.dll"
	# Only the last option 'Windows Software Development Kit' is neccessary.
	static [string]$SdkSetup = "sdksetup.exe"

    static [string[]]$WindowsUpdateManifest = @(
        "Insider=KB3106638" # Update for Windows 10 Insider Preview: October 21, 2015
        "RTM=KB3105213" # 10/31/2015 Cumulatieve update Windows 10 voor x64-systemen (KB3105210)
    )
    # List the files that a user needs to run all code
    # SECDRV.ps1 is already downloaded, but needs to be downloaded again to the proper folder
	static [string[]]$DownloadManifest = @(
        "SECDRV.ps1",  # Bootstrap Script
		"SECDRV.psd1", # Module Definition
		"SECDRV.psm1", # Module File
		"SECDRV.sys",  # Presigning - Driver File
		"SECDRV.cat",  # Presigning - Signed Driver Catalog
		"SECDRV.cer"   # Presigning - Driver Publisher Certificate
	)
    # List of files needed to run the tools (in the x64 or x86 folder in the SDK)
    static [string[]]$ToolsManifest = @(
         "appxpackaging.dll"
        ,"appxsip.dll"
        ,"makecat.exe"
        ,"makecat.exe.manifest"
        ,"makecert.exe"
        ,"Microsoft.Windows.Build.Appx.AppxPackaging.dll.manifest"
        ,"Microsoft.Windows.Build.Appx.AppxSip.dll.manifest"
        ,"Microsoft.Windows.Build.Appx.OpcServices.dll.manifest"
        ,"Microsoft.Windows.Build.Signing.mssign32.dll.manifest"
        ,"Microsoft.Windows.Build.Signing.wintrust.dll.manifest"
        ,"mssign32.dll"
        ,"opcservices.dll"
        ,"signtool.exe"
        ,"signtool.exe.manifest"
        ,"wintrust.dll"
        ,"wintrust.dll.ini"
    )
    static [hashtable]$PSWindowsUpdateManifest = @{
        ModuleName = "PSWindowsUpdate"
        RequiredVersion = "1.5.1.11"
        #ModuleVersion = "1.5.1.11"
        GUID = "{8ed488ad-7c77-4b33-b06e-32214925163b}"
    }
	
    # Lets align with the ASP.NET way of storing settings we don't want to reside in the code repository
    # https://github.com/aspnet/UserSecrets/blob/dev/src/Microsoft.Extensions.Configuration.UserSecrets/PathHelper.cs
    static [string]GetUserSecretFolder() {
        $Result = $env:APPDATA # Windows only, no conditional stuff
        $Result = Join-Path $Result "Microsoft\UserSecrets\SECDRV"
        return $Result
    }
    # Get settings not checked into the repo - not necessarily secrets so much, but user-system-specific stuff
    static [string]GetUserSecrets() {
        $Path = Join-Path ([SecDrvConstants]::GetUserSecretFolder()) "secrets.json"
        $File = dir $Path -ErrorAction SilentlyContinue
        # Does something exist at $Path?
        if ($File -eq $null) { return $null; }
        # Path exists, but is not a file
        if ($File.Attributes -band [System.IO.FileAttributes]::Directory) { return $null }
        $Text = Get-Content -Path $Path -Encoding UTF8
        # Get-Content -is [Object[]], make it [string]
        $Text = $Text -join "`n" 
        if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
        return $Text
    }

    # Get the Developer path - the path where we may find tools on a specific system
    static [string]GetDevPath() {
        $Text = [SecDrvConstants]::GetUserSecrets()
        $Json = ConvertFrom-Json -InputObject $Text
        if ($Json -eq $null) { return $null }
        return $Json.DevPath # May still be null
    }
}
set-alias ?: Invoke-Ternary -Option AllScope -Description "PowerShell Conditional Operator filter alias"
filter Invoke-Ternary ([scriptblock]$condition, [scriptblock]$yes, [scriptblock]$no) 
{ if (&$condition) { &$yes } else { &$no } }

function Read-String([string]$Prompt, [string]$Default, [scriptblock]$Validator, [string]$RegexPattern, [string]$ErrorMessage) {
    while ($true) {
        $PromptString = $Prompt
        if ($Default -ne $null -and $Default -ne "") { $PromptString = "$Prompt [Default = $Default]" }
        $Value = Read-Host -Prompt $PromptString
        if ($Value -eq "") { $Value = $Default }
        if ($RegexPattern -ne $null) { $Validator = { ([regex]$RegexPattern).IsMatch($args[0]) } }
        if ($Validator -eq $null) { break; }
        if ([bool]$Validator.Invoke($Value)) { break; }
        if ($ErrorMessage -ne $null) { Write-Host $ErrorMessage }
        Write-Host "The string entered was not allowed, or the validator threw an exception."
    }
    return $Value
}
class ChoiceItem {
    ChoiceItem([string]$Label, [string]$HelpText, [object]$Value) {
        $this.Label = $Label
        $this.HelpText = $HelpText
        $this.Choice = [ChoiceItem]::Build($Label, $HelpText)
        $this.Value = $Value
    }
    [string]$Label
    [string]$HelpText
    [object]$Value
    [System.Management.Automation.Host.ChoiceDescription]$Choice
    static [System.Management.Automation.Host.ChoiceDescription] Build([string]$Label, [string]$HelpText) {
        if ($Label -eq $null) {
            throw "A label is required."
        }
        if ($HelpText -eq $null) {
            return [System.Management.Automation.Host.ChoiceDescription]::new($Label)
        } else {
            return [System.Management.Automation.Host.ChoiceDescription]::new($Label, $HelpText)
        }
    }
}
class ChoiceDialog {
    ChoiceDialog([object]$Default, [string]$Caption, [string]$Message, [object[]]$Choices) {
        $this.Caption = $Caption
        $list = [System.Collections.Generic.LinkedList[Tuple[string,string, object]]]::new()
        $Choices | foreach { $list.Add([tuple]::Create([string]$_.Item1, [string]$_.Item2, [object]$_.Item3)) }
        $this.Choices = $list | foreach { [ChoiceItem]::new($_.Item1, $_.Item2, $_.Item3) }
        $this.Default = $Default
        $this.Message = $Message
        $this.Choice = $Default
    }
    [object]$Default
    [string]$Caption
    [string]$Message
    [ChoiceItem[]]$Choices
    [object]$Choice
    [object] Show() {
        trap { Write-Host (Get-Variable -Name Error -ValueOnly -Scope Global) }
        $cd = [System.Collections.Generic.List[System.Management.Automation.Host.ChoiceDescription]]::new()
        $this.Choices | foreach { $cd.Add($_.Choice) }
        $h = Get-Variable -Name Host -ValueOnly -Scope Global
        $e = Get-Variable -Name Error -ValueOnly -Scope Global
        $e.Clear()
        try {
            $d = -1
            for ($i = 0; $i -lt $this.Choices.Count; $i++) {
                if ($this.Default -eq $this.Choices[$i].Value) {
                    $d = $i
                    break;
                }
            }
            $n = $h.UI.PromptForChoice($this.Caption, $this.Message, $cd.ToArray(), $d)
            $this.Choice = ?: { $n -lt 0 } { $null } { $this.Choices[$n].Value }
        } catch {
            Write-Host $e -ForegroundColor Red
            throw
        }
        return $this.Choice
    }
    static [bool] Is([object]$a, [object]$b) {
        return [object]::Equals($a, $b)
    }
}
function Invoke-CommandLine {
    [CmdLetBinding()]
    param(
        [String]$Command,
        [Object[]]$Arguments,
        [Switch]$Echo,
        [Switch]$WhatIf
    )
    Process {
        if ($WhatIf.IsPresent) {
            Write-Host "What If: Invoke-CommandLine $Command $Arguments"
            $Output = "What If: Invoke-CommandLine $Command $Arguments"
            $ExitCode = 0
        } elseif ($Echo.IsPresent) {
            Tee-Object -InputObject (& $Command $Arguments) -Variable Output
            $ExitCode = $LASTEXITCODE
        } else {
            $Output = & $Command $Arguments
            if ($Verbose.IsPresent) {
                Write-Verbose $Output
            }
            $ExitCode = $LASTEXITCODE
        }
        return @{ Output = $Output; ExitCode = $ExitCode }
    }
}
# We need to run Windows update, since clean install produces ACCESS_VIOLATION in Export-PfxCertificate
# And we need to 1) Uninstall and 2) Disable KB3086255 (https://support.microsoft.com/en-us/kb/3086255)
function Install-SecDrvWindowsUpdates {
    $NuGet = Get-PackageProvider -Name NuGet -ForceBootstrap 
    
    $PswuSpec = [SecDrvConstants]::PSWindowsUpdateManifest
    $PswuFqn = [Microsoft.PowerShell.Commands.ModuleSpecification]::new($PswuSpec)
    $Pswu = Get-Module -FullyQualifiedName $PswuFqn -ListAvailable
    if ($Pswu -eq $null) {
        Install-Package -Name ($PswuSpec.ModuleName) -ProviderName PSModule -ForceBootstrap -RequiredVersion ($PswuSpec.RequiredVersion) -Confirm:$false -Force
        $Pswu = Get-Module -FullyQualifiedName $PswuFqn -ListAvailable
        if ($Pswu -eq $null) {
            throw "The required package PSWindowsUpdate could not be obtained. This may be due to connectivity problems, or a version conflict. Try again later."
        }
        Import-Module -FullyQualifiedName $PswuFqn
    }
    $ready = ((Get-WUInstallerStatus) -match "ready") # text :(
    Write-Warning "Searching Windows Update"
    $updates = Get-WUInstall -ListOnly
    $dlsize = ($updates | measure MaxDownloadSize).Sum / 1MB
    if ($updates.Count -gt 0) {
        Write-Warning "Downloading $($updates.Count) updates ($("{0:N1}" -f $dlsize)MB)"
        $ignore = Get-WUInstall -DownloadOnly -AcceptAll
        Write-Warning "Installing updates..."
        Get-WUInstall -IgnoreUserInput -AcceptAll -IgnoreReboot 1>4 3>4 # Success and Warnings as Verbose
    }
    $ready = ((Get-WUInstallerStatus) -match "ready")
    $status = Get-WURebootStatus -Silent    
    return !$status
}

function Find-SecDrvToolsPath {
    [CmdLetBinding()]
    param(
        [String]$Hint,
        [String]$DevPath,
        [String]$Sentinel = "makecert.exe"
    )
    Process {
        $WindowsSdkPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
        $HasToolsPath = ![string]::IsNullOrWhiteSpace($Hint)
        $HasDevPath = ![string]::IsNullOrWhiteSpace($DevPath)

        if ($HasToolsPath -and (Test-Path $Hint)) {
            $RootFolder = $Hint
        } elseif ($HasDevPath -and (Test-Path $DevPath)) {
            $RootFolder = $DevPath
        } elseif (Test-Path $WindowsSdkPath) {
            $RootFolder = $WindowsSdkPath
        } else {
            $message = 
                "A directory containing the tools does not exist. " +
                "You must specify a path as a hint, or an actual path to the required executables."
            throw [System.ArgumentNullException]::new($message)
        }

        $Joined = Join-Path $RootFolder $Sentinel
        if (Test-Path $Joined) {
            return $RootFolder
        }

        $ProcessorArchitecture = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE", [System.EnvironmentVariableTarget]::Machine)
        if ([System.Environment]::Is64BitOperatingSystem -ne [System.Environment]::Is64BitProcess) {
            $Bitness = 32
            if ([System.Environment]::Is64BitOperatingSystem) { $Bitness = 64 }
            throw [System.NotSupportedException]::new(
                "Your operating system and the current PowerShell host process are not the same bitness. " +
                "You may be running 'PowerShell ISE (x86)' on a 64-bit operating system - start 'PowerShell ISE' instead. " +
                "Restart PowerShell using the $Bitness-bit version.")
        }
        if ([System.Environment]::Is64BitOperatingSystem) {
            if ($ProcessorArchitecture -eq "AMD64") { 
                $ToolsPath = Join-Path $RootFolder "x64"
            } else {
                throw [System.NotSupportedException]::new(
                    "Processor architecture $ProcessorArchitecture is not supported. This script only supports 64-bit Intel architecture (AMD64).")
            }
        } else {
            if ($ProcessorArchitecture -eq "x86") { 
                $ToolsPath = Join-Path $RootFolder "x86"
            } else {
                throw [System.NotSupportedException]::new(
                    "Processor architecture $ProcessorArchitecture is not supported. This script only supports 32-bit Intel architecture (x86).")
            }
        }

        $Joined = Join-Path $ToolsPath $Sentinel
        if (Test-Path $Joined) {
            return $ToolsPath
        } else {
            $message = "Could not find the tools under folder '$RootFolder'. '$Joined' not found."
            throw [System.IO.FileNotFoundException]::new($message, $Joined)
        }
    }
}
function Approve-SecDrvToolsPath {
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory = $true)][String]$Path
    )
    Process {
        $Manifest = [SecDrvConstants]::ToolsManifest
        foreach ($file in $Manifest) {
            $FullPath = Join-Path $Path $file
            $OK = $false
            while ($true) {
                if (!(Test-Path $FullPath)) { break; }
                $FileInfo = dir $FullPath -ErrorAction SilentlyContinue
                if ($FileInfo -eq $null) { break; }
                if ($FileInfo.Attributes -band [System.IO.FileAttributes]::Directory) { break; }
                $OK = $true
                break;
            }
            if ($OK -eq $false) {
                throw [System.IO.FileNotFoundException]::new("A required file is missing: $file", $FullPath)            
            }
        }
        return $true
    }
}
function Test-SecDrvWindowsSdk {
    [CmdLetBinding()]
    param(
    )
    Process {
        $WindowsSdk = Get-Package -ProviderName msi -MinimumVersion 10.0.26624 | where Source -Match 89CA32DC-2323-27B2-A388-54373DA1A492
        return $WindowsSdk -ne $null
    }
}
enum SecDrvPrompt {
    Yes
    No
}
<#
sdksetup /?

sdksetup /list
Windows Software Development Kit - Windows 10.0.26624
Available features: (Features marked with * can be downloaded but cannot be installed on this computer)   OptionId.WindowsPerformanceToolkit   OptionId.WindowsDesktopDebuggers   OptionId.AvrfExternal   OptionId.NetFxSoftwareDevelopmentKit   OptionId.WindowsSoftwareLogoToolkit   OptionId.MSIInstallTools   OptionId.WindowsSoftwareDevelopmentKitUse Ctrl+C to copy this information to the Clipboard.


#>
enum SecDrvWindowsSdkInstallAction {
    Install
    Uninstall
    Repair
}
function Install-SecDrvWindowsSdk {
    [CmdLetBinding()]
    param(
        [Parameter()][String]$LogPath,
        [Parameter()][String]$AllowRestart, # If specified, will not use /norestart
        #[Parameter()][Switch]$Verbose,      # If specified, will not use /quiet # Install-SecDrvWindowsSdk : A parameter with the name 'Verbose' was defined multiple times for the command.
        [Parameter()][Switch]$Ceip,
        [Parameter()][Timespan]$Timeout = [TimeSpan]::FromMinutes(20),    # How long to wait for setup to complete -- pretty long for slow computers
        [Parameter()][Switch]$Confirm
    )
    Process {
        Run-SecDrvWindowsSdkInstaller -InstallAction:$([SecDrvWindowsSdkInstallAction]::Install) -AllowRestart:$AllowRestart -Ceip:$Ceip -Timeout:$Timeout `
            -LogPath:$LogPath -Verbose:($Verbose.IsPresent) -Confirm:($Confirm.IsPresent) # -WhatIf:$($WhatIf.IsPresent)
    }
}
function Uninstall-SecDrvWindowsSdk {
    [CmdLetBinding()]
    param(
        [Parameter()][String]$LogPath,
        [Parameter()][String]$AllowRestart, # If specified, will not use /norestart
        #[Parameter()][Switch]$Verbose,      # If specified, will not use /quiet # Install-SecDrvWindowsSdk : A parameter with the name 'Verbose' was defined multiple times for the command.
        [Parameter()][Switch]$Ceip,
        [Parameter()][Timespan]$Timeout = [TimeSpan]::FromMinutes(20),    # How long to wait for setup to complete -- pretty long for slow computers
        [Parameter()][Switch]$Confirm
    )
    Process {
        Run-SecDrvWindowsSdkInstaller -InstallAction:$([SecDrvWindowsSdkInstallAction]::Uninstall) -AllowRestart:$AllowRestart -Ceip:$Ceip -Timeout:$Timeout `
            -LogPath:$LogPath -Verbose:($Verbose.IsPresent) -Confirm:($Confirm.IsPresent) # -WhatIf:$($WhatIf.IsPresent)
    }
}
function Repair-SecDrvWindowsSdk {
    [CmdLetBinding()]
    param(
        [Parameter()][String]$LogPath,
        [Parameter()][String]$AllowRestart, # If specified, will not use /norestart
        #[Parameter()][Switch]$Verbose,      # If specified, will not use /quiet # Install-SecDrvWindowsSdk : A parameter with the name 'Verbose' was defined multiple times for the command.
        [Parameter()][Switch]$Ceip,
        [Parameter()][Timespan]$Timeout = [TimeSpan]::FromMinutes(20),    # How long to wait for setup to complete -- pretty long for slow computers
        [Parameter()][Switch]$Confirm
    )
    Process {
        Run-SecDrvWindowsSdkInstaller -InstallAction:$([SecDrvWindowsSdkInstallAction]::Repair) -AllowRestart:$AllowRestart -Ceip:$Ceip -Timeout:$Timeout `
            -LogPath:$LogPath -Verbose:($Verbose.IsPresent) -Confirm:($Confirm.IsPresent) # -WhatIf:$($WhatIf.IsPresent)
    }
}
function Run-SecDrvWindowsSdkInstaller {
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory = $true)][SecDrvWindowsSdkInstallAction]$InstallAction,
        [Parameter()][String]$LogPath,
        [Parameter()][String]$AllowRestart, # If specified, will not use /norestart
        #[Parameter()][Switch]$Verbose,      # If specified, will not use /quiet # Install-SecDrvWindowsSdk : A parameter with the name 'Verbose' was defined multiple times for the command.
        [Parameter()][Switch]$Ceip,
        [Parameter()][Timespan]$Timeout,    # How long to wait for setup to complete -- pretty long for slow computers
        [Parameter()][Switch]$Confirm
    )
    Process {
        $Lowercase = $InstallAction.ToString().ToLower()
        if ($Confirm.IsPresent) {
            $InstallPrompt = [ChoiceDialog]::new([SecDrvPrompt]::Yes, "$($InstallAction)?", "Do you want to $Lowercase $([SecDrvConstants]::SdkTitle) now?", @(
                [tuple]::Create("&Yes", "$InstallAction $([SecDrvConstants]::SdkTitle).", [SecDrvPrompt]::Yes),
                [tuple]::Create("&No", "Skip $InstallAction of $([SecDrvConstants]::SdkTitle).", [SecDrvPrompt]::No)
            ))
            $InstallAnswer = $InstallPrompt.Show()
            if ($InstallAnswer -eq [SecDrvPrompt]::No) { return }
        }
        
        Write-Host "The $([SecDrvConstants]::SdkTitle) will be downloaded from $([SecDrvConstants]::SdkPortalTitle) and then launched." 
        $TempFile = Join-Path $env:TEMP $([SecDrvConstants]::SdkSetup)
        $Uri = [SecDrvConstants]::SdkUrl
        Write-Verbose "Downloading $Uri => $TempFile" 
        curl -Uri $Uri -OutFile $TempFile

        Write-Host "$([SecDrvConstants]::SdkTitle) Setup will now start. Please wait..."
        $Arguments = @()
        try {
            switch ($InstallAction) {
                ([SecDrvWindowsSdkInstallAction]::Install) { $Arguments += @("/features OptionId.WindowsSoftwareDevelopmentKit") }
                ([SecDrvWindowsSdkInstallAction]::Repair) { $Arguments += @("/repair") }
                ([SecDrvWindowsSdkInstallAction]::Uninstall) { $Arguments += @("/features OptionId.WindowsSoftwareDevelopmentKit /uninstall") }
                default {
                    throw [System.NotSupportedException]::new("The setup action '$InstallAction' is not supported.")
                }
            }
            if ($AllowRestart) {
                $Arguments += @("/forcerestart") # Can't use promptrestart in PowerShell
            } else {
                $Arguments += @("/norestart")
            }
            if (-not $Verbose.IsPresent) {
                $Arguments += @("/quiet")
            }
            if ($Ceip.IsPresent) {
                $Arguments += @("/ceip on")
            } else {
                $Arguments += @("/ceip off")
            }
            if ([string]::IsNullOrWhiteSpace($LogPath) -eq $false) {                
                $Arguments += @("/log $LogPath")
            }  
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = $TempFile
            $psi.Arguments = $Arguments -join " "
            Write-Verbose "Executing $($psi.FileName) $($psi.Arguments)"
            $process = [System.Diagnostics.Process]::Start($psi)
            $Start = [System.DateTimeOffset]::Now
            $End = $Start + $Timeout
            $ProgressID = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
            
            $ProcentComplete = [System.Collections.Generic.Dictionary[double,double]]::new()
            $max = [int]::MaxValue
            $cfg = @(
                @{ Seconds =   0; Procent =  0; Step =        0 },
                @{ Seconds = 180; Procent = 75; Step = (180/75) },
                @{ Seconds = 360; Procent = 20; Step = (360/20) },
                @{ Seconds = 999; Procent =  5; Step = (999/ 5) }
            )
            $index = 0
            $current = $cfg[0];
            $cumulative = @{ Seconds = 0; Procent = 0; Step = 0 }
            foreach ($i in [System.Linq.Enumerable]::Range(1, 200)) { # $i = 1 $i = 151 $i++
                $p = $i / 2 # base 100%
                if ($p -gt ($cumulative.Procent + $current.Procent)) { # $cumulative; $current
                    $cumulative.Seconds += $current.Seconds
                    $cumulative.Procent += $current.Procent
                    $cumulative.Step = $p
                    $index++; 
                    $current = $cfg[$index]
                }
                $Seconds = $cumulative.Seconds + ($p - $cumulative.Step) * $current.Step
                try {
                    $ProcentComplete.Add($Seconds, $p)
                } catch {
                    $i;$p;throw
                }
            }

            try {
                while ([System.DateTimeOffset]::Now -lt $End) {
                    $Now = [System.DateTimeOffset]::Now
                    $Elapsed = ($Now - $Start).TotalSeconds
                    $Remaining = ($End - $Now).TotalSeconds
                    $Key = $ProcentComplete.Keys | where {$_ -le $Elapsed} | sort | select -Last 1
                    $Progress = $ProcentComplete[$Key]
                    Write-Debug "Elapsed $Elapsed ($($Elapsed.GetType().Name)) Key: $Key ($($Key.GetType().Name)) Value: $Progress ($($Progress.GetType().Name)) LINQ: $($ProcentComplete.Keys | where {$_ -le $Elapsed} | sort )" 
                    Write-Progress -PercentComplete $Progress -Activity "$InstallAction $([SecDrvConstants]::SdkTitle)" -Status "Running, $($Now - $Start) elapsed." -Id $ProgressID
                    Start-Sleep -Seconds 1
                    if ($process.HasExited) { break; }
                }
                if ($process.ExitCode -eq 0) {
                    Write-Host "Success" -ForegroundColor Green
                } else {
                    Write-Error "Failure. $([SecDrvConstants]::SdkSetup) exited with exit code $($process.ExitCode)"
                }
            } finally {
                Write-Progress -Id $ProgressID -Completed -Activity Done
            }
            if (!$process.HasExited) {
                throw [System.TimeoutException]::new("Timed out waiting for $($process.MainWindowTitle).")
            }
            if ($process.ExitCode -ne 0) {
                Write-Error "Something went wrong. $([SecDrvConstants]::SdkSetup) exited with exit code $($process.ExitCode)." 
            }
            if (Test-RebootRequired) {
                Write-Warning "A reboot is required to finish $Lowercase $([SecDrvConstants]::SdkTitle)" 
            } else {
            }
        } finally {
            del $TempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
# this is silly, there should be a better way - Enable-WindowsOptionalFeature cooks up a value for example
function Test-RebootRequired {
    [CmdletBinding()]
    param()
    Process {
        # http://blogs.technet.com/b/heyscriptingguy/archive/2013/06/11/determine-pending-reboot-status-powershell-style-part-2.aspx
        $cbs = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'
        $RebootPending = ($cbs | Get-Member | where Name -Match RebootPending).Count -gt 0

        $wau = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
        if ($wau -eq $null) { $RebootRequired = $false } else {
            $RebootRequired = ($wau | Get-Member | where Name -Match RebootRequired).Count -gt 0
        }

        $csm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        # is also not null on my system but only files in $env:LocalAppData need renames
        $PendingFileRename = $csm -ne $null -and $csm.PendingFileRenameOperations -ne $null 

        $SplattedWmiInvoke = @{
            NameSpace='ROOT\ccm\ClientSDK'
            Class='CCM_ClientUtilities'
            Name='DetermineIfRebootPending'
            ComputerName="."
            ErrorAction='SilentlyContinue'
        }
        $WmiResult = Invoke-WmiMethod @SplattedWmiInvoke
        if ($WmiResult -eq $null) {
            $WmiSaisRebootPending = $false
        } elseif ($WmiResult.ReturnValue -ne 0) {
            throw "DetermineIfRebootPending failed with return value $($WmiResult.ReturnValue)"
        } else {
            $WmiSaisRebootPending = $WmiResult.IsHardRebootPending -or $WmiResult.IsRebootPending
        }

        return $RebootPending -or $RebootRequired -or $WmiSaisRebootPending #-or $PendingFileRename
    }
}
function Write-Conditional {
    [CmdLetBinding()]
    param(
        [object[]]$Text
    )
    Process {
        if (!$Verbose.IsPresent) {
            Write-Verbose ($Text -join "`n")
        } else {
            Write-Debug ($Text -join "`n")
        }
    }
}
# Install-SecDrv : Unable to find type [System.ServiceProcess.ServiceStartMode]
if ($false) {
    Write-Host "enum SecDrvServiceStartMode {"
    Write-Host "`tAutomatic = $([int][System.ServiceProcess.ServiceStartMode]::Automatic)"
    Write-Host "`tDisabled = $([int][System.ServiceProcess.ServiceStartMode]::Disabled)"
    Write-Host "`tManual = $([int][System.ServiceProcess.ServiceStartMode]::Manual)"
    Write-Host "}"
}
enum SecDrvServiceStartMode {
	Automatic = 2
	Disabled = 4
	Manual = 3
}
<#
    .NOTES
        Copyright (C) Eric Jonker. All rights reserved.

    .SYNOPSIS
        Selectively performs actions necessary to install SECDRV.sys, 
        depending on the switches specified and on the current state
        of the system.

    .DESCRIPTION
        This command is able to perform the actions necessary to install
        SECDRV.sys on a Windows 10 System. This involves the following steps
        - Install the Standalone SDK for Windows 10 (if neccessary)
        - Create a Catalog Definition File (.cdf) - a small text file
        - Generate a Publisher Certificate to digitally sign the driver (.cer)
        - Generate a Driver Catalog (.cat) which contains proof of the use
          of the certificate previously created to sign the exact driver file present.
        - Install the driver file (.sys) and the catalog (.cat) in Windows
        - Configure Windows to trust the certificate used to sign the driver
        - Turn on BOOTSIGNING test mode so the driver can be loaded
        No steps have been taken yet to supress the Windows Update which disables SECDRV.

        The publisher certificate (.cer) that this command creates, the
        catalog definition file (.cdf)  and driver catalog file (.cat) 
        will be created or generated in a folder on your machine and kept private.

        If you do not specify any switches, this will effectively mean
        
        Install-SecDrv -MakeCertificate -SignDriver -InstallDriver -SetBootSigningOn

        If you do not specify -ToolsPath and the Standalone SDK for Windows  10 
        is not isntalled, the script will silently install the
        Windows Standalone SDK for Windows 10 from Windows Dev Center:
        https://dev.windows.com/en-us/downloads
        Only the single feature containing SIGNTOOL, MAKECERT and MAKECAT 
        will be installed. No other features are required by this script.
        The SECDRV PowerShell module cannot cope with installations of the SDK
        in a non-default path. If the SDK is installed in a non-default path,
        use the -ToolsPath parameter to specify where the mentioned tools are.
        
        If you wish to add or remove features from the SDK, or download
        it to an offline location, please download the SDK manually.
        The applicable file is called sdksetup.exe and is located here 
        https://go.microsoft.com/fwlink/p/?LinkId=619296

    .PARAMETER MakeCertificate
        A new certificate will be created, even if one already exists.
        A new certificate is created without specifying this switch, if none exists.
        Implies SignDriver.
        Exports the certificate and the private key to a folder on your machine.
        This will cause a prompt for a password to protect the private key while it is stored on disk.

    .PARAMETER SignDriver
        Writes a new Catalog Definition File (.cdf)
        Uses MAKECAT to create the Driver Catalog File (.cat), creating the digital signature for the driver in the process.
        Uses SIGNTOOL to sign the Driver Catalog File (.cat) using the most recently created certificate.

    .PARAMETER InstallDriver
        Imports the most recently created certificate into 
        1) Trusted Root Certification Authorities (Cert:\LocalMachine\Root) and
        2) Trusted Publishers (Cert:\LocalMachine\TrustedPublishers)
        Copies the driver file to $env:WINDIR\system32\drivers.
        Also runs SIGNTOOL to install cq. register the Signed Driver Catalog File (.cat) with Windows.
        
    .PARAMETER SetBootSigningOn
        Runs BCDEDIT to set BOOTSIGNING ON for the current OS boot entry.
        BCDEDIT /set {current} BOOTSIGNING ON

    .PARAMETER VerifyDriver
        Runs SIGNTOOL to verify the driver signature in the local Driver Catalog File (.cat)
        against the certificates present in Trusted Root Certification Authorities 
        (Cert:\LocalMachine\Root) and Trusted Publishers (Cert:\LocalMachine\TrustedPublishers)
        for the Driver File (.sys) present in the folder where this PowerShell Module is installed.

    .PARAMETER ToolsPath
        This script requires the MAKECAT, MAKECERT and SIGNTOOL executables in an 
        architecture-specific subfolder (i.e. x64 or x86) of the default Standalone SDK for 
        Windows 10 installation location (${env:ProgramFiles(x86)}\Windows Kits\10\bin).
        If for any reason you want to customize this behavior, you can specify 
        a full path to the folder containing MAKECAT, MAKECERT and SIGNTOOL in this parameter.
#>
function Install-SecDrv {
    [CmdletBinding()]
    param(
        [Switch]$MakeCertificate,
        [Switch]$SignDriver,
        [Switch]$InstallDriver,
        [Switch]$SetBootSigningOn,
        [Switch]$VerifyDriver,
        [String]$ToolsPath,
        [SecDrvServiceStartMode]$ServiceStartMode = [SecDrvServiceStartMode]::Manual,
        [Switch]$Confirm
    )
    DynamicParam {}
    Begin {}
    Process {
        $WhatIf = [Switch]::new($false) # not supported
        $CommonSplat = @{
            WhatIf = $WhatIf.IsPresent
            Verbose = $Verbose.IsPresent
            Confirm = $Confirm.IsPresent
        }
        $DriverName = [SecDrvConstants]::DriverName
        $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        if(!$CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
	    {
		    throw "This command must be run as Administrator."
	    }

        # If no switches are present, we'll be smart about what to do by figuring out what hasn't been done yet
        $All = !$MakeCertificate.IsPresent `
            -and !$SignDriver.IsPresent `
            -and !$InstallDriver.IsPresent `
            -and !$SetBootSigningOn.IsPresent `
            -and !$VerifyDriver.IsPresent
            
        $ActualToolsPath = $null
        try {
            $ActualToolsPath = Find-SecDrvToolsPath -Hint $ToolsPath # OK if $null
        } catch {
            if (!(Test-SecDrvWindowsSdk)) {
                Write-Warning "The $([SecDrvConstants]::SdkTitle) is not installed, or not up to date."
                Install-SecDrvWindowsSdk -Confirm:$($Confirm.IsPresent)
                if (!(Test-SecDrvWindowsSdk)) {
                    throw [System.OperationCanceledException]::new("A previous action failed.")
                }
                $ActualToolsPath = Find-SecDrvToolsPath -Hint $ToolsPath # OK if $null
            }
            throw;
        }
        if ([string]::IsNullOrEmpty($ActualToolsPath)) {
            throw [System.IO.DirectoryNotFoundException]::new("No path could be found that contains the tools required by this module.")
        }
        $Suppress = Install-SecDrvWindowsUpdates

        if ((Test-RebootRequired) -or (Get-WURebootStatus -Silent)) {
            Write-Warning "A reboot is required and you may experience problems running this script if you do not reboot first."
            Write-Host "It is recommended that you reboot now, to make sure that all features used by this script are up-to-date."
            Write-Host "To continue installing $DriverName after you reboot, run Install-SecDrv again, in one of the following ways:"
            Write-Host ""
            Write-Host "1) Start a Command Prompt as Administrator"
            Write-Host "2) Go back to github and copy the command you ran to get here"
            Write-Host "3) Paste it in the Command Prompt and press Enter, to download the module again and run Install-SecDrv at the same time"
            Write-Host "   --or--"
            Write-Host "1) Start a Command Prompt as Administrator"
            Write-Host "2) Starting PowerShell by typing ""PowerShell -ExecutionPolicy RemoteSigned"" and pressing Enter."
            Write-Host "3) Running Install-SecDrv by typing ""Install-SecDrv"" and pressing Enter."
            $RebootPrompt = [ChoiceDialog]::new(
                [SecDrvPrompt]::Yes, 
                "Reboot?", 
                "A reboot is required to be able to sign and install $DriverName. Do you want to reboot now?", @(
                [tuple]::Create("&Yes", "Reboot immediately. Recommended. Features used by this script may need them.", [SecDrvPrompt]::Yes),
                [tuple]::Create("&No", "Reboot later. Not recommended. You may be experiencing lots of red text.", [SecDrvPrompt]::No)
            ))
            $RebootAnswer = $RebootPrompt.Show()
            if ($RebootAnswer -eq [SecDrvPrompt]::Yes) {
                Write-Host "Initiating reboot..."
                Restart-Computer 
            } else {
                Write-Host "The export of certificates may fail. If this happens, reboot."
            }
        }

        $Approved = Approve-SecDrvToolsPath -Path $ActualToolsPath # throws if not approved
        Write-Verbose "Tools will be used from '$ActualToolsPath'."
        $MakeCert = Join-Path -Path $ActualToolsPath -ChildPath "MakeCert.exe"
        $MakeCat = Join-Path -Path $ActualToolsPath -ChildPath "MakeCat.exe"
        $SignTool = Join-Path -Path $ActualToolsPath -ChildPath "SignTool.exe"

        $HostName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
        $DateTime = "{0:dd MMM yyyy HH:mm}" -f [System.DateTimeOffset]::Now.ToLocalTime()
        $CertificateBasicName = "Private Signing Certificate for $DriverName.sys on \\$HostName"
        $CertificateCommonName = "$CertificateBasicName (Created by \\$env:USERDOMAIN\$env:USERNAME on $DateTime)"
        $CertificateNameRegex = "CN=$CertificateBasicName" -replace "\\", "\\" -replace "\.", "\." # escape the regex with a regex replace
        $CertificateNameRegex = "^$CertificateNameRegex \(.*\)$"
        $PrivateFolder = [SecDrvConstants]::GetUserSecretFolder()
        Write-Verbose "Private certificate and related files will be stored in '$PrivateFolder'."

        if (!(Test-Path $PrivateFolder)) { mkdir $PrivateFolder }
        $DriverSys = Join-Path $PrivateFolder "$DriverName.sys"
        $DriverCer = Join-Path $PrivateFolder "$DriverName.cer"
        $DriverCat = Join-Path $PrivateFolder "$DriverName.cat"
        $DriverDef = Join-Path $PrivateFolder "$DriverName.cdf"
        $DriverOut = Join-Path $PrivateFolder "$Drivername.txt"

        $Certificate = dir Cert: -Recurse | where Subject -Match $CertificateNameRegex | sort NotBefore -Descending | select -First 1
        $CertificateFileExists = Test-Path -Path $DriverCer -PathType Leaf
        $CertificateDingExists = $Certificate -ne $null
        $CertificateExists = $CertificateFileExists -or $CertificateDingExists

        $CertificateIsNew = $MakeCertificate.IsPresent -or ((-not $CertificateExists) -and $All)
        if (!$CertificateIsNew) {
            Write-Verbose "A certificate exists: $($Certificate.Subject)"
        } else {
            Write-Host "Creating Publisher Certificate with subject ""$CertificateCommonName""."
            $MakeCertArgs = 
                "-r",                      # Root Certificate / Self Signed Certificate
                #"-pe",                     # Private Key is Exportable - not needed
                "-sr", "LocalMachine",     # certificate store location <CurrentUser|LocalMachine>.  Default to 'CurrentUser'
                "-ss", "Root",             # Subject's certificate store name that stores the output certificate (dir cert:\LocalMachine)
                "-n", "CN=$CertificateCommonName", # Certificate subject X500 name (eg: CN=Fred Dews)
                $DriverCer                 # outputCertificateFile
            Invoke-CommandLine -Command $MakeCert -Arguments $MakeCertArgs @CommonSplat
            $Certificate = dir Cert: -Recurse | where Subject -Match $CertificateNameRegex | sort NotBefore -Descending | select -First 1
        }
        # Deploy
        <#
        To test-sign a catalog file or embed a signature in a driver file, 
        the MakeCert test certificate can be in the Personal certificate store ("my" store), 
        or some other custom certificate store, of the local computer that signs the software.

        But it must be in Cert:\LocalMachine\Root *and* in Cert:\LocalMachine\TrustedPublisher to use it.
        #>
        $DriverSignatureOK = $CertificateIsNew
        if (-not $DriverSignatureOK) {
            Write-Verbose "Verifying the digital certificate using catalog '$DriverCat' for driver file '$DriverSys'."
            $SignToolVerifyOutput = & $SignTool verify /v /pa /c $DriverCat $DriverSys
            $SignToolStatus = $LASTEXITCODE
            Write-Conditional $SignToolVerifyOutput -Verbose:$($Verbose.IsPresent)
            $DriverSignatureOK = $SignToolStatus -eq 0
            if ($DriverSignatureOK) {
                Write-Verbose "The driver signature is OK."
            } else {
                Write-Verbose "The driver signature is not OK."
            }
        }

        $DriverCerExists = Test-Path $DriverCer
        $DriverDefExists = Test-Path $DriverDef
        $DriverCatExists = Test-Path $DriverCat
        $DriverIsSigned = $DriverCerExists -and $DriverDefExists -and $DriverCatExists -and $DriverSignatureOK
        if ($CertificateIsNew -or $SignDriver.IsPresent -or ($All -and (!$DriverIsSigned))) {
            Push-Location -Path $PrivateFolder
            try {
                # Using MakeCat to Create a Catalog File 
                # https://msdn.microsoft.com/en-us/library/windows/hardware/ff553620%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
                $DriverCatalogDefinition = @(
                    "[CatalogHeader]",
                    "Name=$DriverName.cat",
                    "PublicVersion=0x1",
                    "EncodingType=0x00010001",
                    "CATATTR1=0x10010001:OSAttr:2:6.0",
                    "[CatalogFiles]",
                    "<hash>$DriverName=$DriverName.sys"
                ) -join "`r`n"
                # SECDRV.cdf
                Write-Verbose "Creating a Driver Catalog Definition File (.cdf)"
                Set-Content -Value $DriverCatalogDefinition -Path $DriverDef -Encoding Ascii -Force
                # SECDRV.sys
                # SECDRV.sys is deployed there already # copy "$RootFolder\$DriverName.sys" $PrivateFolder
                # SECDRV.cat
                Write-Verbose "Creating the Driver Catalog File (.cat)"
                $MakeCatArgs = 
                    "-v",              # Verbose for Write-Verbose
                    "-o", $DriverOut,  # output filename/hash pairs to specified file
                    "-r",              # return fail even on recoverable errors
                    $DriverDef         # CDF_filename
                Invoke-CommandLine -Command $MakeCat -Arguments
                #$MakeCatOutput = & $MakeCat -v -o $DriverOut $DriverDef # MakeCat must be run in the folder where the driver file is, hence Push-Location
                #Write-Conditional $MakeCatOutput -Verbose:$($Verbose.IsPresent)

                try {
                    # Sign the driver - doesn't work with [SecureString] obviously
                    $TimeStampUrl = [SecDrvConstants]::VerisignTimestampServerUrl
                    Write-Verbose "Using timestamp server $TimestampUrl"
                    Write-Verbose "Signing the Driver Catalog File (.cat)"
                    $SignToolArgs = 
                        "sign",                                       # sign a file
                        "/v", "/debug",                               # Verbose, Debug => Write-Verbose
                        #"/f", $DriverCer,                            # not using the .cer - it doesn't have a private key
                        "/sm", "/s", "Root",                          # Store Machine, Root=Trusted Root CA's: Cert:\LocalMachine\Root
                        "/sha1", $($Certificate.Thumbprint),          # Cert:\LocalMachine\Root\53FA801... i.e. the certificate previously generated
                        "/t", $TimeStampUrl,                          # Get a timestamp using the Verisign URL
                        $DriverCat                                    # .\SECDRV.cat stores the result of the signing operation
                    Invoke-CommandLine -Command $SignTool -Arguments $SignToolArgs @CommonSplat 
                    #$SignToolOutput = & $SignTool sign /v /debug /f $DriverCer /sm /s Root /sha1 $($Certificate.Thumbprint) /t $TimeStampUrl $DriverCat
                    #Write-Debug ($SignToolOutput -join "`n")
                } finally {
                    $PasswordClearText = $null
                }
            } finally {
                Pop-Location
            }
        }
        <#
        To verify a test signature, the corresponding test certificate must be installed in the 
        Trusted Root Certification Authorities certificate store of the local computer that you use 
        to verify the signature.
        #>
        $SecDrvInstalledPath = "$env:windir\system32\drivers\$DriverName.sys"
        $DriverSysIsInstalled = Test-Path $SecDrvInstalledPath
        if (!$InstallDriver.IsPresent -or $CertificateIsNew -or $VerifyDriver.IsPresent) {
            Write-Verbose "Verifying the driver signature to determine whether reinstallation is required."
            $SignToolVerifyOutput = & $SignTool verify /v /pa /c $DriverCat $DriverSys
            $SignToolStatus = $LASTEXITCODE
            Write-Conditional $SignToolVerifyOutput -Verbose:$($Verbose.IsPresent -or $VerifyDriver.IsPresent)
            $DriverSignatureOK = $SignToolStatus -eq 0
            if ($DriverSignatureOK) {
                Write-Verbose "The driver signature is OK."
            } else {
                Write-Verbose "The driver signature is not OK."
            }
        }

        $DriverReinstalled = $false
        if ($InstallDriver.IsPresent -or ($All -and !$DriverInstalled)) {
            $CertificateLocations = @("Cert:\LocalMachine\Root", "Cert:\LocalMachine\TrustedPublisher")
            foreach ($CertificateLocation in $CertificateLocations) { # $CertificateLocation = $CertificateLocations[1]
                if ((dir "$CertificateLocation\$($Certificate.Thumbprint)" -ErrorAction SilentlyContinue).Count -eq 0) {
                    Write-Verbose "Importing certificate to $CertificateLocation"
                    Import-PfxCertificate -Exportable -Password $Password -CertStoreLocation $CertificateLocation -FilePath $DriverCer -Verbose:$($Verbose.IsPresent)
                }
            }
            Write-Verbose "Copying '$DriverSys' to '$SecDrvInstalledPath'." 
            copy $DriverSys $SecDrvInstalledPath -Force
            Write-Verbose "Installing Driver Catalog '$DriverCat'."
            # Installing a Catalog File by using SignTool
            # https://msdn.microsoft.com/en-us/library/windows/hardware/ff547579(v=vs.85).aspx
            $SuppressOutput = & $SignTool catdb /v /u $DriverCat
            Write-Conditional $SuppressOutput -Verbose:$($Verbose.IsPresent)
            $DriverReinstalled = $true

            # Set the service start mode
            $DriverRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\secdrv"
            if (!(Test-Path $DriverRegistryPath -ErrorAction SilentlyContinue)) {
                $Suppress = New-Item -Path $DriverRegistryPath -ItemType Directory
            }
            Set-ItemProperty -Path $DriverRegistryPath -Name Start -Value ([int]$ServiceStartMode) 
            if ($false) { # Test Code
                Remove-ItemProperty -Path $DriverRegistryPath -Name Start
                rmdir -Path $DriverRegistryPath -Recurse -Force # Don't do this at home
                Get-ItemProperty -Path $DriverRegistryPath -ErrorAction SilentlyContinue
            }
        }
        if ($SetBootSigningOn.IsPresent -or $All) {
            Write-Verbose "Running BCDEDIT /set {current} TESTSIGNING ON"
            $SuppressOutput = & bcdedit /set "{current}" testsigning on
            Write-Conditional $SuppressOutput -Verbose:$($Verbose.IsPresent)
            if ($LASTEXITCODE -ne 0) {
                throw $SuppressOutput -join "`n"
            }
        }
        if ($Confirm.IsPresent -and ($DriverReinstalled -or $SetBootSigningOn.IsPresent)) {
            Write-Warning "A reboot is required, to complete installation of the driver. This is required before SECDRV can be enabled and started."
            Write-Host "Once the system has rebooted, SECDRV will be installed, but disabled."
            Write-Host "Run "
            Write-Host "`tPowerShell -ExecutionPolicy RemoteSigned -Command { Enable-SecDrv; Start-SecDrv; }"
            Write-Host "to enable and start it."
            Write-Host "Run "
            Write-Host "`tPowerShell -ExecutionPolicy RemoteSigned -Command { Disable-SecDrv }"
            Write-Host "to stop and disable it."
            Write-Host "You can add these snippets to a script you can run from a shortcut or the StartMenu."
            $RebootPrompt = [ChoiceDialog]::new([SecDrvPrompt]::Yes, "Reboot?", "A reboot is required to enable $DriverName. Do you want to reboot now?", @(
                [tuple]::Create("&Yes", "Reboot immediately. You must do this immediately to enable $DriverName ASAP.", [SecDrvPrompt]::Yes),
                [tuple]::Create("&No", "Reboot later. There is no pressing need to do this at any particular moment.", [SecDrvPrompt]::No)
            ))
            $RebootAnswer = $RebootPrompt.Show()
            if ($RebootAnswer -eq [SecDrvPrompt]::Yes) { 
                Write-Host "The system will reboot in 10 seconds."
                Start-Sleep -Seconds 10
                Restart-Computer 
            }
        }
       
    }
    End { }
}
function Enable-SecDrv {
    [CmdLetBinding()]
    param(
        [Switch]$AutoStart
    )
    Process {
        if ($AutoStart.IsPresent) {
            & cmd /c sc config secdrv start= auto
        } else {
            & cmd /c sc config secdrv start= demand
        }
    }
}
function Disable-SecDrv {
    [CmdLetBinding()]
    param()
    Process {
        & cmd /c sc stop secdrv
        & cmd /c sc config secdrv start= disabled
    }
}
function Start-SecDrv {
    [CmdLetBinding()]
    param()
    Process { & cmd /c sc start secdrv }
}
function Stop-SecDrv {
    [CmdLetBinding()]
    param()
    Process { & cmd /c sc stop secdrv }
}

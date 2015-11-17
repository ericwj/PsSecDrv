class SecDrvBootstrap {
    # Load UserSecrets - System-specific configuration
    static [object]GetUserSecrets() {
        $Path = [SecDrvBootstrap]::UserSecretsPath
        $File = Join-Path $Path "secrets.json"
        if (-not (Test-Path $File)) { return $null }
        $FileInfo = dir $File
        if ($FileInfo -eq $null) { return $null }
        if ($FileInfo.Attributes -band ([System.IO.FileAttributes]::Directory)) { return $null }
        $Text = Get-Content $File -ErrorAction SilentlyContinue -Encoding UTF8
        if ([string]::IsNullOrEmpty($Text)) { return $null }
        $Text = $Text -join "`n"
        $Json = $null
        try {
            $Json = ConvertFrom-Json $Text -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not load '$File'."
        }
        return $Json
    }
    
    # During dev/test, download from the URL "OriginSite" in UserSecrets (possibly file:////)
    static [string]GetOriginSite() {
        $Json = [SecDrvBootstrap]::GetUserSecrets()
        if ($Json -ne $null -and ![String]::IsNullOrWhiteSpace($Json.OriginSite)) {
            try {
                [string]$Url = $Json.OriginSite
                [uri]$Uri = [uri]::new($Url) # might throw for invalid user data
                return $Url
            } catch {
                Write-Warning "Could not parse 'OriginSite'."
            }
        }
        if (![String]::IsNullOrWhitespace($env:SECDRV_ORIGINSITE)) {
            return $env:SECDRV_ORIGINSITE
        }
        return "https://raw.githubusercontent.com/ericwj/PsSecDrv/master/"
    }
    # During dev/test, download from the URL "OriginSite" in UserSecrets (possibly file:////)
    static [bool]GetVerbosePreference() {
        $Json = [SecDrvBootstrap]::GetUserSecrets()
        if ($Json -ne $null -and ![String]::IsNullOrWhiteSpace($Json.Verbose)) {
            return $Json.Verbose 
        }
        return $false
    }
    # During dev/test, download from the URL "OriginSite" in UserSecrets (possibly file:////)
    static [bool]GetConfirmPreference() {
        $Json = [SecDrvBootstrap]::GetUserSecrets()
        if ($Json -ne $null -and ![String]::IsNullOrWhiteSpace($Json.Confirm)) {
            return $Json.Confirm
        }
        return $false
    }
    static [void]Download([string]$Url, [string]$TargetPath) {
        $uri = [Uri]::new($Url) # will throw if invalid
        if ($uri.IsFile -or $uri.IsUnc) {
            # used during test by setting secrets.json#OriginSite=file://C:/Users/pathToGitRepo
            copy -Path $uri.LocalPath -Destination $TargetPath 
        } else {
            # Supposed to be some raw.githubusercontent.com URI (tbd)
            try {
                curl -Uri $Url -OutFile $TargetPath -ErrorAction SilentlyContinue
            } catch {
                throw [System.Net.WebException]::new("Could not download '$TargetPath' from '$Url'.")
            }
        }
    }
    static [string]$ModuleName = "SECDRV"
    static [object]$FQN = @{ModuleName=([SecDrvBootstrap]::ModuleName);Guid=[guid]::new("{c8da5d77-b7cf-40a4-9cc8-240f6013a1fd}");ModuleVersion="0.0.0.0"}
    static [string]$UserSecretsPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\UserSecrets\SECDRV"
    # PowerShell Module path in UserProfile
    static [string]$TargetPathPsm = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\$([SecDrvBootstrap]::ModuleName)"
    # Default path to store the driver and the publisher certificate etc
    static [string]$TargetPathDefault = [SecDrvBootstrap]::UserSecretsPath
    static [string[]]$Manifest = @(
        "src/SECDRV/SECDRV.psd1=[TargetPathPsm]\SECDRV.psd1",
        "src/SECDRV/SECDRV.psm1=[TargetPathPsm]\SECDRV.psm1",
#        "$([SecDrvBootstrap]::ModuleName).ChoiceDialog.psm1=TargetPathPsm",
        "tools/SECDRV/SECDRV.sys=[TargetPathDefault]\SECDRV.sys"
    )
    static [System.Collections.Generic.Dictionary[string,string]]GetManifestUrls() {
        $Result = [System.Collections.Generic.Dictionary[string,string]]::new()
        
        $OriginSite = [SecDrvBootstrap]::GetOriginSite()
        $OriginSiteUri = [Uri]::new($OriginSite)
        $OriginSiteIsFile = $OriginSiteUri.IsFile -or $OriginSiteUri.IsUnc
        
        $Psm = [SecDrvBootstrap]::TargetPathPsm
        $Default = [SecDrvBootstrap]::TargetPathDefault
        foreach ($file in [SecDrvBootstrap]::Manifest) {
            $split = $file -split "="
            $name = $split[0] # tools/SECDRV/SECDRV.sys
            $spec = $split[1] # [TargetPathDefault]\SECDRV.sys
            $TargetPath = $spec `
                -replace "\[TargetPathPsm\]", ([SecDrvBootstrap]::TargetPathPsm) `
                -replace "\[TargetPathDefault\]", ([SecDrvBootstrap]::TargetPathDefault)
            if ($TargetPath -eq $spec) {
                $message = "The target path specification '$spec' for file '$file' in the manifest is unknown."
                throw [System.ArgumentException]::new($message)                
            }
            $FileOrigin = $OriginSite
            if ($OriginSiteIsFile) {
                $FileOrigin = Join-Path $OriginSiteUri.LocalPath $name
            } else {
                $FileOrigin = $OriginSite + $name # simply concatenate
            }
            $Result.Add($FileOrigin, $TargetPath)
        }
        return $Result
    }
}
# Test code
if ($false) {
    # See what's here
    dir $env:USERPROFILE\Documents\WindowsPowerShell\Modules -Recurse -ErrorAction SilentlyContinue
    dir ([SecDrvBootstrap]::UserSecretsPath) -ErrorAction SilentlyContinue
    # Module Info
    Get-Module -Name SECDRV -ListAvailable | select -First 1 | fl
    # Clean
    del (Join-Path ([SecDrvBootstrap]::UserSecretsPath) "SECDRV.*")
    rmdir ([SecDrvBootstrap]::TargetPathPsm) -Recurse
}
$Verbose = [switch]::new([SecDrvBootstrap]::GetVerbosePreference())
$Confirm = [switch]::new([SecDrvBootstrap]::GetConfirmPreference())
if ($Verbose) { $VerbosePreference = [System.Management.Automation.ActionPreference]::Continue }
# Download the neccessary files
$urls = [SecDrvBootstrap]::GetManifestUrls()
Write-Warning "Downloading the SECDRV intaller module from $([SecDrvBootstrap]::GetOriginSite())"
$origin = [uri]::new([SecDrvBootstrap]::GetOriginSite())
foreach ($ding in $urls.Keys) {
    if ($origin.IsFile -or $origin.IsUnc) {
        $short = "." + $ding.Substring($origin.LocalPath.Length)
    } else {
        $short = $origin.MakeRelative([uri]::new($ding))
    }
    Write-Verbose "Downloading $short => $($urls[$ding])"
    $FileOrigin = $ding
    $TargetPath = $urls[$ding]
    $FolderPath = [System.IO.Path]::GetDirectoryName($TargetPath)
    if (!(Test-Path $FolderPath)) { $unused = mkdir $FolderPath }
    [SecDrvBootstrap]::Download($FileOrigin, $TargetPath)
}
# Check PSModulePath and add the $userprofile\WindowsPowerShell\Modules folder (which is included by default) if it isn't there
$ModulePaths = $env:PSModulePath -split ";"
$ModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
# Unconditionally reorder $PSModulePath to prioritize $ModulePath, 
# since we want to load from the folder where the script is downloaded to
# so if this script is run (from a trusted source), it'll always download again (from a trusted source)
# and screw up any attempts to replace the module with another version.
#if ($ModulePaths -notcontains $ModulePath) { 
    $ModulePaths = @($ModulePath) + $ModulePaths | select -Unique # might have the effect of reordering $ModulePath as the first folder
    $env:PSModulePath = $ModulePaths -join ";"
#}

# If the module is loaded, unload it first
$LoadedModule = Get-Module -FullyQualifiedName ([SecDrvBootstrap]::FQN)
if ($LoadedModule -ne $null) {
    Remove-Module -Name SECDRV
}
# Now we should be able to upgrade
$ModuleOK = Get-Module -FullyQualifiedName ([SecDrvBootstrap]::FQN) -ListAvailable
if ($ModuleOK -eq $null) {
    Write-Error "Something went wrong. The module SECDRV is not installed."
} else {
    Import-Module -FullyQualifiedName ([SecDrvBootstrap]::FQN)
}
$CommandOK = Get-Command -Verb Install -Noun SecDrv -FullyQualifiedModule ([SecDrvBootstrap]::FQN)
if ($CommandOK -eq $null) {
    Write-Error "Something went wrong. Could not find the Install-SecDrv command."
}
Write-Host "The PowerShell Module is installed."
if ($Verbose) {
    Write-Verbose "The following commands are available:" 
    Get-Command -FullyQualifiedModule ([SecDrvBootstrap]::FQN) | select Noun, Verb, Name, CommandType, Source, Version | sort Noun, Verb | ft
    Write-Verbose "To get more information, start PowerShell and try:"
    Write-Verbose "`tGet-Help <Name>"
    Write-Verbose "E.g."
    Write-Verbose "`tGet-Help Install-SecDrv"
}
# no checking for tools here and no call to a comand -- that's better left to the copy/paste script
#Install-SecDrv -Verbose:$Verbose -Confirm:$Confirm
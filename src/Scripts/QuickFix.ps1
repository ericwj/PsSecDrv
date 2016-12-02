# Enable test signing
bcdedit /set "{current}" testsigning on

# Set path to Windows 10 SDK
$arch = "x86"
if ($env:PROCESSOR_ARCHITECTURE -eq "amd64") { $arch = "x64" }
$env:Path = "$env:Path;${env:ProgramFiles(x86)}\Windows Kits\10\bin\$arch"
cd $env:USERPROFILE

# Create a private root certificate to sign driver with
$DateTime = "{0:dd MMM yyyy HH:mm}" -f [System.DateTimeOffset]::Now.ToLocalTime()
makecert -r -sr LocalMachine -ss Root -n "CN=Private Signing Certificate for SECDRV.sys on \\$env:COMPUTERNAME created by \\$env:USERDOMAIN\$env:USERNAME on $DateTime"
# Find it in the certificate store
$Certificate = dir Cert:\LocalMachine\Root | where Subject -Match SECDRV | sort NotBefore | select -Last 1
Write-Host "Using certificate $($Certificate.Subject)"
# Export to file
<# Don't need this - just need the thumbprint
$Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$Pwd = [byte[]]::new(16)
$Rng.GetBytes($Pwd)
$PasswordPlainText = [System.Convert]::ToBase64String($Pwd)
$PasswordSecString = ConvertTo-SecureString -String $PasswordPlainText -AsPlainText -Force
Export-PfxCertificate -Cert $Certificate -FilePath "SECDRV.pfx" -Password $PasswordSecString -Confirm:$false
#>

 $CDF = @(
    "[CatalogHeader]",
    "Name=SECDRV.cat",
    "PublicVersion=0x1",
    "EncodingType=0x00010001",
    "CATATTR1=0x10010001:OSAttr:2:6.0",
    "[CatalogFiles]",
    "<hash>SECDRV=SECDRV.sys"
) -join "`r`n"
# Write catalog definition file (.cdf)
sc SECDRV.cdf -Value $CDF
# Find SECDRV.sys in C:\ and copy the first match to the current directory
$SecdrvSys = dir -ErrorAction SilentlyContinue -Path "$env:SystemDrive\" -Filter SECDRV.sys -Recurse | select -First 1
copy $secdrvsys.FullName .
# Create driver signing catalog file (.cat) and copy readable hashes to text file (.txt)
makecat -v -o SECDRV.txt -r SECDRV.CDF
# Sign the driver
signtool sign /v /debug /sm /s Root /sha1 "$($Certificate.Thumbprint)" /t "http://timestamp.verisign.com/scripts/timstamp.dll" secdrv.cat

# Install driver
copy secdrv.sys "$env:windir\System32\drivers" -Force
signtool catdb /v /u secdrv.cat

# Set to Manual start
<# Use sc.exe to configure, not direct registry edits
$DriverRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\secdrv"
if (!(Test-Path $DriverRegistryPath -ErrorAction SilentlyContinue)) {
    $Suppress = New-Item -Path $DriverRegistryPath -ItemType Directory
}
# <see cref="System.ServiceProcess.ServiceStartMode"/>
$Automatic = 2
$Manual = 3
$Disabled = 4
$ServiceStartMode = $Manual
Set-ItemProperty -Path $DriverRegistryPath -Name Start -Value ([int]$ServiceStartMode)
#>
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
Enable-SecDrv -AutoStart
# Trying to start before reboot will fail
# Start-SecDrv

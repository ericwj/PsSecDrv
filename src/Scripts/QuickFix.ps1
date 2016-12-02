# Enable test signing
bcdedit /set "{current}" testsigning on

# Set path to Windows 10 SDK
$arch = "x86"
if ($env:PROCESSOR_ARCHITECTURE -eq "amd64") { $arch = "x64" }
$env:Path = "$env:Path;${env:ProgramFiles(x86)}\Windows Kits\10\bin\$arch"
cd $env:USERPROFILE

# Create a private root certificate to sign driver with
$DateTime = "{0:dd MMM yyyy HH:mm}" -f [System.DateTimeOffset]::Now.ToLocalTime()
makecert -r -sr LocalMachine -ss Root -pe -n "CN=Private Signing Certificate for SECDRV.sys on \\$env:COMPUTERNAME created by \\$env:USERDOMAIN\$env:USERNAME on $DateTime"
# Find it in the certificate store
$Certificate = dir Cert:\LocalMachine\Root | where Subject -Match SECDRV | sort NotBefore | select -Last 1
Write-Host "Using certificate $($Certificate.Subject)"

# Export to file then import to Cert:\LocalMachine\TrustedPublisher
$Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$RandomBytes = [byte[]]::new(16)
$Rng.GetBytes($RandomBytes)
$PasswordPlainText = [System.Convert]::ToBase64String($RandomBytes)
$PasswordSecString = ConvertTo-SecureString -String $PasswordPlainText -AsPlainText -Force
$SuppressOutput = Export-PfxCertificate -Cert $Certificate -FilePath "SECDRV.pfx" -Password $PasswordSecString -Confirm:$false
$SuppressOutput = Import-PfxCertificate -FilePath "SECDRV.pfx" -Password $PasswordSecString -CertStoreLocation Cert:\LocalMachine\TrustedPublisher

# Delete the certificate with its private key exportable and import the pfx with non-exportable private key
del "Cert:\LocalMachine\Root\$($Certificate.Thumbprint)"
$SuppressOutput = Import-PfxCertificate -FilePath "SECDRV.pfx" -Password $PasswordSecString -CertStoreLocation Cert:\LocalMachine\Root

# Zero and delete the pfx file and the password
$PfxPath = "$((Get-Location).Path)\SECDRV.pfx"
$PasswordPlainText = ""
$PasswordSecString.Clear()
$FileSize = [System.IO.File]::ReadAllBytes($PfxPath).Length
$RandomBytes = [byte[]]::new($FileSize) # All zeroes
[System.IO.File]::WriteAllBytes($PfxPath, $RandomBytes)
del SECDRV.pfx

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
makecat -o SECDRV.txt -r SECDRV.CDF
# Sign the driver
signtool sign /sm /s Root /sha1 "$($Certificate.Thumbprint)" /t "http://timestamp.verisign.com/scripts/timstamp.dll" secdrv.cat

# Install driver
copy secdrv.sys "$env:windir\System32\drivers" -Force
signtool catdb /u secdrv.cat

# Set to automatic start
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

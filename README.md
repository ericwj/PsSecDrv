# How to install SECDRV.sys to play games
Microsoft does provide a way to re-enable SECDRV.

* Install a game that brings (a recent version of) `SECDRV.sys`.
* Install the Windows 10 SDK from [Get the standalone Windows 10 SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk).  
Just install all components.
* Start *PowerShell* as an administrator.
* Find `makecat.exe`, `makecert.exe` and `signtool.exe` and add the path to your PATH in System Properties, Environment Variables.  
The ones in a x86 subfolder are always OK on all Intel architecture chips. No need to match the hardware or the OS bitness.  
  ```
  $SdkToolsPath = dir -Path "${env:ProgramFiles(x86)}\Windows Kits\10" -Recurse -Directory | where { $n = $_.FullName; $_.BaseName -eq "x86" -and [System.IO.File]::Exists("$n\makecert.exe") -and [System.IO.File]::Exists("$n\makecat.exe") -and [System.IO.File]::Exists("$n\signtool.exe") } | sort CreationTime | select -Last 1
  $env:Path = "$env:Path;$($SdkToolsPath.FullName)"
  ```
* Create a new folder in your Downloads folder
  ```
  $WorkingDirectory = "$env:UserProfile\Downloads\SECDRV"
  if (-not (Test-Path $WorkingDirectory)) { mkdir $WorkingDirectory | Out-Null }
  ```
* Run all further commands in a PowerShell prompt as Administrator in the folder you created.
  ```
  cd $WorkingDirectory
  ```
* Copy `SECDRV.sys` in it. If it's an old version, replace it with this one downloadable [here](https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys). Its from September 2006.
  ```
  # Using curl (Windows 10 has it inbox)
  curl.exe -OL https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys
  # Using PowerShell or PowerShell Core
  iwr -Uri https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys -OutFile SECDRV.sys
  ```
* Enable test signing boot mode.  
  ```
  bcdedit /set "{current}" testsigning on
  ```
* Pick a subject - any subject, but include the text "SECDRV" in it
  ```
  $Subject = "SECDRV.sys Published by \\$env:ComputerName\$env:UserName on $("{0:yyyy-MM-dd HH:mm}" -f [datetimeoffset]::Now)"
  ```
* Create a root certificate.  
  ```
  # try this
  makecert -r -sr LocalMachine -ss My -n $Subject
  # if it doesn't work, use this
  makecert -r -sr LocalMachine -ss My -n "CN=$Subject"
  ```
* Open Local Machine Certificates.  
  ```
  certlm.msc
  ```
* Go to Personal, Certificates and select the certificate created, there usually is only one, or match the subject, right click Copy.
* Go to Trusted Root Certification Authorities, Certificates. Paste.
* Go to Trusted Publishers, Certificates. Paste.
* Make a text file called `SECDRV.cdf` in the folder and put the text between @" and "@ in it.
  ```
  Set-Content -Path SECDRV.cdf -Value @"
  [CatalogHeader]
  Name=SECDRV.cat
  PublicVersion=0x1
  EncodingType=0x00010001
  CATATTR1=0x10010001:OSAttr:2:6.0
  [CatalogFiles]
  <hash>SECDRV=SECDRV.sys
  "@
  ```
* Make a driver catalog file in the folder.  
  ```
  makecat -o SECDRV.txt -r SECDRV.cdf
  ```
* Get the thumbprint of the certificate you created. The thumbprint is shown in `certlm` for the certificate created, just double click it and look around, without spaces. Or get it in PowerShell with dir:
  ```PS
  $Publishers = dir Cert:\LocalMachine -Recurse | where Subject -Match SECDRV | sort NotBefore
  $Publishers | select Thumbprint, NotBefore, NotAfter, Subject
  $Publisher = $Publishers | select -Last 1
  ```
* Sign the driver.  
  ```
  signtool sign /sm /s Root /sha1 "$($Publisher.Thumbprint)" /t http://timestamp.digicert.com secdrv.cat
  ```
* Install the driver. This adds it to the driver catalog on your system, but does not copy files or create driver services.
  ```
  signtool catdb /u secdrv.cat
  ```
* Just to be sure, overwrite the `SECDRV.sys` on your system with the exact version that you signed and installed.
  ```
  copy .\SECDRV.sys "$env:windir\System32"
  ```
* Reboot.
* Test if it works.
  ```
  sc.exe start secdrv
  ```

If it doesn't work, check these reasons.
* You are not an Administrator or you opened the PowerShell prompt without elevation. Right click the button in the Task Bar and hit *Run as Administrator* and start over.
* `SECDRV.sys` is too old. Then the driver doesn't start. Right click it, hit *Properties*, go to *Details* and check *Product version*. It contains a date as a string. If you downloaded it from the link above, the version is "SECURITY Driver 4.03.086 2006/09/13".
* You might have to run games that need `SECDRV` as Administrator. The driver might not be installed and the driver services might not be present until you have tried this.
* Secure Boot is enabled. Run `bcdedit` again after disabling it.
* You didn't reboot. You will have to reboot.

Now play games.

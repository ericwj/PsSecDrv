# How to install SECDRV.sys to play games
Microsoft does provide a way to re-enable SECDRV.

* Install a game that brings (a recent version of) `SECDRV.sys`.
* Install the Windows 10 SDK from [Get the standalone Windows 10 SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk).  
Just install all components.
* Start *PowerShell* as an administrator.
* Make sure you are on 64-bit Windows, or make sure whichever `SECDRV.sys` you will be using going through this guide is 32-bit. See how below.
  ```
  [System.Environment]::Is64BitOperatingSystem
  ```
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
* Copy `SECDRV.sys` in it. Match your operating system bitness.  
  If it's an old version and you're on 64-bit Windows, replace it with this one downloadable [here](https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys). Its from September 2006.
  ```
  # Using curl (Windows 10 has it inbox)
  curl.exe -OL https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys
  # Using PowerShell or PowerShell Core
  iwr -Uri https://github.com/ericwj/PsSecDrv/raw/master/tools/SECDRV/SECDRV.sys -OutFile SECDRV.sys
  ```
  That one is 64-bit.
* Check that you have the correct bitness:
  ```
  $bytes = [System.IO.File]::ReadAllBytes($exe)
  [int]$pe = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 1KB).IndexOf("PE`0`0")
  $mc = [System.BitConverter]::ToUInt16($bytes, $pe + 4)
  switch ($mc) { 0x8664 { "64-bit" } 0x014c { "32-bit" } default { "Unknown" } }
  ```
  > This is a very opportunistic way of reading the machine type in about as few lines as possible by simply finding the first occurrence of `PE\0\0` in the file. So use with caution.

  The even more opportunistic way is to simply do `type SECDRV.sys | more`, make sure the first two letters are `MZ` and look for `PE` usually all by itself on a line about a screen down of `This program cannot be run in DOS mode.` and see if you can find `L` or `d` two lines down from it.
  1. If the letter is `L` then the PE file is probably 32-bit (`L` is `0x4c` in ASCII).
  2. If the letter is `d` then the PE file is probably 64-bit (`d` is `0x64` in ASCII).
  <img width="867" alt="image" src="https://user-images.githubusercontent.com/9473119/172049657-143b5e31-8ffc-419c-82fc-75b3bc85076c.png">

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
  If you get `SignTool Error: No file digest algorithm specified. (...) use the /fd certHash option.`, run this instead
  ```
  signtool sign /sm /s Root /sha1 "$($Publisher.Thumbprint)" /fd SHA256 /t http://timestamp.digicert.com secdrv.cat
  ```
* Install the driver. This adds it to the driver catalog on your system, but does not copy files or create driver services.
  ```
  signtool catdb /u secdrv.cat
  ```
* Just to be sure, overwrite the `SECDRV.sys` referred to by the kernel driver service with the exact version that you signed and installed.
  ```
  sc.exe qc secdrv
  ```
  If the output has something like `\??\C:\Windows\system32\drivers\SECDRV.sys`, copy that path excluding `\??\` and use it in the next command:
  ```
  copy .\SECDRV.sys "C:\Windows\system32\drivers\SECDRV.sys"
  ```
* Reboot.
* Test if it works.
  ```
  sc.exe start secdrv
  ```

If it doesn't work, check these reasons.
* You are not an Administrator or you opened the PowerShell prompt without elevation. Right click the button in the Task Bar and hit *Run as Administrator* and start over.
* `SECDRV.sys` is too old. Then the driver doesn't start. Right click it, hit *Properties*, go to *Details* and check *Product version*. It contains a date as a string. If you downloaded it from the link above, the version is "SECURITY Driver 4.03.086 2006/09/13".
* `SECDRV.sys` is 32-bit and your Windows is 64-bit. Download `SECDRV.sys` from the link given.
* `SECDRV.sys` is 64-bit and your Windows is 32-bit. Then don't download the driver from the link given, but use whichever version came with the game you installed.
* You might have to run games that need `SECDRV` as Administrator. The driver might not be installed and the driver services might not be present until you have tried this.
* Secure Boot is enabled. Run `bcdedit` again after disabling it.
* You didn't reboot. You will have to reboot.

Now play games.

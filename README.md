# PsSecDrv
PowerShell script and module to install the SECDRV copy protection driver on Windows 10.

## What's this?
PsSecDrv is a bit of PowerShell script that can install SECDRV.sys on a computer running Windows 10, 
eliminating almost all manual steps from this process, apart from starting the script.

To learn a little bit about SECDRV.sys, see [What is SECDRV?](docs/SECDRV.md).

## Wow, this readme is long!
OK here's the jump start.

It isn't really safe to use SECDRV. All complaints aside, even if Microsoft has other reasons to remove it from Windows 10,
this one is really good and enough all by itself. The objective might have been to make Windows 10 secure and allowing no
excuses to compromise that goal. So use SECDRV (and by extension, this script) at your own risk!

Disable Secure Boot in your BIOS if you have a modern say tablet which is BitLockered without 
you ever having done anything to make it so. SECDRV won't load with Secure Boot enabled.

Right click Start and pick Command Prompt (Administrator). Copy and pass these three lines of text.
```PowerShell 
rem Start
PowerShell -NoExit -ExecutionPolicy RemoteSigned -Command "$wc = [System.Net.WebClient]::new(); $s = $wc.DownloadString('https://raw.githubusercontent.com/ericwj/PsSecDrv/master/src/SECDRV/SECDRV.ps1'); iex $s"
rem End
```
PowerShell will have done nothing but copy a few files to your computer (including SECDRV.sys). Now copy and paste this.
```PowerShell 
Install-SecDrv
```
To enable and start SECDRV:
```PowerShell 
Enable-SecDrv
Start-SecDrv 
```
To stop and disable SECDRV:
```PowerShell 
Stop-SecDrv
Disable-SecDrv
```
These commands can be copied into text files, saved with file extension .ps1 and be run from the Start Menu.

## Why?
I wrote the PowerShell scripts in this repository for several reasons:
* Because this script includes the most recent copy of the driver (that I know of), so I don't have to search for it.
* Because I don't like to use 'third party tools' tools to install SECDRV which are themselves a potential security risk.
* Because I really don't want to tell my computer to trust security certificates for which someone else with potentially 
malicious intent has the private key or which are not under my control. 
* Because I am confident a script (that is plain text more or less in English) available from a public source, open to scrutiny from
knowledgable people, would give everyone including novice users reason to trust that it is safe to run.
* Because I had been digging into the wonderful world called PowerShell to automate a variety of tasks and
wrote most of the code used in this repository in a few hours in a weekend some time ago and learned a lot about 
PowerShell in the process.

## What's the status?
Making it run the first time completely flawless in a way that is convenient was an interesting undertaking so far
and isn't finished yet.

## Is it safe?
No.

No windows dressing, no excuses. It's not safe. (Yes, typo. No, I won't fix ;)

But we want to play games, right? Even old games.

I recommend you setup your computer to dual boot. For example using VHD boot. And use a Windows Insider Preview build
to do that completely legally.

And then use SECDRV (and this script) only on that Windows installation meant only for gaming, 
where you never use your credit card and never edit your security info and which ideally also 
doesn't have access to the hard disks partitions you use for your other Windows installation.

But really, whatever you do, it's up to you and your responsibility to bear the consequences if something goes wrong.

That said, you can use this script to install SECDRV and be quite sure it won't open back doors on your computer
apart from running SECDRV.sys itself (which is a back door itself, and I hate to say I told you so). 

## How does it work?
The instructions below perform the following tasks.
* Install a Windows PowerShell module called SECDRV in your Documents folder, making PowerShell 
commands available to you on your computer with which SECDRV.sys can be controlled and all its prerequisites and
prerequisites for installing it can be installed.
 * Copy some files from GitHub to your computer necessary to do all of the remaining things.
* Run Windows Update to install updates (because if you don't, you might receive errors running the script)
* Download and install a small part of the Windows Standalone SDK for Windows 10 from Windows Dev Center
* Use the Windows SDK to 
 * Create a certificate that is unique to you and your computer
 * Create a signed version of SECDRV.sys using that certificate
 * Install the new certificate as a Trusted Root Certificate
 * Install the new certificate as a Trusted Publisher Certificate
 * Install the signed version of SECDRV.sys on your computer
 * Enabling Windows to load SECDRV by allowing it to load drivers signed with a certificate not chained to 
 a trusted Microsoft Hardware Publisher certificate. (See [What BOOTSIGNING TEST MODE?](docs/BOOTSIGNING.md) for more info)
 
This script does not export the private key used to sign the driver, meaning that noone - not even you - can use this
certificate for say malicious purposes and the certificate is useless for use on any computer but yours.

## How to get rid of it?	
There is no uninstallation option, but you can manually remove all (traces of) this script by:
* Disable and stop SECDRV by copy/pasting this into PowerShell (Administrator)
    ```Stop-SecDrv; Disable-SecDrv```
* Running `cmd /c sc delete secdrv` in a Command Prompt (Administrator) or PowerShell (Administrator)
* Copying `%APPDATA%\Microsoft\UserSecrets\SECDRV` in the File Explorer address bar and deleting that folder
* Copying `%USERPROFILE%\Documents\WindowsPowerShell\Modules\SECDRV` in the File Explorer address bar and deleting that folder
* Copying `%WINDIR%\System32` in the File Explorer address bar and deleting SECDRV.sys.
* Opening `Programs and Features` and uninstalling `Windows Standalone SDK for Windows 10`.
* Rebooting (if SECDRV was running)

You might not be able to remove the Windows Updates installed during installation of SECDRV.sys,
or have to find out how yourself.

## How do I test this without ruining my computer?
By making a new computer!

Seriously, really. And it's not hard if you have Windows Pro.

Read it in the [developer readme](docs/DEV.md).



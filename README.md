# PsSecDrv
PowerShell script and module to install the SECDRV copy protection driver on Windows 10.

## What's this?
PsSecDrv is a bit of PowerShell script that can install SECDRV.sys on a computer running Windows 10, 
eliminating almost all manual steps from this process, apart from starting the script.

To learn a little bit about SECDRV.sys, see `What is SECDRV` below.

## Wow, this readme is long!
OK here's the jump start.

Disable Secure Boot in your BIOS if you have a modern say tablet which is BitLockered without 
you ever having done anything to make it so. SECDRV won't load with Secure Boot enabled.

Right click Start and pick Command Prompt (Administrator). Copy and pass these three lines of text.
```PowerShell 
rem Start
PowerShell -NoExit -ExecutionPolicy RemoteSigned -Command iex (curl "https://raw.githubusercontent.com/ericwj/PsSecDrv/master/src/SECDRV/SECDRV.ps1").Content
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
 a trusted Microsoft Hardware Publisher certificate. (See `What BOOTSIGNING TEST MODE` below for more info)
 
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

* Go to http://insider.windows.com and become a Windows Insider.
* Download a Windows Insider Preview image file (.iso) from http://go.microsoft.com/fwlink/?LinkId=691048
Perhaps this requires using the Media Creation Tool option on that page.
* Enable Hyper-V (only available on Windows 8/8.1/10 Pro)
```PowerShell
$result = Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
if ($result.RestartNeeded) { Restart-Computer -Confirm }```
* Then start `Hyper-V Management`, create a Virtual Machine and select the Windows Insider Preview iso file as the CD to boot from.
* Start the VM and follow the prompts to install Windows in the Virtual Machine
* Once you've figured out you have five seconds to press a key and Windows is installed, go straight to Github
and start copying the snippets above. 

Note that most games won't run very well in a VM and even if they do, you'll need a Generation 1 VM to be able
to use your physical CD's and DVD's inside a VM. However you can test the script without actually using SECDRV.

To really use SECDRV, I recommend using Hyper-V Management to create a VHDX file and setup your computer to boot
from it (only from a virtual Hard Disk, but on your real computer). There's help for that in your favorite search engine.

# What is SECDRV?
SECDRV is a kernel driver in Windows Operating systems. It implements a copy protection technology
commonly referred to as Safe Disc that is used to protect older games from being copied unbridled
and distributed on illegally burnt media or through the Internet, Torrent sites, etc 

However, as a kernel driver, it has complete and unrestricted access to the system on which it is running
once it is installed and instructed to start. This is fine as long as both the way this software works
and the actual implementation is secure and without (known) flaws. However, this is not the case.

Windows 10 eliminates this driver from the operating system, because it has known security issues and is
attack surface for malicious people to enter your computer without your knowledge and do practically anything
they can think of, like seeing you type all your passwords and credit card numbers.

Apart from this, SECDRV is also a relic from a gone era where games were distributed on 
CD's and DVD's. However, the removal of this driver also prevents users who still own legitimate copies of
older games that use this copy protection mechanism from running these games on their Windows 10 computers.

# What is BOOTSIGNING TEST MODE?
All drivers that Windows can load by default must be submitted to Microsoft for Windows Hardware Quality Labs (WHQL)
verification, after which Microsoft signs them (or hands out a means for the creator of the driver to sign the driver)
with a certificate that chains back to a Microsoft Hardware Publisher certificate.

BOOTSIGNING TEST MODE is a way in which Windows computers can boot that turns of the WHQL verification selectively.
It is a means for driver developers (let's say NVIDIA) to let Windows load drivers that are not (yet)
signed by a certificate that chains back to a Microsoft Hardware Publisher certificate. It's meant for testing purposes
and it's enabled or disabled at boot time - when the computer starts, so it's called BOOTSIGNING TEST MODE.
However, drivers must still be signed and the computer must still be told to trust the certificate with which
drivers are signed, before a driver will actually load. Hence, WHQL verification is disabled 'selectively'.

Certificate chaining is the way in which computers can be made to 'trust'. Each chained certificate is checked
by humans - in this case the Microsoft WHQL people - to make sure that the trust that is implied by a certificate 
and acted upon by computers all over the world is actually real. Computers also have a way to 'untrust' lets say
a driver publisher that screws up and whose certificate is compromised. That's called a revocation list. 

Each Windows computer has a list of 
* Trusted Publishers that can publish drivers (let's say NVIDIA), 
* Trusted Root Certification Authorities (Microsoft in this case)
* and a revocation list (including e.g. compromised certificates from DigiCert, to mention an example)

SECDRV.sys can be loaded and started without a WHQL certificate by enabling BOOTSIGNING TEST MODE,
by signing the driver with a certificate and by making Windows trust that certificate both as a software
publisher certificate and as a root certificate (the top of the certificate chain).  

This is a bit of a simplification, but it should give a quick overview of how this security feature works.

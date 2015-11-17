# PsSecDrv
PowerShell script and module to install the SECDRV copy protection driver on Windows 10.

## What's this?
PsSecDrv is a bit of PowerShell script that can install SECDRV.sys on a computer running Windows 10, 
eliminating almost all manual steps from this process, apart from starting the script.

To learn a little bit about SECDRV.sys, see `What is SECDRV` below.

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

This script does not export the private key used to sign the driver, meaning that noone - not even you - can use this
certificate for say malicious purposes and the certificate is useless for use on any computer but yours.

## So How does it really work?
By right-clicking on Start and picking `Command Prompt (Administrator)` and then copy/pasting the following command.

This will only download the latest version of the script to your computer and make it's commands available.

    PowerShell -NoExit -ExecutionPolicy RemoteSigned -Command iex (curl "https://raw.githubusercontent.com/ericwj/PsSecDrv/master/src/SECDRV/SECDRV.ps1").Content
	
To install, enable and start the SECDRV kernel driver service, copy/paste the following.
A future version of the scripts might make this automatic.

    Install-SecDrv
	Enable-SecDrv
	Start-SecDrv 

To stop and disable:

    Stop-SecDrv
	Disable-SecDrv
	
These commands can be copied into text files, saved with file extension .ps1 and be run from the Start Menu.

## How to get rid of it?	
There is no uninstallation option, but you can manually remove all (traces of) this script by:
* Disable and stop SECDRV by copy/pasting this into PowerShell (Administrator)
    `Stop-SecDrv; Disable-SecDrv`
* Running `sc delete secdrv` in a Command Prompt (Administrator) or PowerShell (Administrator)
* Copying `%APPDATA%\Microsoft\UserSecrets\SECDRV` in the File Explorer address bar and deleting that folder
* Copying `%USERPROFILE%\Documents\WindowsPowerShell\Modules\SECDRV` in the File Explorer address bar and deleting that folder
* Copying `%WINDIR%\System32` in the File Explorer address bar and deleting SECDRV.sys.
* Opening `Programs and Features` and uninstalling `Windows Standalone SDK for Windows 10`.
* Rebooting (if SECDRV was running)

You might not be able to remove the Windows Updates installed during installation of SECDRV.sys,
or have to find out how yourself.

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

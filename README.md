# PsSecDrv
*PowerShell* script and module to install the **SECDRV** *Safe Disc* driver on *Windows 10*.

## What's this?
PsSecDrv is a bit of *PowerShell* script that can install **SECDRV.sys** on a computer running Windows 10, 
eliminating almost all manual steps from this process, apart from starting the script.

To learn a little bit about SECDRV.sys, see [What is SECDRV?](docs/SECDRV.md)

## Wow, this readme is long!
OK here's the jump start.

It isn't really safe to use SECDRV, so use it (and by extension, this script) at your own risk!

Disable *Secure Boot* in your BIOS if you have a modern say tablet. SECDRV won't load with Secure Boot enabled.

Right click Start and pick **Command Prompt (Administrator)**. Copy and pass these lines of text. 
Only the second one is important, the others are there to make copy/pasting easier when viewing this on GitHub.
```PowerShell 
rem Start
PowerShell -NoExit -ExecutionPolicy RemoteSigned -Command "$wc = [System.Net.WebClient]::new(); $s = $wc.DownloadString('https://raw.githubusercontent.com/ericwj/PsSecDrv/master/src/SECDRV/SECDRV.ps1'); iex $s"
#rem End
```
PowerShell will have done nothing but copy a few files to your computer (including SECDRV.sys). 
Now copy and paste this, or just type and use `Tab` to auto-complete and cycle through the available options
after typing the first letter or two.
```PowerShell 
Install-SecDrv
```
When that's done, to enable and start SECDRV:
```PowerShell 
Enable-SecDrv
Start-SecDrv 
```
And to stop and disable SECDRV:
```PowerShell 
Stop-SecDrv
Disable-SecDrv
```
These commands can be copied into text files, saved with file extension .ps1 (enable *Show file extensions for known file types* please) 
and be run from the Start Menu. But you might have to open **PowerShell (Administrator)** just once and run the following command before that works.
```PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```
This will cause PowerShell to run scripts saved on your local computer without issue, but block scripts from remote
sources if they don't come from a trusted source.

You landed in **PowerShell**. Type `exit` twice and press Enter twice in an appropriate order to close that Command Prompt (Administrator).

## Why?
I wrote the PowerShell scripts in this repository for several reasons:
* Because this script includes the most recent copy of the driver (that I know of), so I don't have to search for it.
* Because I don't like to use 'third party tools' tools to install SECDRV which are themselves a potential security risk.
* Because I really don't want to tell my computer to trust security certificates for which someone else with potentially 
malicious intent has or could have the private key (there is no way to tell) or which are not under my control. 
* Because I am confident a script (that is plain text more or less in English) available from a public source, open to scrutiny from
knowledgable people, would give everyone including novice users reason to trust that it is safe to just run.
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

I recommend you setup your computer to dual boot. For example using *VHD boot*. And use a **Windows Insider Preview** build
to do that completely legally.

And then use SECDRV (and this script) only on that Windows installation meant only for gaming, 
where you never use your credit card and never edit your security info and which ideally also 
doesn't have access to the hard disks partitions you use for your other Windows installation.

But really, whatever you do, it's up to you and your responsibility to bear the consequences if something goes wrong.

That said, you can use this script to install SECDRV and be quite sure it won't open back doors on your computer
apart from running SECDRV.sys itself (which is a back door itself, and I hate to say I told you so).

All complaints aside, even if you believe the theories that Microsoft has other, economic reasons 
to remove SECDRV from Windows 10, this one is really good and enough all by itself.
The objective might have been to make Windows 10 as secure as it can be and allowing no excuses to compromise that goal.
That holds even if Windows 10 isn't quite perfectly secure. 
Leaving a known security hole open is quite stupid from a security perspective...so Microsoft has been quite 
stupid for quite a while only to make us gamers happy, which has been appreciated without thinking about it by most of us reading this.

Kudo's to Microsoft! ;)   

## How does it work?
The script downloads SECDRV.sys from [PsSecDrv](https://www.github.com/ericwj/PsSecDrv) on GitHub.
It then downloads and installs the Windows SDK and uses it to create a certificate unique to your computer,
sign the driver, makes Windows trust that certificate and enabling Windows to load SECDRV.sys, registering
the driver. 

However, this does not completely install SECDRV.
To complete the process, you need to run the setup program of a game that uses Safe Disc.
You might be done if you had done that before running this script. Poke me if you aren't.

### More detailed inner workings
In more detail, the scripts perform the following tasks.
* Copy some files from GitHub to your computer necessary to do all of the remaining things.
* Run Windows Update to install updates (because if you don't, you might receive errors running the script)
* Download and install a small part of the **Windows Standalone SDK for Windows 10** from [Windows Dev Center](https://dev.windows.com)
* Use the Windows SDK to 
 * Create a certificate that is unique to you and your computer.
   To proof that, its subject contains your computer name, user name and the time at which the certificate was created.
 * Create a signed version of SECDRV.sys on your computer using that certificate
 * Install the new certificate as a Trusted Root Certificate on your computer
 * Install the new certificate as a Trusted Publisher Certificate on your computer
 * Install the signed version of SECDRV.sys on your computer
 * Enabling Windows on your computer to load SECDRV by allowing it to load drivers that are signed, but not with a certificate chained to 
 a trusted Microsoft Hardware Publisher certificate. (See [What is BOOTSIGNING TEST MODE?](docs/BOOTSIGNING.md) for more info)
 
This script does not export the private key used to sign the driver, nor does it allow the private key to be exported,
meaning that noone can use this certificate for say malicious purposes and the certificate is useless for use on any computer 
but yours. That means attackers need to run code with Administrator privileges on your computer in order to use your private key.

It is however still a risk to have BOOTSIGNING TEST MODE continuously enabled, since it takes only one careless
click on **Yes** too many when Windows prompts you **Do you want to allow Lief Roodkapje to make changes to your computer?**
for something you don't trust at all to add certificates to your Trusted Publishers list and you'll be loading
kernel drivers from wherever Roodkapje's EVIL TWIN came from, sending your credit card info to Nigeria 
without anyone noticing before the money is gone.

Sounds stupid and you'd never do it. So that's why this script is on GitHub for you to use.

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

This will also leave the certificate created for SECDRV.sys on your computer, but only in the system managed
certificate store - not in a file on disk. I could tell you how to delete it, but it's risky - you might delete
certificates that Windows needs to run. Well you'd never do that, right? So here goes. 

Copy paste these lines into **PowerShell (Administrator)**:

```PowerShell
$certs = dir cert: -Recurse | where Subject -Like "*SECDRV.sys*" | select Thumbprint -Unique | {
    del "Cert:\LocalMachine\Root\$($_.Thumbprint)" -ErrorAction Continue
    del "Cert:\LocalMachine\TrustedPublisher\$($_.Thumbprint)" -ErrorAction Continue
}
```
This might produce some red text but that's not really a problem - it tried to delete certificates that didn't exist.

## How to update?
If you have PowerShell open and ran `Install-SecDrv` or another command in the SECDRV PowerShell Module, run this.

```PowerShell
Remove-Module SECDRV
```

Or just close and reopen PowerShell.

Then start reading and following instructions at the top of the page, without first 'getting rid of it'.

This will overwrite the SECDRV PowerShell Module and the SECDRV.sys file (with an identical file most likely)
so that you can be sure that what you'll be doing next is with a fresh copy that nobody could have touched.

This won't delete any certificate files, driver signing catalogs, none of that. If you had SECDRV installed fine
before doing this, it'll still be installed fine.

If you want to recreate another certificate, you can do that without deleting the current certificate by poking
around in the commands that the SECDRV PowerShell module exports and their switches and arguments.
So with say `Get-Help Install-SecDrv -Detailed` or with `Get-Help Enable-SecDrv` 
or whichever other command you'd like to learn more about. To see what's available,
use `Get-Command -Module SECDRV` or browse the source code.

## How do I test this without ruining my computer?
By making a new computer!

Seriously, really. And it's not hard if you have Windows Pro.

Read it in the [developer readme](docs/DEV.md).



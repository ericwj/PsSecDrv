# How do I test this without ruining my computer?
By making a new computer!

Seriously, really. And it's not hard if you have Windows Pro.

## Get Setup
* Go to http://insider.windows.com and become a Windows Insider.
* Download a Windows Insider Preview image file (.iso) from http://go.microsoft.com/fwlink/?LinkId=691048
Perhaps this requires using the Media Creation Tool option on that page.
* Enable Hyper-V (only available on Windows 8/8.1/10 Pro)

        $result = Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
        if ($result.RestartNeeded) { Restart-Computer -Confirm }

## Create a Virtual Machine and Install Windows on it
* Then start `Hyper-V Management`, create a Virtual Machine and select the Windows Insider Preview iso file as the CD to boot from.
* Start the VM and follow the prompts to install Windows in the Virtual Machine
* Once you've figured out you have five seconds to press a key and Windows is installed, go straight to Github
and start copying the snippets above. 

Note that most games won't run very well in a VM and even if they do, you'll need a Generation 1 VM to be able
to use your physical CD's and DVD's inside a VM. Whether your VM is a Generation 1 or Generation 2 VM is
just an option to pick while making a new VM. However you can test the script without actually using SECDRV. 

## Install a game that uses SECDRV
Note however that the script doesn't install the driver service completely.
You need to run the setup program of a game which uses the driver to do that.

* I made a copy of a game using [Folder2Iso](http://www.trustfm.net/software/utilities/Folder2Iso.php)
* Make sure to use copy/paste the CD labels so they match the original CD's
* Those can be mounted in a virtual CD-ROM drive and used to install the game (but a VM might not play it)
* After that you can test whether SECDRV works by setting the driver to auto start ```Enable-SecDrv -AutoStart``` and rebooting
* You can also run ```Start-SecDrv``` and ```cmd /c sc query secdrv``` to see if SECDRV works 

I used `Command and Conquer: Generals` (both CD's) with labels `GENERALS1` and `GENERALS2` respectively.

## VHD Boot for actual gaming
To really use SECDRV, I recommend using Hyper-V Management to create a VHDX file and setup your computer to boot
from it (only from a virtual Hard Disk, but on your real computer). There's help for that in your favorite search engine.
Search for VHD boot. Make sure you have a partition that is large enough and not encrypted to put the virtual hard disk on.
Even if the disk is a dynamically expanding disk, booting from it requires that it is inflated to the maximum size you specified.
A minimum of 20GB is recommended to install Windows 10 Pro.

## Options for testing the script and making changes without committing on GitHub
The scripts use a convention introduced in [ASP.NET 5](https://www.github.com/aspnet/) which is useful for storing
machine specific configuration and secretive stuff (like certificate files). Okay well, maybe I misuse the feature a little,
but the idea is just to keep the scripts and its configuration separate and the certificate it creates secret for as far as
necessary.

The script can be configured by creating the directory `%APPDATA%\Microsoft\UserSecrets\SECDRV` and creating an empty
file called `secrets.json` in it. You can then configure a few options like so:

```JSON
{
    "OriginSite": "file:////COMPUTERNAME/C$/PathToRepoDirectory",
    "DevPath": "\\\\COMPUTERNAME\C$\PathToRepoDirectory"
    "Verbose": true,
    "Confirm": true
}
```

Where
* `OriginSite` is an URL (hence `file:`) where SECDRV.ps1 will download the module files and SECDRV.sys from.
* `DevPath` is a path (hence in UNC notation \\COMPUTER\Share\Path) that contains a copy of the files installed
with the Windows 10 SDK necessary to install SECDRV (so with some tweaking you don't have to install the SDK on a test machine).
The list of files is the `$ToolsManifest` in `SECDRV.psm1`.
* `Verbose` will set PowerShell `$VerbosePreference` (only in the bootstrap script SECDRV.ps1) used to generate more output in PowerShell to see what the script does.
* `Confirm` will set PowerShell `$ConfirmPreference` (only in the bootstrap script SECDRV.ps1) used to do prompting before doing potentially irreversible stuff.

Both `OriginSite` and `DevPath` should point to the folder containing the `src` and `Tools` subfolders in this repository and ultimately `SECDRV.psm1`, `SECDRV.psd1` and `SECDRV.sys`.  

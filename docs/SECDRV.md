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

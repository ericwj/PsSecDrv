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

These lists are updated by humans (at Microsoft) and then pushed to millions of computers using Windows Update.

SECDRV.sys can be loaded and started without a WHQL certificate by enabling BOOTSIGNING TEST MODE,
by signing the driver with a certificate and by making Windows trust that certificate both as a software
publisher certificate and as a root certificate (the top of the certificate chain).  

This is a bit of a simplification, but it should give a quick overview of how this security feature works.

class SecDrvModule {
    static [guid]$Guid = [guid]::new("{c8da5d77-b7cf-40a4-9cc8-240f6013a1fd}")
    static [string]$Description = "Setup and removal of SECDRV.sys on Windows 10."
    static [string]$Author = "Eric Jonker"
    static [Version]$Version = [version]::Parse("1.0.0.1")
    static [string[]]$Scripts = @("SECDRV.ps1", "SECDRV.psm1")
}
if (!(Test-Path SECDRV.sys)) {
    throw [System.IO.FileNotFoundException]::new("SECDRV.sys not found. Change the current directory.")
}

New-ModuleManifest -Path .\SECDRV.psd1 `
    -Author ([SecDrvModule]::Author) -CompanyName None `
    -ModuleVersion ([SecDrvModule]::Version) `
    -Description ([SecDrvModule]::Description) `
    -Guid ([SecDrvModule]::Guid) `
    -PowerShellVersion 5.0 -ClrVersion 4.0 -DotNetFrameworkVersion 4.0 `
    -ProcessorArchitecture None `
    -RootModule SECDRV `
    -FunctionsToExport Install-SecDrv
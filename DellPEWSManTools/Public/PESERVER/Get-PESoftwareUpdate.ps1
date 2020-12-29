function Get-PESoftwareUpdate
{
    [CmdletBinding(DefaultParameterSetName='iDRACSession')]
    # [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [Parameter(Mandatory, ParameterSetName='iDRACSession')]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $iDRACSession
        ,
        [string]
        $DellCatalog  = "https://downloads.dell.com/Catalog/Catalog.gz"
        ,
        [string]
        $UpdateStageFolder = "$env:temp\DellUpdates\"
        ,
        [switch]
        $AllowUnsupported
        ,
        [Parameter(Mandatory, ParameterSetName='SoftwareInventory')]
        [Parameter(HelpMessage='Output from Get-PESoftwareInventory')]
        $PESoftwareInventory
        ,
        [Parameter(Mandatory, ParameterSetName='SoftwareInventory')]
        [Parameter(HelpMessage='Output from (Get-PESystemInformation).SystemID')]
        [int]
        $SystemID
        ,
        [ValidateSet("LIN","WIN64")]
        [String]
        $osCode = "LIN"
        ,
        [ValidateSet("LLXP","LW64")] # LLXP = Linux/BIN   LW64 = Windows64
        [String]
        $packageType = 'LW64'
    )

    Begin {
    }
    Process
    {
        if ($PSCmdlet.ParameterSetName -eq 'iDRACSession') {
            Write-Verbose "Get-PESoftwareInventory"
            $PESoftwareInventory = (Get-PESoftwareInventory -iDRACSession $iDRACSession -Installed)
            $SystemID = (Get-PESystemInformation -iDRACSession $iDRACSession).SystemID
        }

        Write-Verbose "Getting Dell Catalog"
        $XmlCatalog = Get-DellCatalog -UpdateStageFolder $UpdateStageFolder -DellCatalog $DellCatalog
        Write-Verbose "Comparing Inventory to Catalog "
        Write-Verbose "Version $($XmlCatalog.Manifest.version)"
        Write-Verbose "SystemID - $SystemID"
        $systemIDhex = '{0:X4}' -f [int]$SystemID
        Write-Verbose "systemIDhex - $systemIDhex"

        # $SoftwareBundle = $XmlCatalog.SelectNodes("/Manifest/SoftwareBundle[TargetSystems/Brand/Model/@systemID='$systemIDhex' and TargetOSes/OperatingSystem/@osCode='$osCode']")
        # $SoftwareBundle.Contents.Package

        foreach ($Device in $PESoftwareInventory){
            Write-Verbose "Checking '$($Device.ComponentType) - $($Device.ElementName)'"

            if ($Device.ComponentID) {
                $Filter = "ComponentType/@value='$($Device.ComponentType)'"
                $Filter += " and SupportedDevices/Device/@componentID='$($Device.ComponentID)'"
            } elseif ($Device.DeviceID) {
                $Filter = "ComponentType/@value='$($Device.ComponentType)'"
                $Filter += " and SupportedDevices/Device/PCIInfo/@vendorID='$($Device.VendorID)'"
                $Filter += " and SupportedDevices/Device/PCIInfo/@deviceID='$($Device.DeviceID)'"
                $Filter += " and SupportedDevices/Device/PCIInfo/@subVendorID='$($Device.SubVendorID)'"
                $Filter += " and SupportedDevices/Device/PCIInfo/@subDeviceID='$($Device.SubDeviceID)'"
            }
            Write-Verbose "  Device Filter : '$($Filter)'"
            $Update = $XmlCatalog.SelectNodes("/Manifest/SoftwareComponent[$Filter]")
            # if updates are found for Device
            if ($Update.count -ge 1) {
                # Determine if there are updates appoved for the current server model
                if ($Update | Where-Object {($_.packageType -eq $packageType) -and ($_.SupportedSystems.Brand.Model.systemID -contains $systemIDhex)}) {
                    Write-Verbose "    SupportedUpdate - True"
                    $SupportedUpdate = $True
                    $Update = $Update | Where-Object {($_.packageType -eq $packageType) -and ($_.SupportedSystems.Brand.Model.systemID -contains $systemIDhex)}
                } else {
                    Write-Verbose "    SupportedUpdate - False $($Update.Count)"
                    $SupportedUpdate = $False
                    if ($Update | Where-Object {$_.SupportedSystems.Brand.Model.systemID -contains $systemIDhex}) {
                        $Update = $Update | Where-Object {$_.SupportedSystems.Brand.Model.systemID -contains $systemIDhex}
                        Write-Verbose "    SupportedSystems - $($Update.Count)"
                    }
                    if ($Update | Where-Object {$_.packageType -eq $packageType}) {
                        $Update = $Update | Where-Object {$_.packageType -eq $packageType}
                        Write-Verbose "     packageType - $($Update.Count)"
                    }
                }
                if ($Update.Count -gt 1) {
                    if       (-not ($Update.dellVersion   -notmatch '^(\D)(\d\d)$'                  )) {
                        # Example A00
                        $Update = $Update | Sort-Object {[String]  $_.dellVersion  } | Select-Object -Last 1
                    } elseif (-not ($Update.dellVersion   -notmatch '^\d+\.\d+(?>\.\d+)?(?>\.\d+)?$')) {
                        # Example 1.2 , 1.2.3 , 1.2.3.4
                        $Update = $Update | Sort-Object {[Version] $_.dellVersion  } | Select-Object -Last 1
                    } elseif (-not ($Update.vendorVersion -notmatch '^\d+\.\d+(?>\.\d+)?(?>\.\d+)?$')) {
                        # Example 1.2 , 1.2.3 , 1.2.3.4
                        $Update = $Update | Sort-Object {[Version] $_.vendorVersion} | Select-Object -Last 1
                    } else {
                        # This is lazy way of handling dells inconsistent versioning. Just assuming newest update was released last
                        $Update = $Update | Sort-Object {[DateTime]$_.releaseDate  } | Select-Object -Last 1
                    }
                }

                Write-Verbose "  $($Device.VersionString) -eq $($Update.vendorVersion)"
                if ($Device.VersionString -eq $Update.vendorVersion) {
                    Write-Verbose "    Firmware Up To Date"
                } else {
                    if ($SupportedUpdate -or $AllowUnsupported) {
                        Write-Verbose "    Firmware Up Date Needed"
                        $Update | Add-Member -MemberType NoteProperty -Name Device -Value $Device -force
                        $Update
                    } else {
                        # $Update | FL | Out-String | Write-Host -ForegroundColorCyan
                        Write-Verbose "    Unsupported Update Found`n    $($Update.path)`n    $($Update.Description.Display.'#cdata-section')"
                    }
                }
            } else {
                Write-Verbose "    No Firmware Found For Device"
            }
        }
    }
}


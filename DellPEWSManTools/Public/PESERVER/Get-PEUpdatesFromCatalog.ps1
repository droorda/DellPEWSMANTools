<#
Get-PEUpdatesFromCatalog.ps1 - Gets info from the ESX host via WSMan API

_author_ = Douglas Roorda _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Get-PEUpdatesFromCatalog {
    <#
    .SYNOPSIS
    Describe the function here
    .DESCRIPTION
    Describe the function in more detail
    .EXAMPLE
    Give an example of how to use it
    .EXAMPLE
    Give another example of how to use it
    .PARAMETER computername
    The computer name to query. Just one.
    .PARAMETER logname
    The name of a file to write failed computer names to. Defaults to errors.txt.
    #>
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='Low')]
    param
    (
        [Parameter(
            Mandatory=$True,
            HelpMessage='Output from Get-PESoftwareInventory')]
        $SoftwareIdentity,

        [Parameter(
            Mandatory=$True,
            HelpMessage='Output from (Get-PESystemInformation).SystemID')]
        [int]
        $SystemID,

        [string]
        $SourceServer  = "https://downloads.dell.com/",

        # https://www.dell.com/support/article/en-us/sln312282/dell-emc-catalog-links-for-poweredge-servers?lang=en
        # TODO:switch to correct catalog 'Catalog.gz'
        [string]
        $SourceCatalog = "${SourceServer}Catalog/Catalog.xml.gz",

        [string]
        $UpdateStageFolder = "$env:temp\DellUpdates\",

        [switch]
        $AllowUnsupported
    )

    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }
        $inFile  = "${UpdateStageFolder}Catalog.xml.gz"
        $outFile = ($infile -replace '\.gz$','')
        get-item $inFile  -ErrorAction SilentlyContinue | Remove-Item

        $Devices = $SoftwareIdentity.clone()

        try {
            $remoteLastModified = [System.Net.HttpWebRequest]::Create("$SourceCatalog").GetResponse().LastModified -as [DateTime]
        } catch {
            try {
                $remoteLastModified = [System.Net.HttpWebRequest]::Create("$SourceCatalog").GetResponse().LastModified -as [DateTime]
            } catch {
                Write-Verbose $_
                throw "Unable to Check for latest Version of $SourceCatalog"
            }
        }

        if (-not (Test-Path $UpdateStageFolder)){
            New-Item $UpdateStageFolder -type directory | Write-Verbose
        }

        if (Test-Path $outFile){
            Write-Verbose "Age difference of cached catalog $([int]($remoteLastModified - (Get-Item $outFile).LastWriteTime).Totalhours) hr"
            if ([int]($remoteLastModified - (Get-Item $outFile).LastWriteTime).Totalhours -gt 1){
                Remove-Item $outFile -ErrorAction Continue
            } else {
                Write-Verbose "Using Cached Catalog.xml"
            }
        }

        if (-not (Test-Path $outFile)){
            Write-Verbose "Downloading $SourceCatalog"
            try {
                (New-Object System.Net.WebClient).DownloadFile($SourceCatalog,$inFile)
            } catch {
                Write-Warning "Unable to download the Dell Catalog, Will Retry"
                Start-Sleep -s 300
                try {
                    (New-Object System.Net.WebClient).DownloadFile($SourceCatalog,$inFile)
                } catch {
                    Write-Verbose $_
                    throw "Unable to download the Dell Catalog"
                }
            }
            Expand-GZip -FullName $inFile -NewName $outFile
            Remove-Item $inFile -ErrorAction SilentlyContinue
            (Get-Item "$outFile").CreationTime   = $remoteLastModified
            (Get-Item "$outFile").LastAccessTime = $remoteLastModified
            (Get-Item "$outFile").LastWriteTime  = $remoteLastModified
        #    Remove-Item $outFile -ErrorAction SilentlyContinue
        }
        [xml]$XmlCatalog = Get-Content -Path $outFile
        $XmlSoftwareComponent = $XmlCatalog | Select-XML -Xpath "//Manifest/SoftwareComponent" | Select-Object -ExpandProperty "node"
        if (([int]((get-date) - $remoteLastModified).TotalDays) -gt 45){
            write-Warning "DellCatalog is $([int]((get-date) - $remoteLastModified).TotalDays) Days old"
        } else {
            Write-Verbose "Catalog is $([int]((get-date) - $remoteLastModified).TotalDays) Days old"
        }
        Write-Verbose "Comparing Inventory to Catalog "
        Write-Verbose "Version $($XmlCatalog.Manifest.version)"
        $systemIDhex = '{0:X4}' -f [int]$SystemID
        Write-Verbose "systemIDhex - $systemIDhex"
        $Devices = $SoftwareIdentity.clone()
        foreach ($Device in $Devices){
            Write-Verbose "$($Device.ComponentType) - $($Device.ElementName)"
            if ($Device.IdentityInfoType -eq 'CIM_SoftwareFamily'){
                if ($Device.ComponentID){
                    $IdentityInfoType  = 'OrgID:ComponentType:ComponentID'.Split(':')
                    $IdentityInfoValue = $Device.IdentityInfoValue.Split(':')
                } else {
                    $IdentityInfoType  = 'OrgID:ComponentType:VendorID:DeviceID:SubVendorID:SubDeviceID'.Split(':')
                    $IdentityInfoValue = $Device.IdentityInfoValue.Split(':')
                }
            } else {
                $IdentityInfoType  = $Device.IdentityInfoType.Split(':')
                $IdentityInfoValue = $Device.IdentityInfoValue.Split(':')
            }
            $Device | Add-Member -MemberType NoteProperty -Name Update -Value $Null
            $Device | Add-Member -MemberType NoteProperty -Name UpdateAvailible -Value $False

            if (($IdentityInfoType[0] -eq 'OrgID') -and ($IdentityInfoValue[0] -eq 'DCIM')) {
                if ($IdentityInfoType[1] -eq 'ComponentType') {
                    $Update = $XmlSoftwareComponent.Clone() | Where-Object {$_.ComponentType.value -eq $Device.ComponentType}
                } else {
                    Write-Warning "Unknown Type Filter '$($IdentityInfoType[1]))'"
                    continue
                }
            } else {
                Write-Warning "Unknown Identity Info Type/Value: '$($IdentityInfoType[0]) = $($IdentityInfoType[0])'"
                continue
            }
            if ($IdentityInfoType[2] -eq 'ComponentID') {
                $Update = $Update | Where-Object {$_.SupportedDevices.Device.ComponentID         -eq $Device.ComponentID}
            } else {
                for($i=2; $i -lt $IdentityInfoType.count; $i++){
                    if ($Device.$($IdentityInfoType[$i])) {
                        Write-Verbose "  $($IdentityInfoType[$i]) = $($Device.$($IdentityInfoType[$i]))"
                        $Update = $Update | Where-Object {$_.SupportedDevices.Device.PCIInfo.$($IdentityInfoType[$i]) -eq $($Device.$($IdentityInfoType[$i]))}
                    } else {
                        Write-Verbose "  $($IdentityInfoType[$i]) = $($IdentityInfoValue[$i])"
                        # May be needed, but only instance found that may use is extra ports on 'Intel(R) Ethernet 10G 4P X710'
                        # $Update = $Update | Where-Object {$_.SupportedDevices.Device.PCIInfo.$($IdentityInfoType[$i]) -eq $IdentityInfoValue[$i]}
                        $Update = $null
                    }
                }
            }
            # $Update = $Update           | Where-Object {$_.packageType                                 -eq 'LW64'}
            Write-Verbose "Update Count 1: $($Update.count)"
            if ($Update){
                $SupportedUpdate = $Update               | Where-Object {$_.SupportedSystems.Brand.Model.systemID       -eq $systemIDhex}
                if ($SupportedUpdate){
                    $Update = $SupportedUpdate
                    $SupportedUpdate = $null
                    $Update | Add-Member -MemberType NoteProperty -Name Supported -Value $True -Force
                } else {
                    Try {
                        $Update = $Update | Sort-Object {[version]$_.vendorVersion} -ErrorAction Stop | Select-Object -last 1
                    } Catch {
                        Try {
                            $Update = $Update | Sort-Object {[dateTime]$_.dateTime} -ErrorAction Stop | Select-Object -last 1
                        } Catch {
                            Write-Verbose $_
                            # $Update | Out-String | Write-Verbose
                        }
                    }
                    $Update | Add-Member -MemberType NoteProperty -Name Supported -Value $False -Force
                }
            }
            #Try to Filter Downgrade options if multiple exist
            if ($Update.count -gt 1){
                $Update = $Update | Where-Object {(Compare-PEUpdateVersion -Update $_ -Device $Device) -ge 0}
            }
            if ($Update.count -gt 1){
                $Update = $Update | Where-Object {(Compare-PEUpdateVersion -Update $_ -Device $Device) -gt 0}
            }
            #Process Found Updates
            if ($Update.count -gt 1){
                write-Warning "$($Update.count) matches Found for $($Device.ElementName)"

                Write-Verbose " ServiceTag        : '$($Server.systemview.ServiceTag)'" -verbose
                Write-Verbose " IdentityInfoType  : '$($Device.IdentityInfoType)'" -verbose
                Write-Verbose " IdentityInfoValue : '$($Device.IdentityInfoValue)'" -verbose
                Write-Verbose " ComponentType     : '$($Device.ComponentType)'" -verbose
                Write-Verbose " SystemIDhex       : '$systemIDhex'" -verbose
                Write-Verbose " ComponentID       : '$($Device.ComponentID)'" -verbose
                Write-Verbose " vendorID          : '$($Device.vendorID)'" -verbose
                Write-Verbose " subVendorID       : '$($Device.subVendorID)'" -verbose
                Write-Verbose " deviceID          : '$($Device.deviceID)'" -verbose
                Write-Verbose " subDeviceID       : '$($Device.subDeviceID)'" -verbose
                Write-Verbose " ElementName       : '$($Device.ElementName)'" -verbose
                Write-Verbose " VersionString     : '$($Device.VersionString)'" -verbose
                # $Device | Format-List *   | Out-String | Write-Verbose
                $Update | Format-Table -a | Out-String | Write-Verbose
                # $Update | Format-List     | Out-String | Write-Verbose
                $Update = $null
                # $Update
            } elseif ($Update) {
                Write-Verbose "  Update $($Device.ComponentType) Version $($Update.vendorVersion)"
                Write-Verbose "    $($Update.path)"

                $Device.Update = $Update
                if ((Compare-PEUpdateVersion -Update $Update -Device $Device) -gt 0){
                    if ($Device.Update.Supported){
                        Write-Verbose "  Supported Update Found"
                        $Device.UpdateAvailible = $true
                    } elseif ($UnsupportedUpdate){
                        Write-Verbose "  UnSupported Update Found"
                        $Device.UpdateAvailible = $true
                    } else {
                        Write-Verbose "      Possible Hardware update found for '$($Device.ElementName)' Version:$($Device.VersionString)"
                        Write-Verbose "        Update $($Device.Update.releaseID) Version:$($Device.Update.vendorVersion)"
                        $Device.Update = $Null
                        $Device.UpdateAvailible = $False
                    }
                }

            } else {
                Write-Verbose " ---------------------------------------------------"
                Write-Verbose " $($Device.ElementName) Updates not availible"
                Write-Verbose " ServiceTag    $($Server.systemview.ServiceTag)"
                Write-Verbose " ComponentType $($Device.ComponentType)"
                Write-Verbose " SystemIDhex   $systemIDhex "
                Write-Verbose " ComponentID   $($Device.ComponentID)"
                Write-Verbose " vendorID      $($Device.vendorID)"
                Write-Verbose " subVendorID   $($Device.subVendorID)"
                Write-Verbose " deviceID      $($Device.deviceID)"
                Write-Verbose " subDeviceID   $($Device.subDeviceID)"
                Write-Verbose " ElementName   $($Device.ElementName)"
                Write-Verbose " VersionString $($Device.VersionString)"
            }
        }
        $Devices
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}

<#
Get-PEBIOSAttribute.ps1 - Gets a list of BIOS attributes

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_Updated_= Doug Roorda <droorda at gmail.com> = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

function Get-PEBIOSAttribute
{
    [CmdletBinding(DefaultParameterSetName='None')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        [Parameter(ParameterSetName='AttributeDisplayName')]
        [String] $AttributeDisplayName,

        [Parameter(ParameterSetName='AttributeName')]
        [String] $AttributeName,

        [Parameter()]
        [String] $GroupDisplayName
    )

    Begin
    {
        #$CimOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
    }

    Process
    {
        Write-Verbose "Retrieving PEBIOS attribute information ..."
        $filter = $null
        if ($GroupDisplayName) {
                $filter =             "GroupDisplayName='$GroupDisplayName'"
        }
        if ($AttributeName) {
            if ($filter){
                $filter = "$filter AND AttributeName='$AttributeName'"
            } else {
                $filter =             "AttributeName='$AttributeName'"
            }
        }
        if ($AttributeDisplayName) {
            if ($filter){
                $filter = "$filter AND AttributeDisplayName='$AttributeDisplayName'"
            } else {
                $filter =             "AttributeDisplayName='$AttributeDisplayName'"
            }
        }
        if ($filter) {
            Write-Verbose "Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_BIOSEnumeration -Namespace root\dcim -Filter ""$filter"" -ErrorAction Stop"
            try {
                Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_BIOSEnumeration -Namespace root\dcim -Filter "$filter" -ErrorAction Stop
            } catch {
                try {
                    Start-Sleep -s 5
                    Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_BIOSEnumeration -Namespace root\dcim -Filter "$filter" -ErrorAction Stop
                } catch {
                    Write-warning "Get-PEBIOSAttribute Failed : $($_.Exception.Message)"
                }
            }

        } else {
            Write-Verbose "Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_BIOSEnumeration -Namespace root\dcim -ErrorAction Stop"
            Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_BIOSEnumeration -Namespace root\dcim -ErrorAction Stop
        }
    }

    End
    {

    }
}

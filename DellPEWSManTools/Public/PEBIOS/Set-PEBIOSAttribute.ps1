<#
Set-PEBIOSAttribute.ps1 - Sets BIOS attributes

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_Updated_= Doug Roorda <droorda at gmail.com> = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Set-PEBIOSAttribute
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        [Parameter()]
        [String] $AttributeName,

        [Parameter()]
        [String[]] $AttributeValue
    )

    Begin
    {
        #$CimOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
        $properties=@{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_BIOSService";Name="DCIM:BIOSService";}
        $instance = New-CimInstance -ClassName DCIM_BIOSService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties
    }

    Process
    {
        if ($PSCmdlet.ShouldProcess($($iDRACSession.ComputerName),'Set BIOS attribute'))
        {
            #Check if the attribute is settable.
            $attribute = Get-PEBIOSAttribute -iDRACSession $iDRACSession -AttributeName $AttributeName #-Verbose

            if ($attribute)
            {
                if ($attribute.CurrentValue -eq $AttributeValue) {
                    Write-warning -Message "Current Value is already correct"
                    return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                }
                if ($attribute.PendingValue -eq $AttributeValue) {
                    Write-warning -Message "Pending Value is already correct"
                    return [PSCustomObject]@{Result = $true ; RebootRequired  = $true}
                }
                if ($attribute.IsReadOnly -eq $true) {
                    Write-warning -Message "${AttributeName} is readonly and cannot be configured."
                    return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                }

                Write-Verbose "setting PEBIOS attribute information ..."

                #Check if the AttributeValue falls in the same set as the PossibleValues by calling the helper function
                if (TestPossibleValuesContainAttributeValues -PossibleValues $attribute.PossibleValues -AttributeValues $AttributeValue )
                {
                    if ($PSCmdlet.ShouldProcess($AttributeValue, 'Set BIOS attribute'))
                    {
                        try
                        {
                            $params = @{
                                'Target'         = 'BIOS.Setup.1-1'
                                'AttributeName'  = $AttributeName
                                'AttributeValue' = $AttributeValue
                            }
                            $responseData = Invoke-CimMethod -InputObject $instance -MethodName SetAttribute -CimSession $iDRACsession -Arguments $params
                            if ($responseData.ReturnValue -eq 0)
                            {
                                Write-Verbose -Message 'BIOS attribute configured successfully'
                                if ($responseData.RebootRequired -eq 'Yes')
                                {
                                    Write-Verbose -Message 'BIOS attribute change requires reboot.'
                                }
                            }
                            else
                            {
                                Write-Warning -Message "BIOS attribute change failed: $($responseData.Message)"
                            }
                        }
                        catch
                        {
                            Write-Error -Message $_
                        }
                    }
                }
                else
                {
                    Write-warning -Message "Attribute value `"${AttributeValue}`" is not valid for attribute ${AttributeName}."
                }
            }
            else
            {
                Write-Verbose "Get-PEBIOSAttribute -iDRACSession $iDRACSession -AttributeName $AttributeName -Verbose"
                Write-Verbose "$(Get-PEBIOSAttribute -iDRACSession $iDRACSession -AttributeName $AttributeName -Verbose)"
                Write-Error -Message "${AttributeName} does not exist in PEBIOS attributes."
            }
        }
        return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
    }

    End
    {

    }
}
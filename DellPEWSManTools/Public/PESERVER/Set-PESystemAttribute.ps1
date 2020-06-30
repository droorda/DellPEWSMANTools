<#
Set-PELCAttribute.ps1 - Sets PE system LC attribute.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Set-PESystemAttribute {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='low')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        # Sepcify the name of the attribute name to be set
        [Parameter(Mandatory)]
        [String] $AttributeName,

        # Sepcify the GroupID of the attribute name to be set
        [Parameter()]
        [String] $GroupID,

        # Pending or Current value to be set
        [Parameter(Mandatory)]
        [String[]] $AttributeValue
    )

    Begin {
        $properties= @{SystemCreationClassName="DCIM_ComputerSystem";SystemName="srv:system";CreationClassName="DCIM_SystemManagementService";Name="DCIM:SystemManagementService";}
        $instance = New-CimInstance -ClassName DCIM_SystemManagementService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties
    }

    Process {
        #Check if the attribute is settable.
        $attribute = Get-PESystemAttribute -iDRACSession $iDRACSession -GroupID $GroupID -AttributeName $AttributeName #-Verbose

        if ($attribute) {
            if ($attribute.IsReadOnly -ne 'false') {
                Write-Error -Message "${AttributeName} is readonly and cannot be configured."
                return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
            }
        } else {
            Write-Error -Message "${AttributeName} does not exist in System attributes."
            return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
        }

        #Check if the AttributeValue falls in the same set as the PossibleValues by calling the helper function

        if ($attribute.PossibleValues){
            if ( -not (TestPossibleValuesContainAttributeValues -PossibleValues $attribute.PossibleValues -AttributeValues $AttributeValue)) {
                Write-Error -Message "Attribute value `"${AttributeValue}`" is not valid for attribute ${AttributeName}."
                return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
            }
        } else {
            Write-Verbose "PossibleValues blank, skipping check"
        }

        if ($PSCmdlet.ShouldProcess($AttributeValue, 'Set System attribute')) {
            Write-Verbose "setting System attribute information ..."
            try {
                $params = @{
                    'Target'         = 'System.Embedded.1'
                    'AttributeValue' = $AttributeValue
                }
                if ($GroupID) {
                    $params.AttributeName = "$GroupID#$AttributeName"
                } else {
                    $params.AttributeName = $AttributeName
                }
                write-verbose "Invoke-CimMethod -InputObject $instance -MethodName SetAttribute -CimSession $iDRACsession -Arguments $params"
                $responseData = Invoke-CimMethod -InputObject $instance -MethodName SetAttribute -CimSession $iDRACsession -Arguments $params
                if ($responseData.ReturnValue -eq 0) {
                    Write-Verbose -Message 'System attribute configured successfully'
                    if ($responseData.RebootRequired -eq 'Yes') {
                        Write-Verbose -Message 'System attribute change requires reboot.'
                        return [PSCustomObject]@{Result = $true  ; RebootRequired  = $true}
                    }
                    return [PSCustomObject]@{Result = $true  ; RebootRequired  = $false}
                } else {
                    Write-Warning -Message "System attribute change failed: $($responseData.Message)"
                    return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                }
            } catch {
                Write-Error -Message $_
            }
        }
    }

    End {
    }
}


<#
Set-PEBIOSAttribute.ps1 - Sets BIOS attributes

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_Updated_= Doug Roorda <droorda at gmail.com> = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Set-PEDRACAttribute {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        
        # Sepcify the name of the attribute name to be set
        [Parameter()]
        [String] $GroupID,

        # Sepcify the name of the attribute name to be set
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $AttributeName,

        # Pending or Current value to be set
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String[]] $AttributeValue        
    ) 

    Begin {
        #$CimOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
        $properties=@{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_iDRACCardService";Name="DCIM:iDRACCardService";}
        $instance = New-CimInstance -ClassName DCIM_iDRACCardService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties 
    }

    Process {
        if ($PSCmdlet.ShouldProcess($($iDRACSession.ComputerName),'Set iDRAC attribute')) {
            #Check if the attribute is settable.
            Write-Verbose "Get-PEDRACAttribute -iDRACSession $iDRACSession -GroupID $GroupID -AttributeName $AttributeName #-Verbose"
            $attribute = Get-PEDRACAttribute -iDRACSession $iDRACSession -GroupID $GroupID -AttributeName $AttributeName #-Verbose
            
            if ($attribute) {
                if ($attribute.IsReadOnly -eq 'false') {
                    
                    #Check if the AttributeValue falls in the same set as the PossibleValues by calling the helper function
                    if ($attribute.PossibleValues) {
                        Write-Verbose "verifying PEiDRAC attribute information ..."
                        if (TestPossibleValuesContainAttributeValues -PossibleValues $attribute.PossibleValues -AttributeValues $AttributeValue){
                            Write-Verbose "verifyed PEiDRAC attribute information ..."
                        } else {
                            Write-Error -Message "Attribute value `"${AttributeValue}`" is not valid for attribute ${AttributeName}."
                            return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                        }
                    }
                    Write-Verbose "setting PEiDRAC attribute information ..."
                    if ($PSCmdlet.ShouldProcess($AttributeValue, 'Set iDRAC attribute')) {
                            $params = @{
                                'Target'         = 'iDRAC.Embedded.1'
                                'AttributeValue' = $AttributeValue
                            }
                            if ($GroupID) {
                                $params.AttributeName = "$GroupID#$AttributeName"
                            } else {
                                $params.AttributeName = $AttributeName
                            }
#                            write-Verbose "params - AttributeName : $($attribute.GroupID)#$AttributeName"
                            write-Verbose "params - AttributeName  : $($params.AttributeName)"
                            write-Verbose "params - AttributeValue : $($params.AttributeValue)"
                            write-Verbose "Invoke-CimMethod -InputObject `$instance -MethodName SetAttribute -CimSession $iDRACsession -Arguments `$params"

                            if ($Server.iDRACSession.SystemGeneration -gt 11){
                                Try {
                                    $responseData = Invoke-CimMethod -InputObject $instance -CimSession $iDRACsession -MethodName SetAttribute    -Arguments $params -ErrorAction Stop
                                } catch {
                                    Write-warning "Set-PEDRACAttribute Invoke-CimMethod Failed : $($_.Exception.Message)"
                                }
                                if ($responseData.ReturnValue -eq 0) {
                                    Write-Verbose -Message 'iDRAC attribute configured successfully'
                                    if ($responseData.RebootRequired -eq 'Yes') {
                                        Write-Verbose -Message 'iDRAC attribute change requires reboot.'
                                        return [PSCustomObject]@{Result = $true ; RebootRequired  = $true}
                                    }
                                    return [PSCustomObject]@{Result = $true ; RebootRequired  = $false}
                                } else {
                                    Write-Warning -Message "iDRAC attribute change failed: $($responseData.Message)"
                                    return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                                }
                            } else {
                                Try {
                                    $responseData = Invoke-CimMethod -InputObject $instance -CimSession $iDRACSession -MethodName ApplyAttributes -Arguments $params -ErrorAction Stop
                                } catch {
                                    Write-warning "Set-PEDRACAttribute Invoke-CimMethod Failed : $($_.Exception.Message)"
                                }
                                if ($responseData.ReturnValue -eq 4096) {
                                    Write-Verbose -Message 'iDRAC attribute configured successfully'
                                    Write-Verbose -Message 'iDRAC attribute change requires reboot.'
                                    return [PSCustomObject]@{Result = $true ; RebootRequired  = $false}
                                } else {
                                    Write-Warning -Message "iDRAC attribute change failed: $($responseData.Message)"
                                    return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
                                }
                            }
                    }
                } else {
                    Write-Error -Message "${AttributeName} is readonly and cannot be configured."
                }
            } else {
                Write-Error -Message "${AttributeName} does not exist in PEiDRAC attributes."
            }
        }
        return [PSCustomObject]@{Result = $false ; RebootRequired  = $false}
    }

    End {

    }
}
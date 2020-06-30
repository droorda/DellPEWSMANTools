<#
Get-PEDRACAttribute.ps1 - Gets a list of DRAC attributes.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_Updated_= Doug Roorda <droorda at gmail.com> = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Get-PEDRACAttribute
{
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        [Parameter()]
        [String] $GroupID,

        [String] $AttributeDisplayName,

        [String] $AttributeName,

        [String] $GroupDisplayName
    )

    Begin
    {
        #$CimOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
    }

    Process
    {
        Write-Verbose "Retrieving PE DRAC attribute information ..."
        $filter = $null
        if ($GroupID) {
            $filter = "GroupID='$GroupID'"
        }
        if ($GroupDisplayName) {
            if ($filter) {
                $filter = "$filter AND GroupDisplayName='$GroupDisplayName'"
            } else {
                $filter = "GroupDisplayName='$GroupDisplayName'"
            }
        }
        if ($AttributeDisplayName) {
            if ($filter) {
                $filter = "$filter AND AttributeDisplayName='$AttributeDisplayName'"
            } else {
                $filter = "AttributeDisplayName='$AttributeDisplayName'"
            }
        }
        if ($AttributeName) {
            if ($filter) {
                $filter = "$filter AND AttributeName='$AttributeName'"
            } else {
                $filter = "AttributeName='$AttributeName'"
            }
        }

        if ($filter) {
            try {
                write-verbose "Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardAttribute -Namespace root\dcim -Filter $filter -ErrorAction Stop"
                if ($iDRACSession.SystemGeneration -gt 11){
                    Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardAttribute -Namespace root\dcim -Filter $filter -ErrorAction Stop
                } else {
                    $temp = @()
                    $temp += Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardString      -Namespace root\dcim -Filter $filter -ErrorAction Stop
                    $temp += Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardInteger     -Namespace root\dcim -Filter $filter -ErrorAction Stop
                    $temp += Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardEnumeration -Namespace root\dcim -Filter $filter -ErrorAction Stop
                    $temp
                }

            } catch {
                try {
                    Start-Sleep -s 5
                    write-verbose "Retry 1"
                    Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardAttribute -Namespace root\dcim -Filter $filter -ErrorAction Stop
#                } catch [Microsoft.Management.Infrastructure.CimException] {
#                    write-verbose "Retry Without GroupID"
#                    $temp = $null
#                    if ($GroupID) {
#                        $temp = Get-PEDRACAttribute -iDRACSession $iDRACSession -GroupDisplayName $GroupDisplayName -AttributeDisplayName $AttributeDisplayName -AttributeName $AttributeName
#                    }
#                    if ($temp.count -eq 1) {
#                        $temp
#                    } else {
#                        try {
#                            write-warning "Failing to Slow Get-PEDRACAttribute Method"
#                            $temp = Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_iDRACCardAttribute -Namespace root\dcim -ErrorAction Stop
#                            if ($GroupID             ){ $temp = $temp | Where {$_.GroupID              -eq $GroupID             } }
#                            if ($AttributeDisplayName){ $temp = $temp | Where {$_.AttributeDisplayName -eq $AttributeDisplayName} }
#                            if ($AttributeName       ){ $temp = $temp | Where {$_.AttributeName        -eq $AttributeName       } }
#                            $temp
#                        } catch {
#                            Write-warning "Get-PEDRACAttribute Failed : $($_.Exception.Message)"
#                        }
#                    }
                } catch {
                    Write-warning "Get-PEDRACAttribute Failed : $($_.Exception.Message)"
                }
            }
        } else {
            #Break query to parts if scan Times out
            $return = @()
            Foreach ($ClassName in @('DCIM_iDRACCardEnumeration','DCIM_iDRACCardInteger','DCIM_iDRACCardString')){
                Try{
                    write-verbose "Get-CimInstance -CimSession $iDRACSession -ClassName $ClassName -Namespace root\dcim -ErrorAction Stop"
                    $return  += Get-CimInstance -CimSession $iDRACSession -ClassName $ClassName -Namespace root\dcim -ErrorAction Stop
                } catch {
                    Try{
                        write-verbose "Retry 1"
                        Start-Sleep -s 5
                        $return  += Get-CimInstance -CimSession $iDRACSession -ClassName $ClassName -Namespace root\dcim -ErrorAction Stop
                    } catch {
                        Try{
                            write-verbose "Retry 2"
                            Start-Sleep -s 30
                            $return  += Get-CimInstance -CimSession $iDRACSession -ClassName $ClassName -Namespace root\dcim -ErrorAction Stop
                        } catch {
                                Write-warning "Get-PEDRACAttribute:$ClassName Failed : $($_.Exception.Message)"
                        }
                    }
                }
            }
            $return | Sort-Object InstanceID
        }
    }

    End {

    }
}

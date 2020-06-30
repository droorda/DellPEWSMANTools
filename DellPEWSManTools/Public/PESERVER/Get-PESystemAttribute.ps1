<#
Get-PESystemAttribute.ps1 - GET PE System attributes.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Get-PESystemAttribute
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

        [Parameter()]
        [String] $GroupDisplayName,

        [Parameter()]
        [String] $AttributeName,

        [Parameter()]
        [String] $AttributeDisplayName

    )

    Begin
    {

    }

    Process
    {
        Write-Verbose "Retrieving PE Systme attribute information ..."
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

        Try {
            Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_SystemAttribute -Namespace root\dcim -Filter $filter -ErrorAction Stop
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }

    End
    {

    }
}

<#
Get-PEEnclosure.ps1 - Get PE disk enclosure information.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
Function Get-PERAIDEnumeration
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession
    )
    Process
    {
        Write-Verbose "Get-CimInstance -CimSession $iDRACSession -ClassName Get-PERAIDEnumeration -Namespace root\dcim -ErrorAction Stop"
        try {
            Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_RAIDEnumeration -Namespace 'root/dcim' -ErrorAction Stop
        } catch {
            try {
                sleep -s 5
                Get-CimInstance -CimSession $iDRACSession -ClassName DCIM_RAIDEnumeration -Namespace 'root/dcim' -ErrorAction Stop
            } catch {
                Write-warning "Get-PERAIDEnumeration Failed : $($_.Exception.Message)"
            }
        }


    }
}
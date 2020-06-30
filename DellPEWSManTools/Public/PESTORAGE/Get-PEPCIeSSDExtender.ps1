<#
Get-PEPCIeSSDExtender.ps1 - Get PE PCIe SSD extender information.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Get-PEPCIeSSDExtender
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
        $ssdExtender = Get-CimInstance -ClassName DCIM_PCIeSSDExtenderView -Namespace root\dcim -CimSession $idracsession -Verbose
        return $ssdExtender
    }
}
<#
Connect-PERFSISOImage.ps1 - connect a remote file share ISO image to PE DRAC.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com>
_version_ = 1.0.0.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

function Connect-PERFSISOImage
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias("s")]
        [ValidateNotNullOrEmpty()]
        $iDRACSession,

        [Parameter(Mandatory)]
        [ValidateScript({[System.Net.IPAddress]::TryParse($_,[ref]$null)})]
        [String] $IPAddress,

        [Parameter(Mandatory)]
        [String]$ShareName,

        [Parameter(Mandatory)]
        [String]$ImageName,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateSet("NFS","CIFS")]
        [String]$ShareType = "CIFS",

        [Parameter()]
        [ValidateSet('MD5','SHA1')]
        [String] $HashType,

        [Parameter()]
        [String] $HashValue
    )

    Begin
    {
        $properties= @{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_OSDeploymentService";Name="DCIM:OSDeploymentService";}
        $instance = New-CimInstance -ClassName DCIM_OSDeploymentService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties

        if ($HashType -and !$HashValue)
        {
            throw 'If $HashType is provided, $HashValue must be provided'
        }

        if ($HashValue -and !$HashType)
        {
            throw 'If $HashValue is provided, $HashType must be provided'
        }
    }

    Process
    {
        $params= @{
            IPAddress = $IPAddress
            ShareName = $ShareName
            ShareType = ([ShareType]$ShareType -as [int])
            ImageName = $ImageName
            Username = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
        }

        if ($HashType)
        {
            $params.Add('HashType', $HashType)
            $params.Add('HashValue', $HashValue)
        }

        Invoke-CimMethod -InputObject $instance -CimSession $iDRACSession -MethodName ConnectRFSISOImage -Arguments $params
    }
}

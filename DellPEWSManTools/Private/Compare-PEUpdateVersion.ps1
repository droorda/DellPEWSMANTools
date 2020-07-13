<#
Compare-PEUpdateVersion.ps1 -

_author_ = Douglas Roorda _version_ = 1.0


This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Compare-PEUpdateVersion {
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
            HelpMessage='Update')]
        $Update,

        [Parameter(
            Mandatory=$True,
            HelpMessage='Device')]
        $Device
    )

    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }

        Write-Verbose "Comparing '$($Device.VersionString)' to '$($Update.vendorVersion)'"
        # if ($Device.VersionString -is [version]) {
        #     if ($Update.vendorVersion -match '^\d+$') {
        #         $Update.vendorVersion = "#($Update.vendorVersion).0"
        #     }
        # }
        if ($Device.VersionString -eq $Update.vendorVersion){
            Write-Verbose "Filter 0"
            $Return = 0
        } elseif ($Device.VersionString.trim() -match '^\d+(\.\d+){0,3}$' ) {
            Write-Verbose "Filter 1"
            $CurrentVersion = $Device.VersionString
            $UpdateVersion = $Update.vendorVersion
            if ($Device.ElementName -eq 'CMC') {
                #Dell did not keep same version number fidelity in DellCatalog
                Try {
                    $CurrentVersion = [version](($CurrentVersion.Split('.') | Select-Object -first $UpdateVersion.split('.').count) -join '.')
                } catch {
                    $CurrentVersion = [version](($CurrentVersion.Split('.') | Select-Object -first ($CurrentVersion.split('.').count -1 )) -join '.')
                    $UpdateVersion  = [version](($UpdateVersion.Split( '.') | Select-Object -first ($UpdateVersion.split( '.').count -1 )) -join '.')
                }
            } else {
                $CurrentVersion = [version]$CurrentVersion
            }
            if ($Update.vendorVersion -match '^\d+$') {
                $UpdateVersion  = [version]"$UpdateVersion.0"
            } else {
                $UpdateVersion  = [version]$UpdateVersion
            }
            if ($UpdateVersion -gt $CurrentVersion){
                $Return = 1
            } else {
                $Return = -1
            }
        } elseif ($Device.VersionString -match '^(\d+)\.(\d+)\.(\d+)-(\d+)$') {
            Write-Verbose "Filter 2"
            $CurrentVersion = $Device.VersionString
            $UpdateVersion  = $Update.vendorVersion
            $UpdateVals     = ([regex]'^(\d+)\.(\d+)\.(\d+)-(\d+)$').Match($UpdateVersion).Groups
            For ($i=1; $i -lt $UpdateVals.count; $i++) {
                Write-Verbose "'$($UpdateVals[$i].Value)' -eq '$($matches[$i])'"
                if ($UpdateVals[$i].Value -eq $matches[$i]) {
                    $Return = 0
                } elseif ($UpdateVals[$i].Value -gt $matches[$i]) {
                    $Return = 1
                    break
                } else {
                    $Return = -1
                    break
                }
            }
        } elseif ($Device.VersionString -match '^(\d+)(\w)(\d+)$' ) {
            Write-Verbose "Filter 3"
            $CurrentVersion = $Device.VersionString
            $UpdateVersion  = $Update.vendorVersion
            $UpdateVals     = ([regex]'^(\d+)(\w)(\d+)$').Match($UpdateVersion).Groups
            For ($i=1; $i -lt $UpdateVals.count; $i++) {
                Write-Verbose "'$($UpdateVals[$i].Value)' -eq '$($matches[$i])'"
                if ($UpdateVals[$i].Value -eq $matches[$i]) {
                    $Return = 0
                } elseif ($UpdateVals[$i].Value -gt $matches[$i]) {
                    $Return = 1
                    break
                } else {
                    $Return = -1
                    break
                }
            }
        } elseif ($Device.VersionString -match '^(\w)(\d+)$' ) {
            Write-Verbose "Filter 4"
            $CurrentVersion = $Device.VersionString
            $UpdateVersion  = $Update.vendorVersion
            $UpdateVals     = ([regex]'^(\w)(\d+)$').Match($UpdateVersion).Groups
            For ($i=1; $i -lt $UpdateVals.count; $i++) {
                Write-Verbose "'$($UpdateVals[$i].Value)' -eq '$($matches[$i])'"
                if ($UpdateVals[$i].Value -eq $matches[$i]) {
                    $Return = 0
                } elseif ($UpdateVals[$i].Value -gt $matches[$i]) {
                    $Return = 1
                    break
                } else {
                    $Return = -1
                    break
                }
            }
        } else {
            Write-Warning "Unknown Version structure '$($Device.VersionString)'"
            if ($Device.VersionString -ne $Update.vendorVersion){
                $Return = 1
            }
        }
        Write-Verbose "Returning '$Return'"
        $Return
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}

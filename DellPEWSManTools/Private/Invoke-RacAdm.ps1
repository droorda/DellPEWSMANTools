<#
Invoke-RacAdm.ps1 -

_author_ = Douglas Roorda _version_ = 1.0


This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
$ScriptPath = split-path $Script:MyInvocation.MyCommand.Path -parent

function Invoke-RacAdm {
    Param(
        $racexe            = "$ScriptPath\BIN\rac5\racadm.exe",
        $DracInfo,
        [switch]$ignoreCertFailures,
        [string]$command
    )
    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" }

        @($racexe) | foreach-object {
            if (Test-path ($_)) {
                write-Verbose "Verified Access to '$_'"
            } else {
                throw "Unable to access '$_'"
            }
        }

        $return = $false
        for($i=1; $i -le 6; $i++){
            write-verbose "racadm command attempt $i"
            if ($ignoreCertFailures){
                write-verbose "$racexe -r $($DracInfo.HostName) -u $($DracInfo.Credential.UserName) -p $($DracInfo.Credential.GetNetworkCredential().Password) $command"
                $return = &$racexe -r $($DracInfo.HostName) -u $($DracInfo.Credential.UserName) -p $($DracInfo.Credential.GetNetworkCredential().Password) $($command.split(" ")) 2>&1
            } else {
                write-verbose "$racexe -S -r $($DracInfo.HostName) -u $($DracInfo.Credential.UserName) -p $($DracInfo.Credential.GetNetworkCredential().Password) $command"
                $return = &$racexe -S -r $($DracInfo.HostName) -u $($DracInfo.Credential.UserName) -p $($DracInfo.Credential.GetNetworkCredential().Password) $($command.split(" ")) 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                write-warning "Retry $i : Error $LASTEXITCODE on $($DracInfo.HostName) running command $command"
                write-warning "$return"
                Start-Sleep -s 300
                # if ($i -eq 3) {
                #     write-warning "Triggering Reset of iDRAC"
                #     Restart-DRAC $DracInfo -ignoreCertFailures:$ignoreCertFailures

                # }
            } else {
                Write-Verbose "Command Succeded"
                Start-Sleep -s 30
                return $LASTEXITCODE
            }
        }
        return $LASTEXITCODE
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}

<#
New-Certificate.ps1 - Imports a certificate into PE DRAC.

_author_ = Douglas Roorda <droorda@gmail.com> _version_ = 1.0

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

function New-Certificate {
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
    [CmdletBinding(
                    # DefaultParameterSetName='General',
                    PositionalBinding=$false,
                    SupportsShouldProcess=$true,
                    ConfirmImpact='low'
                    )]
    # [OutputType([String])]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $CertName,

        [string[]]
        $CertAltNames,

        [string[]]
        $IPaddresses,

        [string]
        $CertificateTemplate = 'WebServerLongLife',

        [string]
        $CAMachineNameCAName
        )

    begin {
        Write-Verbose "-------------Start $($myInvocation.InvocationName) IN '$((Get-MyFunctionLocation).ScriptName)' -----------------"
        Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)"
        Write-Verbose "  Line '$($myInvocation.Line.Trim())'"
        $myInvocation.BoundParameters.GetEnumerator()  | foreach { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" }
        $myInvocation.UnboundArguments | foreach { Write-Verbose "  UnboundArguments : '$_'" }

        If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
            Throw 'New-Certificate Requires Administrator token'
        }


        if (-not $CAMachineNameCAName) {
            write-verbose "Detecting CAMachineNameCAName"
            Try {
                $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
                $domain = "DC=" + $domain -replace '\.', ", DC="
                $CA = [ADSI]"LDAP://CN=Enrollment Services, CN=Public Key Services, CN=Services, CN=Configuration, $domain"
                $CAMachineNameCAName = "$($CA.psBase.Children.DNSHostName)\$($CA.psBase.Children.Name)"
            } catch {
                throw "error getting CA for Domain '$domain'"
            }
        }

        Write-Verbose "Creating Temp Files"
        $Files = @{
            Request = New-TemporaryFile
            Csr     = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).CSR"} -passThru
            Cer     = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).CER"} -passThru
        }
        $Files.values | Where-Object {$_} | ForEach-Object {if (Test-Path($_)) {remove-item $_ -ErrorAction Stop}}
        Write-Verbose "Creating Certificate Request"
        @(
            "[Version]"
            'Signature="$Windows NT$"'
            ""
            "[NewRequest] "
            "Subject = `"E = SysAdminAlerts@ICONICGROUP.com,"+ `
                "CN = $CertName, "+`
                "OU = ICONICGROUP, "+`
                "O = ICONICGROUP, "+`
                "L = Tallahassee, "+`
                "S = FL, "+`
                "C = US`""
            ""
            "KeySpec = 1"
            "KeyLength = 2048"
            "Exportable = TRUE"
            "MachineKeySet = TRUE"
            #        "SMIME = False"
            "PrivateKeyArchive = FALSE"
            "UserProtected = FALSE"
            "UseExistingKeySet = FALSE"
            'ProviderName = "Microsoft RSA SChannel Cryptographic Provider"'
            "ProviderType = 12"
            "RequestType = PKCS10"
            "KeyUsage = 0xa0"
            ""
            "[Extensions]"
            '2.5.29.17 = "{text}"'
        ) | ForEach-Object {$_ | Out-File -append $Files.Request }
        if ($CertName.Contains("*")){
            "_continue_ = `"dns=$CertName&`""                                            | Out-File -append $Files.Request
        } else {
            if ($CertName.Contains(".")){
                # Add NetBios Name
                "_continue_ = `"dns=$($CertName.split('.')[0])&`""                       | Out-File -append $Files.Request
            }
            "_continue_ = `"dns=$CertName&`""                                            | Out-File -append $Files.Request
            [System.Net.Dns]::GetHostAddresses($CertName).IPAddressToString | foreach {
                "_continue_ = `"IPAddress=$_&`""                                         | Out-File -append $Files.Request
            }
        }
        foreach ($CertAltName in $CertAltNames){
            "_continue_ = `"dns=$CertAltName&`""                                         | Out-File -append $Files.Request
        }

        foreach ($IPaddress in $IPaddresses){
            "_continue_ = `"IPaddress=$IPaddress&`""                                     | Out-File -append $Files.Request
        }

        Write-verbose "  Generating Cert for iDRAC"
        write-verbose "Calling:'certutil.exe -privatekey -delstore MY $CertName'"
        certutil.exe -privatekey -delstore MY $CertName                                                         | Write-Verbose
        write-verbose '-------------------------------------------------------------------------'
        write-verbose "Calling:'certreq -new $($Files.Request) $($Files.Csr)'"
        certreq -new $($Files.Request) $($Files.Csr)                                                            | Write-Verbose
        write-verbose "Calling:'certreq -submit -config $CAMachineNameCAName -attrib `"CertificateTemplate: $CertificateTemplate`" $($Files.Csr) $($Files.Cer)'"
        $RequestID = certreq -submit -config $CAMachineNameCAName -attrib "CertificateTemplate: $CertificateTemplate" $($Files.Csr) $($Files.Cer)
        $RequestID | Write-Verbose
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "SSL Cert Successfully created"
            # write-verbose "Calling:'Certutil.exe -addstore -f MY $($Files.Cer)'"
            # Certutil.exe -addstore -f MY $($Files.Cer)                                                          | Write-Verbose
            # if ($LASTEXITCODE -ne 0) { throw "Error $LASTEXITCODE Adding Cert to Store" }
            # write-verbose '-------------------------------------------------------------------------'
            # write-verbose "Calling:'Certutil.exe -repairstore MY $CertName'"
            # Certutil.exe -repairstore MY $CertName                                                              | Write-Verbose
            # if ($LASTEXITCODE -ne 0) { throw "Error $LASTEXITCODE Repairing Store" }
            # write-verbose '-------------------------------------------------------------------------'
            $Certificate = Import-Certificate -FilePath $Files.Cer -CertStoreLocation cert:\LocalMachine\My
            $Files.values | Where-Object {$_} | ForEach-Object {if (Test-Path($_)) {remove-item $_ -ErrorAction Stop}}
        } else {
            throw $RequestID
        }
        $Certificate
    }
    process {
    }
    End {
        Write-Verbose "--------------END- $($myInvocation.InvocationName) -----------------"
    }
}

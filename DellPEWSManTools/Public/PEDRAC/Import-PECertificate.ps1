<#
Import-PECertificate.ps1 - Imports a certificate into PE DRAC.

_author_ = Ravikanth Chaganti <Ravikanth_Chaganti@Dell.com> _version_ = 1.0
_Updated_= Doug Roorda <droorda at gmail.com> = 1.1

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License, version 2 (GPLv2). There is NO WARRANTY for this software, express or implied, including the implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2 along with this software; if not, see http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>
function Import-PECertificate
{
    [CmdletBinding( DefaultParameterSetName='FileGeneral',
                    PositionalBinding=$false)]
    [OutputType([String])]
    Param
    (
        # iDRAC Session
        [Parameter( Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("s")]
        $iDRACSession,

        # Pass phrase
        [Parameter(ParameterSetName='FileGeneral')]
        [Parameter(ParameterSetName='FileWait')]
        [Parameter(ParameterSetName='FilePassthru')]
        [Alias("pass")]
        [SecureString]
        $passphrase,

        # Certificate Filename
        [Parameter(Mandatory,ParameterSetName='FileGeneral')]
        [Parameter(Mandatory,ParameterSetName='FileWait')]
        [Parameter(Mandatory,ParameterSetName='FilePassthru')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("cert")]
        [string]
        $certificateFileName,

        # Certificate
        [Parameter(Mandatory,ParameterSetName='CertGeneral')]
        [Parameter(Mandatory,ParameterSetName='CertWait')]
        [Parameter(Mandatory,ParameterSetName='CertPassthru')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $certificate,

        # Web Server Certificate
        [Parameter(ParameterSetName='FileGeneral')]
        [Parameter(ParameterSetName='FileWait')]
        [Parameter(ParameterSetName='FilePassthru')]
        [Parameter(ParameterSetName='CertGeneral')]
        [Parameter(ParameterSetName='CertWait')]
        [Parameter(ParameterSetName='CertPassthru')]
        [Alias("wsc")]
        [switch]
        $webServerCertificate,

        # AD Service Certificate
        [Parameter(ParameterSetName='FileGeneral')]
        [Parameter(ParameterSetName='FileWait')]
        [Parameter(ParameterSetName='FilePassthru')]
        [Parameter(ParameterSetName='CertGeneral')]
        [Parameter(ParameterSetName='CertWait')]
        [Parameter(ParameterSetName='CertPassthru')]
        [Alias("asc")]
        [switch]
        $ADServiceCertificate,

        # Custom Signing Certificate
        [Parameter(ParameterSetName='FileGeneral')]
        [Parameter(ParameterSetName='FileWait')]
        [Parameter(ParameterSetName='FilePassthru')]
        [Parameter(ParameterSetName='CertGeneral')]
        [Parameter(ParameterSetName='CertWait')]
        [Parameter(ParameterSetName='CertPassthru')]
        [Alias("csc")]
        [switch]
        $customSigningCertificate,

        # Wait for job completion
        [Parameter(ParameterSetName='FileWait')]
        [Parameter(ParameterSetName='CertWait')]
		[Switch]
        $Wait,

        # Privilege
        [Parameter(ParameterSetName='FilePassthru')]
        [Parameter(ParameterSetName='CertPassthru')]
		[Switch]
        $Passthru
    )

    Begin
    {
        $properties=@{SystemCreationClassName="DCIM_ComputerSystem";SystemName="DCIM:ComputerSystem";CreationClassName="DCIM_iDRACCardService";Name="DCIM:iDRACCardService";}
        $instance = New-CimInstance -ClassName DCIM_iDRACCardService -Namespace root/dcim -ClientOnly -Key @($properties.keys) -Property $properties

        $params=@{}

        if ( !$webServerCertificate -and !$ADServiceCertificate -and !$customSigningCertificate )
        {
            Throw "ERROR: Missing certificate type"
        }

        if ( ($webServerCertificate -and $ADServiceCertificate) -or ($ADServiceCertificate -and $customSigningCertificate) -or ($webServerCertificate -and $customSigningCertificate) )
        {
            Throw "ERROR: Cannot process multiple certificate types"
        }

        # if ($certificateObject){
        #     $certificateFileName = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).pfx"} -passThru
        #     $certificateFileName | remove-item -ErrorAction Stop
        #     [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

        #     # $passphrase = $(ConvertTo-SecureString  ([System.Web.Security.Membership]::GeneratePassword(32,3)) -AsPlainText  -Force)
        #     $passphrase = $(ConvertTo-SecureString  (Get-Random) -AsPlainText  -Force)
        #     Export-PfxCertificate -Cert $certificateObject -Password $passphrase -FilePath $certificateFileName | Out-Null

        #     $OpenSSLexe        = "\\local\sys\Software\OpenSSL\Win64OpenSSL-1_1_0b\bin\openssl.exe"
        #     $tempCred = New-Object -Typename PSCredential -ArgumentList 'temp',$passphrase
        #     $seed2 = $tempCred.GetNetworkCredential().Password

        #     $Files = @{
        #         Cer     = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).CER"} -passThru
        #         Key     = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).KEY"} -passThru
        #         RootCer = New-TemporaryFile | rename-item -NewName {"$($_.BaseName).CER"} -passThru
        #     }
        #     $Files.values | Where-Object {$_} | ForEach-Object {if (Test-Path($_)) {remove-item $_ -ErrorAction Stop}}
        #     $Files.Pfx = $certificateFileName
        #     write-verbose "Calling:'$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -passout pass: -cacerts -out $($Files.RootCer)'"
        #     &$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -nokeys -cacerts -out $($Files.RootCer) 2>&1 | Write-Verbose
        #     if ($LASTEXITCODE -ne 0) { write-warning "Error $LASTEXITCODE Exporting ROOT Key"    ; break }
        #     write-verbose '-------------------------------------------------------------------------'
        #     write-verbose "Calling:'$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -nokeys -clcerts      -out $($Files.Cer)'"
        #     &$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -nokeys -clcerts      -out $($Files.Cer) 2>&1 | Write-Verbose
        #     if ($LASTEXITCODE -ne 0) { write-warning "Error $LASTEXITCODE Exporting Public Key"  ; break }
        #     write-verbose '-------------------------------------------------------------------------'
        #     write-verbose "Calling:'$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -nocerts -nodes       -out $($Files.Key)'"
        #     &$OpenSSLexe pkcs12 -in $($Files.Pfx) -passin pass:$seed2 -nocerts -nodes       -out $($Files.Key) 2>&1 | Write-Verbose
        #     if ($LASTEXITCODE -ne 0) { write-warning "Error $LASTEXITCODE Exporting Private Key" ; break }
        #     write-verbose '-------------------------------------------------------------------------'

        #     # $data = Get-Content -Path $certificateFileName -Encoding String -Raw
        #     $data  = Get-Content -Path $Files.RootCer -Encoding String -Raw
        #     $data += Get-Content -Path $Files.Cer     -Encoding String -Raw
        #     $data += Get-Content -Path $Files.Key     -Encoding String -Raw
        #     $certificateFileName | remove-item -ErrorAction Stop
        #     $certificate = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes($data))

        #     if ( $certificate.Length -eq 0 )
        #     {
        #         Throw "ERROR: No certificate found in file specified"
        #     }
        # }

        if ( $certificateFileName )
        {
            $data = Get-Content -Path $certificateFileName -Encoding String -Raw
            $certificate = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes($data))

            if ( $certificate.Length -eq 0 )
            {
                Throw "ERROR: No certificate found in file specified"
            }
        }

        $params=@{}

        if ($certificate)
        {
            $params.SSLCertificateFile = $certificate
        }

        if ($passphrase)
        {
            # First create the credential out of the secure string and then fetch the clear text value of passphrase
            $tempCred = New-Object -Typename PSCredential -ArgumentList 'temp',$passphrase
            $params.Passphrase = $tempCred.GetNetworkCredential().Password
        }

        if ($webServerCertificate)
        {
            $params.CertificateType = "1"
        }
        elseif ($ADServiceCertificate)
        {
            $params.CertificateType = "2"
        }
        else
        {
            $params.CertificateType = "3"
        }
    }
    Process
    {

        Write-Verbose "Importing Certificate to $($iDRACsession.ComputerName)"
        $responseData = Invoke-CimMethod -InputObject $instance -MethodName ImportSSLCertificate -CimSession $iDRACsession -Arguments $params #2>&1
        if ($responseData.ReturnValue -eq 4096)
        {
            if ($Passthru)
            {
                $responseData
            }
            elseif ($Wait)
            {
                Wait-PEConfigurationJob -iDRACSession $iDRACsession -JobID $responseData.Job.EndpointReference.InstanceID -Activity "Configuring Standard Schema Settings for $($iDRACsession.ComputerName)"
                Write-Verbose "Imported Certificate to $($iDRACsession.ComputerName) successfully"
            }
        }
        else
        {
            Throw "Certificate Import to $($iDRACsession.ComputerName) failed with error: $($responseData.Message)"
        }
    }
}



<#
https://downloads.dell.com/manuals/common/Dell-iDRACCardProfile-1.5.pdf



https://downloads.dell.com/manuals/common/Dell-LCManagementProfile-1.3.pdf

9.14    Replace iDRAC Web Server client certificate and private key
A)  Replace the iDRAC Web Server client certificate and private key using the
    SetCertificateAndPrivateKey() method, construct the input parameters per Table 27
B)  INVOKE the SetCertificateAndPrivateKey() method
    Class URI:
    http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=DCIM_ComputerSystem+CreationClassName=DCIM_LCService+SystemName=DCIM:ComputerSystem+Name=DCIM:LCService
9.15    Replace iDRAC Web Server public certificate
A)  Replace the iDRAC Web Server public certificate using the SetPublicCertificate() method,
    construct the input parameters per Table 29
B)  INVOKE the SetPublicCertificate() method
    Class URI:
    http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=DCIM_ComputerSystem+CreationClassName=DCIM_LCService+SystemName=DCIM:ComputerSystem+Name=DCIM:LCService







#>
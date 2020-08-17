@echo off
REM --------------------------------------------------------------------------
REM
REM          DELL CORPORATION PROPRIETARY INFORMATION
REM
REM This software is supplied under the terms of a license agreement or
REM nondisclosure agreement with Dell Corporation and may not be copied
REM or disclosed except in accordance with the terms of that agreement.
REM
REM Copyright (c) 2007 Dell, Inc. All Rights Reserved.
REM
REM Script Name: vmdeploy.bat
REM
REM Purpose: this sample script handles OS/patch deployments to one or more 
REM          iDRAC hosts, using Virtual Media.
REM    NOTE: the boot image supplied to this script performs the deployment.
REM          [i.e. the boot image determines what/how deployment is done]
REM --------------------------------------------------------------------------

set VOPTS=

REM this tests whether we are being re-entered to handle one deployment
if .%1==.DEPLOY1 goto deploy1

REM otherwise, it's a fresh invocation -- process command options/arguments
setlocal
set SCRIP=%0
set ALIST=
set PLIST=
set ARGOK=
set OPTN=
set BOOTOPTN=
set CYCLEOPTN=
:chkargs
if .%1==.   goto endargs
if .%1==.-h goto usage
if .%2==.   goto badargs
set ARGOK=%ARGOK%.
if .%1==.-r goto chkaddr
if .%1==.-u goto addarg
if .%1==.-p goto addarg
REM if .%1==.-f goto addmedia
if .%1==.-c goto addmedia

set VOPTS=HALT
echo **error: unknown option '%1'
goto nextopt

:badargs
set VOPTS=HALT
echo **error: argument missing for '%1'
goto endargs

:addmedia
if NOT .%VOPTS%==.HALT set VOPTS=%1%2
set OPTN=%1 %2
goto nextarg

:addarg
set PLIST=%PLIST% %1 %2
if .%1==.-u set BOOTOPTN=%BOOTOPTN%-U %2
if .%1==.-p set BOOTOPTN=%BOOTOPTN% -P %2
if .%1==.-u set CYCLEOPTN=%CYCLEOPTN%-U %2
if .%1==.-p set CYCLEOPTN=%CYCLEOPTN% -P %2

:nextarg
shift
:nextopt
shift
goto chkargs

:chkaddr
if NOT exist %2 goto nofile
set ALIST=%2
goto nextarg

:nofile
set PLIST=%1 %2 %PLIST%
set BOOTOPTN=-I lanplus -H %2 
set CYCLEOPTN=-I lanplus -H %2 
goto nextarg

:endargs
if .%VOPTS%==.HALT goto errexit
if .%ARGOK%==..... goto chkenv
echo **error: too many/few arguments
goto halt

:chkenv
if .%TEMP%==. goto badtemp
if exist %TEMP%\. goto chkutil

:badtemp
echo **error: bad environment variable 'TEMP'
set VOPTS=

:chkutil
..\bmc\ipmitool -h >NUL 2>&1
if errorlevel 1 set VOPTS=HALT
vmcli -h >NUL 2>&1
if errorlevel 1 set VOPTS=HALT
if NOT .%VOPTS%==.HALT goto chktemp
echo **error: required utility (ipmitool, vmcli) not in PATH
goto errexit

:chktemp
if .%VOPTS%==. goto halt

REM all's well: deploy each target host by calling ourself with %1 = DEPLOY1

if NOT .%ALIST%==. goto manyrac
REM echo %SCRIP% DEPLOY1 %PLIST% %OPTN%
%SCRIP% DEPLOY1 %PLIST% %OPTN%
goto done

:manyrac
REM for /f "eol=# delims= " %%i in (%ALIST%) do %SCRIP% DEPLOY1 -r %%i %PLIST% %VOPTS%
for /f %%i in (%ALIST%) do (
set BOOTARGS=raw 0x00 0x08 0x05 0x80 0x20 0x00 0x00 0x00
set CYCLEARGS=chassis power cycle
set OPTN=%OPTN%
set PLIST=-r %%i %PLIST%
set BOOTOPTN=-I lanplus -H %%i %BOOTOPTN%
set CYCLEOPTN=-I lanplus -H %%i %CYCLEOPTN%
echo on
%SCRIP% DEPLOY1 -r %%i %PLIST% %OPTN%
echo off
)
goto done

:deploy1
shift
set VLOG=%TEMP%\log_%2.txt

set BOOTARGS=raw 0x00 0x08 0x05 0x80 0x20 0x00 0x00 0x00
set CYCLEARGS=chassis power cycle

REM echo vmcli %PLIST% %OPTN%
REM echo ipmitool %BOOTOPTN% %BOOTARGS%
REM echo ipmitool %CYCLEOPTN% %CYCLEARGS%

REM Make the ERRORLEVEL zero so that we can track IPMITOOL
dir >NUL 2>&1

REM set the next boot device
echo Setting next boot device

..\bmc\ipmitool %BOOTOPTN% %BOOTARGS%
REM check if the IPMI command passed
REM FINDSTR /I "Error" %VLOG% >NUL
IF %ERRORLEVEL%==1 goto ipmiexit
REM shoot out the vmcli command
echo Issuing vmcli
START cmd.exe /c "vmcli %PLIST% %OPTN%>%VLOG%"
REM delay
ping 127.0.0.1 -n 35 > NUL
REM echo power cycling the server
REM powercycle the server only if vmcli attaches successfully
FINDSTR /I "Mapping" %VLOG% >NUL
IF %ERRORLEVEL%==0 start cmd.exe /c "..\bmc\ipmitool %CYCLEOPTN% %CYCLEARGS%"
IF %ERRORLEVEL%==1 echo "ERROR: Please ensure iDRAC Virtual Media is Attached or Auto-attached and Virtual Media session is not already in use and the medium is not Ejected."

REM ping 127.0.0.1 -n 20 > NUL
REM start cmd /c "..\bmc\ipmitool %CYCLEOPTN% chassis power up"

REM make ERRORLEVEL zero 
dir >NUL 2>&1
goto xit

:halt
set VOPTS=HALT

:errexit
REM make ERRORLEVEL nonzero 
dir : >NUL 2>&1
if NOT .%VOPTS%==.HALT goto xit

:ipmiexit
REM Issue a warning to check ipmi settings in iDRAC
echo "Check if IPMI over lan is Enabled"
goto xit

echo usage

:usage
echo.
echo usage: ivmdeploy.bat -r ^<RAC-IP^> -u ^<RAC-USER^> -p ^<RAC-PASSWD^> -c ^<ISO9660-IMG ^| PATH^>
echo where:
echo       ^<ISO9660-IMG^> is a bootable image file
echo	   ^<PATH^> is the path to the Virtual CD drive
echo       ^<RAC-USER^> = RAC user id, with 'virtual media' privilege
echo       ^<RAC-PASSWD^> = RAC user password
echo       ^<RAC-IP^> is either:
echo         - a string of the form: 'RAC-IP'
echo         - a file containing lines matching that form
echo       In the latter case, the boot image is setup and booted
echo       for each host/RAC IP contained in the file.
echo.
echo *Note: your boot image determines what is deployed, and how.
echo.

:done
endlocal

:xit


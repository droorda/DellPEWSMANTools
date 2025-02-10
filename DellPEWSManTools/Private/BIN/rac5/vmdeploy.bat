@echo off
REM --------------------------------------------------------------------------
REM
REM          DELL CORPORATION PROPRIETARY INFORMATION
REM
REM This software is supplied under the terms of a license agreement or
REM nondisclosure agreement with Dell Corporation and may not be copied
REM or disclosed except in accordance with the terms of that agreement.
REM
REM Copyright (c) 2005 Dell, Inc. All Rights Reserved.
REM
REM Script Name: vmdeploy.bat
REM
REM Purpose: this sample script handles OS/patch deployments to one or more 
REM          DRAC hosts, using Virtual Media.
REM    NOTE: the boot image supplied to this script performs the deployment.
REM          [ie. the boot image determines what/how deployment is done]
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
set BOOTDEV=1
:chkargs
if .%1==.   goto endargs
if .%1==.-h goto usage
if .%2==.   goto badargs
set ARGOK=%ARGOK%.
if .%1==.-r goto chkaddr
if .%1==.-u goto addarg
if .%1==.-p goto addarg
if .%1==.-f goto addmedia
if .%1==.-c goto addmedia
if .%1==.-i goto addbootdev
set VOPTS=HALT
echo **error: unknown option '%1'
goto nextopt
:badargs
set VOPTS=HALT
echo **error: argument missing for '%1'
goto endargs
:addmedia
if NOT .%VOPTS%==.HALT set VOPTS=%1%2
goto nextarg
:addbootdev
set BOOTDEV=%2
goto nextarg
:addarg
set PLIST=%PLIST% %1%2
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
set PLIST=%1%2 %PLIST%
goto nextarg

:endargs
if .%VOPTS%==.HALT goto errexit
if .%ARGOK%==..... goto chkenv
if .%ARGOK%==...... goto chkenv
echo **error: too many/few arguments
goto halt

:chkenv
if .%TEMP%==. goto badtemp
if exist %TEMP%\. goto chkutil
:badtemp
echo **error: bad environment variable 'TEMP'
set VOPTS=
:chkutil
racadm >NUL 2>&1
if errorlevel 1 set VOPTS=HALT
racvmcli -h >NUL 2>&1
if errorlevel 1 set VOPTS=HALT
sleep 1 >NUL 2>&1
if errorlevel 1 set VOPTS=HALT
if NOT .%VOPTS%==.HALT goto chktemp
echo **error: required utility (sleep, racadm, racvmcli) not in PATH
goto errexit
:chktemp
if .%VOPTS%==. goto halt

REM all's well: deploy each target host by calling ourself with %1 = DEPLOY1

if NOT .%ALIST%==. goto manyrac
%SCRIP% DEPLOY1 %PLIST% %VOPTS% %BOOTDEV%
goto done
:manyrac
for /f "eol=# delims= " %%i in (%ALIST%) do %SCRIP% DEPLOY1 -r%%i %PLIST% %VOPTS% %BOOTDEV%
goto done

:deploy1
shift
set VLOG=%TEMP%\log%1.txt
set MAXWAIT=15
start /b cmd /c "racvmcli %1 %2 %3 %4 >%VLOG% 2>&1"
:wait
set MAXWAIT=.%MAXWAIT%
if "%MAXWAIT%"=="................15" goto errexit
sleep 1
find "connected" %VLOG% >NUL 2>&1
if errorlevel 1 goto wait

REM if we get here, the VM process is connected
racadm %1 %2 %3 config -g cfgRacVirtual -o cfgVirtualBootOnce %5
if errorlevel 1 goto errexit

REM if we get here, it's all set to go -- reboot the target host, and leave
racadm %1 %2 %3 serveraction powerdown >NUL 2>&1
sleep 30
racadm %1 %2 %3 serveraction powerup >NUL 2>&1
sleep 5

REM ----------------------------------------------------------------------
REM NOTE:
REM
REM Once the deployment is complete, the Virtual Media session should be
REM disconnected using the following command for each system/IP:
REM
REM racadm -r <RAC IP> -u <username> -p <password> vmdisconnect
REM
REM ----------------------------------------------------------------------

REM make ERRORLEVEL zero 
dir >NUL 2>&1
goto xit

:halt
set VOPTS=HALT
:errexit
REM make ERRORLEVEL nonzero 
dir : >NUL 2>&1
if NOT .%VOPTS%==.HALT goto xit

:usage
echo.
echo usage: vmdeploy.bat -r ^<RAC-IP^> -u ^<RAC-USER^> -p ^<RAC-PASSWD^>
echo                   [ -f ^<FLOPPY-IMG^> ^| -c ^<ISO9660-IMG^> ]
echo                   [-i ^<DeviceID^>]
echo.
echo where:
echo       ^<ISO9660-IMG^> and ^<FLOPPY-IMG^> are bootable image files
echo       ^<RAC-USER^> = RAC user id, with 'virtual media' privilege
echo       ^<RAC-PASSWD^> = RAC user password
echo       ^<RAC-IP^> is either:
echo         - a string of the form: 'RAC-IP_or_hostname[:SSL-port]'
echo         - a file containing lines matching that form
echo       In the latter case, the boot image is setup and booted
echo       for each host/RAC IP contained in the file.
echo       ^<DeviceID^> = ID of Device to bootonce into
echo       where DeviceID:
echo            0 = Disable - Disable this option
echo            1 = Virtual Flash/Virtual Media - Boot from virtual flash or virtual media device
echo            2 = Virtual Floppy - Boot from virtual Floppy device
echo            3 = Virtual CD/DVD/ISO - Boot from virtual CD/DVD/ISO device
echo            4 = PXE - Boot from network
echo            5 = Hard Drive - Boot from the default Hard Drive
echo            6 = Utility Partition - Boot into the Utility Partition 
echo                NOTE: The Utility Partition should exist
echo            7 = Default CD/DVD - Boot from the default CD/DVD drive
echo            8 = BIOS Setup - Reboot to the BIOS Setup screen
echo            9 = Primary Removable Media - Boot to the primary removable media
echo.
echo *Note: your boot image determines what is deployed, and how.
echo.
:done
endlocal
:xit

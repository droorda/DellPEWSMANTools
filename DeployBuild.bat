@Echo off

pushd %~dp0

for /f "delims=" %%i in ('git branch --show-current') do set Branch=%%i
IF /i "%Branch%"=="master" goto ReleaseStandard
IF /i "%Branch%"=="main" goto ReleaseStandard
IF /i "%Branch%"=="local" goto ReleaseStandard
IF /i "%Branch%"=="internal" goto ReleaseStandard

:ReleaseBeta
echo "Beta Build"
powershell.exe -inputformat none -ExecutionPolicy Bypass -NonInteractive -command "& .\Build\Start-Build.ps1 -Beta %*"
goto commonexit

:ReleaseStandard
echo "Standard Build"
powershell.exe -inputformat none -ExecutionPolicy Bypass -NonInteractive -command "& .\Build\Start-Build.ps1 %*"
goto commonexit


:commonexit

popd

pause

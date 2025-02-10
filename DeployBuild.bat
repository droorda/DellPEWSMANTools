@Echo off

pushd %~dp0

for /f "delims=" %%i in ('git branch --show-current') do set Branch=%%i
IF /i "%Branch%"=="master" goto ReleaseStandard

for /f "delims=" %%i in ('git branch --show-current') do set Branch=%%i
IF /i "%Branch%"=="main" goto ReleaseStandard

for /f "delims=" %%i in ('git branch --show-current') do set Branch=%%i
IF /i "%Branch%"=="local" goto ReleaseStandard

:ReleaseBeta
powershell.exe -inputformat none -ExecutionPolicy Bypass -NonInteractive -command "& .\Build\Start-Build.ps1 -Beta %*"
goto commonexit

:ReleaseStandard
powershell.exe -inputformat none -ExecutionPolicy Bypass -NonInteractive -command "& .\Build\Start-Build.ps1 %*"
goto commonexit


:commonexit

popd

pause

@Echo off

pushd %~dp0

powershell.exe -inputformat none -ExecutionPolicy Bypass -NonInteractive -command "& .\Build\Start-Build.ps1 %*"
REM powershell.exe -inputformat none -ExecutionPolicy Bypass -noprofile -NonInteractive -command "& .\Build\Start-Build.ps1 %*"

popd

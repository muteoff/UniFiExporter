@echo off
setlocal EnableDelayedExpansion


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::: Make edits according to your setup and needs under this line ::::::::::

set ExportDirectory=C:\Users\username\Export

set 8db88c62-7fd0-3737-aa4e-dae19bab87ea=cam1
set 245faecc-8b37-36dc-8f7b-f5097d30bc63=cam2

set GenerateListOnly=No

set ExportToday=No

set ScheduleDailyExecution=No
set ScheduleTime="03:00"

:::::::::: Make edits according to your setup and needs above this line ::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


if /I "%ScheduleDailyExecution%"=="yes" (
    schtasks /QUERY /TN "UniFiExporter" >NUL 2>&1 || schtasks /CREATE /RU "SYSTEM" /SC DAILY /TN "UniFiExporter" /TR '%0' /ST %ScheduleTime%
)

if not exist "%~dp0UniFiExporterFiles" mkdir "%~dp0UniFiExporterFiles"
if not exist "%~dp0UniFiExporterFiles\Log" mkdir "%~dp0UniFiExporterFiles\Log"
if not exist "%~dp0UniFiExporterFiles\Temp" mkdir "%~dp0UniFiExporterFiles\Temp"
if not exist "%~dp0UniFiExporterFiles\Temp\List" mkdir "%~dp0UniFiExporterFiles\Temp\List"
if not exist "%ExportDirectory%" mkdir "%ExportDirectory%"

if not exist "%~dp0UniFiExporterFiles\ffmpeg-4.4-essentials_build" (
    echo(
    echo Downloading FFMPEG...
    timeout 5 >NUL
    bitsadmin.exe /TRANSFER FFmpegDownloadJob /DOWNLOAD /PRIORITY FOREGROUND https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip "%~dp0UniFiExporterFiles\Temp\ffmpeg-release-essentials.zip"
    echo(
    echo Unpacking FFMPEG...
    powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%~dp0UniFiExporterFiles\Temp\ffmpeg-release-essentials.zip', '%~dp0UniFiExporterFiles'); }"
    del "%~dp0UniFiExporterFiles\Temp\ffmpeg-release-essentials.zip"
)

set current_date="%date:~10,4%-%date:~4,2%-%date:~7,2%"

echo(
echo Renaming chunks...
for /D %%I in ("%~dp0????????-????-????-????-????????????") do (
    for /D %%J in ("%%I\????") do (
        for /D %%K in ("%%J\??") do (
            for /D %%L in ("%%K\??") do (
                cd "%%L"
                ren *.mp4 *.ts
            )
        )
    )
)

del /Q "%~dp0UniFiExporterFiles\Temp\List\*.*"
echo(
echo Generating list of files...
for /D %%I in ("%~dp0????????-????-????-????-????????????") do (
    for /D %%J in ("%%I\????") do (
        for /D %%K in ("%%J\??") do (
            for /D %%L in ("%%K\??") do (
                for %%M in ("%%~fL\*.ts") do (
                    if not "!%%~nI!"=="" (
                        echo file '%%M' >> "%~dp0UniFiExporterFiles\Temp\List\%%~nJ-%%~nK-%%~nL-!%%~nI!.txt"
                    )
                )
            )
        )
    )
)

if /I "%ExportToday%"=="no" (
    if exist "%~dp0UniFiExporterFiles\Temp\List\%current_date%-*" (
        del /Q "%~dp0UniFiExporterFiles\Temp\List\%current_date%-*"
    )
)

if /I "%GenerateListOnly%"=="yes" (
    for /R "%~dp0UniFiExporterFiles\Temp\List" %%G in (*.txt) do (
        copy /Y nul "%~dp0UniFiExporterFiles\Log\%%~nG.txt" >nul    
    )
    
    echo(
    echo Renaming chunks back...
    echo(
    for /D %%I in ("%~dp0????????-????-????-????-????????????") do (
        for /D %%J in ("%%I\????") do (
            for /D %%K in ("%%J\??") do (
                for /D %%L in ("%%K\??") do (
                    cd "%%L"
                    ren *.ts *.mp4
                )
            )
        )
    )
    
    endlocal
    exit /B
)

echo(
for /R "%~dp0UniFiExporterFiles\Temp\List" %%G in (*.txt) do (
    if not exist "%~dp0UniFiExporterFiles\Log\%%~nG.txt" (
        echo Processing %%~nG...
        "%~dp0UniFiExporterFiles\ffmpeg-4.4-essentials_build\bin\ffmpeg.exe" -y -hide_banner -loglevel panic -stats -f concat -safe 0 -i "%~dp0UniFiExporterFiles\Temp\List\%%~nG.txt" -c copy "%~dp0UniFiExporterFiles\Temp\%%~nG.ts"
        "%~dp0UniFiExporterFiles\ffmpeg-4.4-essentials_build\bin\ffmpeg.exe" -y -hide_banner -loglevel panic -stats -i "%~dp0UniFiExporterFiles\Temp\%%~nG.ts" -c copy -movflags +faststart "%~dp0UniFiExporterFiles\Temp\%%~nG.mp4"
        move /Y "%~dp0UniFiExporterFiles\Temp\%%~nG.mp4" "%ExportDirectory%\%%~nG.mp4"
        del /Q "%~dp0UniFiExporterFiles\Temp\%%~nG.ts"
        copy /Y nul "%~dp0UniFiExporterFiles\Log\%%~nG.txt" >nul
        echo(
    )
)

echo Renaming chunks back...
echo(
for /D %%I in ("%~dp0????????-????-????-????-????????????") do (
    for /D %%J in ("%%I\????") do (
        for /D %%K in ("%%J\??") do (
            for /D %%L in ("%%K\??") do (
                cd "%%L"
                ren *.ts *.mp4
            )
        )
    )
)

endlocal
exit /B

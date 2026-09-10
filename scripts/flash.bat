@echo off
setlocal
cd /d "%~dp0"

set "VARIANT=%~1"
if "%VARIANT%"=="" set "VARIANT=standard"
if /i "%VARIANT%"=="standard" (
    set "OPENSBI_IMAGE=fw_dynamic-k1.itb"
) else if /i "%VARIANT%"=="rva23" (
    set "OPENSBI_IMAGE=fw_dynamic-k1-rva23.itb"
) else (
    echo Usage: %~nx0 [standard^|rva23]
    exit /b 2
)

where fastboot >nul 2>nul
if errorlevel 1 (
    echo Error: fastboot was not found in PATH.
    exit /b 1
)

for %%F in (
    "factory\FSBL.bin"
    "factory\bootinfo_spinor.bin"
    "partition_2M.json"
    "env.bin"
    "%OPENSBI_IMAGE%"
    "u-boot.itb"
) do (
    if not exist %%F (
        echo Error: missing artifact: %%~F
        exit /b 1
    )
)

echo Staging FSBL...
fastboot stage factory\FSBL.bin || exit /b 1
fastboot continue || exit /b 1
timeout /t 1 /nobreak >nul

echo Staging U-Boot...
fastboot stage u-boot.itb || exit /b 1
fastboot continue || exit /b 1
timeout /t 1 /nobreak >nul

echo Flashing SPI NOR...
fastboot flash mtd partition_2M.json || exit /b 1
fastboot flash bootinfo factory\bootinfo_spinor.bin || exit /b 1
fastboot flash fsbl factory\FSBL.bin || exit /b 1
fastboot flash env env.bin || exit /b 1
fastboot flash opensbi "%OPENSBI_IMAGE%" || exit /b 1
fastboot flash uboot u-boot.itb || exit /b 1

echo SPI NOR flashing completed successfully.
endlocal

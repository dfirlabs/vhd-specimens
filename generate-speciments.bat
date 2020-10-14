@echo off

rem Script to generate VHD test files
rem Requires Windows 7 or later

rem Split the output of ver e.g. "Microsoft Windows [Version 10.0.10586]"
rem and keep the last part "10.0.10586]".
for /f "tokens=1,2,3,4" %%a in ('ver') do (
	set version=%%d
)

rem Replace dots by spaces "10 0 10586]".
set version=%version:.= %

rem Split the last part of the ver output "10 0 10586]" and keep the first
rem 2 values formatted with a dot as separator "10.0".
for /f "tokens=1,2,*" %%a in ("%version%") do (
	set version=%%a.%%b
)

rem TODO add check for other supported versions of Windows
rem Also see: https://en.wikipedia.org/wiki/Ver_(command)

if not "%version%" == "10.0" (
	echo Unsupported Windows version: %version%

	exit /b 1
)

if exist "%version%" (
	echo Specimens directory: %version% already exists.

	exit /b 1
)

mkdir "%version%"

rem Create a fixed-size VHD image with a NTFS file system
set unitsize=4096
set imagename=fixed.vhd
set imagesize=256

echo create vdisk file=%cd%\%version%\%imagename% maximum=%imagesize% type=fixed > CreateVHD.diskpart
echo select vdisk file=%cd%\%version%\%imagename% >> CreateVHD.diskpart
echo attach vdisk >> CreateVHD.diskpart
echo convert mbr >> CreateVHD.diskpart
echo create partition primary >> CreateVHD.diskpart

echo format fs=ntfs label="TestVolume" unit=%unitsize% quick >> CreateVHD.diskpart

echo assign letter=x >> CreateVHD.diskpart

call :run_diskpart CreateVHD.diskpart

call :create_test_file_entries x

echo select vdisk file=%cd%\%version%\%imagename% > UnmountVHD.diskpart
echo detach vdisk >> UnmountVHD.diskpart

call :run_diskpart UnmountVHD.diskpart

rem Create a dynamic-size VHD image with a NTFS file system
set unitsize=4096
set imagename=dynamic.vhd
set imagesize=256

echo create vdisk file=%cd%\%version%\%imagename% maximum=%imagesize% type=expandable > CreateVHD.diskpart
echo select vdisk file=%cd%\%version%\%imagename% >> CreateVHD.diskpart
echo attach vdisk >> CreateVHD.diskpart
echo convert mbr >> CreateVHD.diskpart
echo create partition primary >> CreateVHD.diskpart

echo format fs=ntfs label="TestVolume" unit=%unitsize% quick >> CreateVHD.diskpart

echo assign letter=x >> CreateVHD.diskpart

call :run_diskpart CreateVHD.diskpart

call :create_test_file_entries x

echo select vdisk file=%cd%\%version%\%imagename% > UnmountVHD.diskpart
echo detach vdisk >> UnmountVHD.diskpart

call :run_diskpart UnmountVHD.diskpart

rem Create a dynamic-size VHD image with a fixed-size parent
set unitsize=4096
set imagename=parent.vhd
set imagesize=256

echo create vdisk file=%cd%\%version%\%imagename% maximum=%imagesize% type=fixed > CreateVHD.diskpart
echo select vdisk file=%cd%\%version%\%imagename% >> CreateVHD.diskpart
echo attach vdisk >> CreateVHD.diskpart
echo convert mbr >> CreateVHD.diskpart
echo create partition primary >> CreateVHD.diskpart

echo format fs=ntfs label="TestVolume" unit=%unitsize% quick >> CreateVHD.diskpart

echo assign letter=x >> CreateVHD.diskpart

call :run_diskpart CreateVHD.diskpart

for /f "tokens=2,3" %%a in ('echo list volume ^| diskpart') do (
    if %%b==X set volumenumber=%%a
)

echo select vdisk file=%cd%\%version%\%imagename% > UnmountVHD.diskpart
echo detach vdisk >> UnmountVHD.diskpart

call :run_diskpart UnmountVHD.diskpart

set imagename=child.vhd

echo create vdisk file=%cd%\%version%\%imagename% parent=%cd%\%version%\parent.vhd > CreateVHD.diskpart
echo select vdisk file=%cd%\%version%\%imagename% >> CreateVHD.diskpart
echo attach vdisk >> CreateVHD.diskpart

echo select volume=%volumenumber% >> CreateVHD.diskpart
echo assign letter=x >> CreateVHD.diskpart

call :run_diskpart CreateVHD.diskpart

call :create_test_file_entries x

echo select vdisk file=%cd%\%version%\%imagename% > UnmountVHD.diskpart
echo detach vdisk >> UnmountVHD.diskpart

call :run_diskpart UnmountVHD.diskpart

rem TODO: create differential image with bitmap that is not byte aligned

exit /b 0

rem Creates test file entries
:create_test_file_entries
SETLOCAL
SET driveletter=%1

rem Create an emtpy file
type nul >> %driveletter%:\emptyfile

rem Create a directory
mkdir %driveletter%:\testdir1

rem Create a file
echo My file > %driveletter%:\testdir1\testfile1

rem Create a hard link to a file
mklink /H %driveletter%:\file_hardlink1 %driveletter%:\testdir1\testfile1

rem Create a symbolic link to a file
mklink %driveletter%:\file_symboliclink1 %driveletter%:\testdir1\testfile1

rem Create a junction (hard link to a directory)
mklink /J %driveletter%:\directory_junction1 %driveletter%:\testdir1

rem Create a symbolic link to a directory
mklink /D %driveletter%:\directory_symboliclink1 %driveletter%:\testdir1

rem Create a file with an altenative data stream (ADS)
type nul >> %driveletter%:\ads1
echo My ADS > %driveletter%:\ads1:myads

ENDLOCAL
exit /b 0

rem Runs diskpart with a script
rem Note that diskpart requires Administrator privileges to run
:run_diskpart
SETLOCAL
set diskpartscript=%1

rem Note that diskpart requires Administrator privileges to run
diskpart /s %diskpartscript%

if %errorlevel% neq 0 (
	echo Failed to run: "diskpart /s %diskpartscript%"

	exit /b 1
)

del /q %diskpartscript%

rem Give the system a bit of time to adjust
timeout /t 1 > nul

ENDLOCAL
exit /b 0


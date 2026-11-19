@echo off
setlocal EnableExtensions
title kurasagi local build (direct cl/link)

rem ------------------------------------------------------------------
rem  Workaround for the WDK / Visual Studio mismatch on this machine:
rem  WindowsDriver.Common.targets picks the DriverKit task assembly by
rem  $(VisualStudioVersion); VS 2022 asks for Microsoft.DriverKit.Build
rem  Tasks.17.0.dll but WDK 10.0.28000.0 only ships the 18.0 (VS 2026)
rem  build, so MSBuild dies with MSB4062 inside StampInf.
rem  This script skips the WDK MSBuild toolset and drives cl.exe /
rem  link.exe directly. Same flags as build_direct.bat, minus the
rem  cmd parsing bug caused by the parentheses in Program Files (x86).
rem  Output: x64\Release\kurasagi.sys
rem ------------------------------------------------------------------

set "ROOT=%~dp0"
if not exist "%ROOT%kurasagi\Entry.cpp" (
    echo [ERROR] kurasagi sources not found next to this script.
    exit /b 1
)

rem 8.3 form of Program Files (x86): parentheses break cmd blocks.
for %%A in ("%ProgramFiles(x86)%") do set "PF86=%%~sA"
if not defined PF86 set "PF86=%ProgramFiles(x86)%"
set "WDK_ROOT=%PF86%\Windows Kits\10"

rem --- newest WDK that has kernel headers ---
set "WDK_VER="
for /f "delims=" %%V in ('dir /b /ad /o-n "%WDK_ROOT%\Include\10.*" 2^>nul') do (
    if not defined WDK_VER if exist "%WDK_ROOT%\Include\%%V\km\ntddk.h" set "WDK_VER=%%V"
)
if not defined WDK_VER (
    echo [ERROR] No WDK kernel headers under "%WDK_ROOT%\Include".
    exit /b 1
)
echo [1/3] WDK %WDK_VER%

rem --- newest MSVC toolset that ships Hostx64\x64\cl.exe ---
set "MSVC="
for /d %%D in ("%PF86%\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.*") do (
    if exist "%%~D\bin\Hostx64\x64\cl.exe" for %%S in ("%%~D") do set "MSVC=%%~sS"
)
if not defined MSVC for /d %%D in ("%PF86%\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.*") do (
    if exist "%%~D\bin\Hostx64\x64\cl.exe" for %%S in ("%%~D") do set "MSVC=%%~sS"
)
if not defined MSVC (
    echo [ERROR] cl.exe not found in the VS 2022 / 2026 build tools.
    exit /b 1
)
echo [2/3] MSVC %MSVC%

set "CLPATH=%MSVC%\bin\Hostx64\x64\cl.exe"
set "LINKPATH=%MSVC%\bin\Hostx64\x64\link.exe"
rem CL / LINK are MSVC default-option env vars; clear them so cl.exe
rem does not read our own paths back as source files.
set "CL="
set "LINK="
set "VCINC=%MSVC%\include"
set "WDKINC=%WDK_ROOT%\Include\%WDK_VER%"
set "WDKLIB=%WDK_ROOT%\Lib\%WDK_VER%\km\x64"
set "OUT=%ROOT%x64\Release"
set "OBJ=%OUT%\obj"
if not exist "%OBJ%" mkdir "%OBJ%" >nul 2>&1
if not exist "%OUT%" mkdir "%OUT%" >nul 2>&1

echo [3/3] Compiling ...
pushd "%ROOT%kurasagi"
"%CLPATH%" /c /nologo /GS- /Qspectre- /O2 /Gy /Zc:wchar_t /Zc:forScope /Zc:inline /Gd /TP /std:c++17 /D_AMD64_ /DAMD64 /D_WIN32_WINNT=0x0A00 /DNTDDI_VERSION=0x0A000008 /I"%WDKINC%\km" /I"%WDKINC%\shared" /I"%WDKINC%\ucrt" /I"%VCINC%" /Fd"%OBJ%\kurasagi.pdb" /Fo"%OBJ%\\" Entry.cpp Global.cpp Module.cpp Module\Barricade.cpp Module\Context7.cpp Module\Misc.cpp Module\Timer.cpp Util\Arith.cpp Util\Memory.cpp
set "CL_RC=%ERRORLEVEL%"
popd
if not "%CL_RC%"=="0" (
    echo [ERROR] Compilation failed.
    exit /b 1
)

echo Linking ...
"%LINKPATH%" /nologo /DRIVER /SUBSYSTEM:NATIVE /MACHINE:X64 /ENTRY:DriverEntry /NODEFAULTLIB /INCREMENTAL:NO /OPT:REF /OPT:ICF /MANIFEST:NO /FIXED:NO /OUT:"%OUT%\kurasagi.sys" /MAP:"%OUT%\kurasagi.map" /LIBPATH:"%WDKLIB%" "%OBJ%\Entry.obj" "%OBJ%\Global.obj" "%OBJ%\Module.obj" "%OBJ%\Barricade.obj" "%OBJ%\Context7.obj" "%OBJ%\Misc.obj" "%OBJ%\Timer.obj" "%OBJ%\Arith.obj" "%OBJ%\Memory.obj" ntoskrnl.lib BufferOverflowK.lib libcntpr.lib hal.lib
if errorlevel 1 (
    echo [ERROR] Link failed.
    exit /b 1
)

echo.
echo [OK] Output: %OUT%\kurasagi.sys
exit /b 0

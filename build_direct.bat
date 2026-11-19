@echo off
setlocal EnableExtensions
title kurasagi direct build (cl/link)

rem ============================================================
rem  Direct kernel driver build - bypasses the WDK MSBuild toolset.
rem  Produces: x64\Release\kurasagi.sys
rem  Usage: put this file next to kurasagi.sln and run it.
rem ============================================================

set "ROOT=%~dp0"
set "WDK_ROOT=%ProgramFiles(x86)%\Windows Kits\10"
set "WDK_VER=10.0.28000.0"
set "OUT=%ROOT%x64\Release"
set "OBJ=%OUT%\obj"

echo.
echo ====================================================
echo   kurasagi direct build  ^|  Release x64
echo ====================================================
echo.

if not exist "%ROOT%kurasagi\Entry.cpp" (
    echo [ERROR] Could not find kurasagi sources next to this script.
    goto :fail
)

if not exist "%WDK_ROOT%\Include\%WDK_VER%\km\ntddk.h" (
    echo [ERROR] WDK headers not found:
    echo         %WDK_ROOT%\Include\%WDK_VER%\km
    echo         Edit WDK_VER at the top of this script if you use another version.
    goto :fail
)

if not exist "%WDK_ROOT%\Lib\%WDK_VER%\km\x64\ntoskrnl.lib" (
    echo [ERROR] WDK kernel libs not found:
    echo         %WDK_ROOT%\Lib\%WDK_VER%\km\x64
    goto :fail
)

echo [1/3] Locating MSVC compiler ...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "CL="

if not exist "%VSWHERE%" goto :cl_done
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find VC\Tools\MSVC\**\bin\Hostx64\x64\cl.exe`) do if not defined CL set "CL=%%i"
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -all -products * -find VC\Tools\MSVC\**\bin\Hostx86\x64\cl.exe`) do if not defined CL set "CL=%%i"
:cl_done

if not defined CL (
    echo [ERROR] cl.exe not found. Install the Visual C++ x64 build tools.
    goto :fail
)

for %%I in ("%CL%") do set "TOOLDIR=%%~dpI"
set "LINK=%TOOLDIR%link.exe"
set "VCINC=%TOOLDIR%..\..\..\include"

echo         %CL%

echo [2/3] Compiling ...
if not exist "%OBJ%" mkdir "%OBJ%" >nul 2>&1
if not exist "%OUT%" mkdir "%OUT%" >nul 2>&1

set "WDKINC=%WDK_ROOT%\Include\%WDK_VER%"
set "WDKLIB=%WDK_ROOT%\Lib\%WDK_VER%\km\x64"

"%CL%" /c /nologo /GS- /Qspectre- /O2 /Gy /Zc:wchar_t /Zc:forScope /Zc:inline /Gd /TP /std:c++17 ^
 /D_AMD64_ /DAMD64 /D_WIN32_WINNT=0x0A00 /DNTDDI_VERSION=0x0A000008 ^
 /I"%WDKINC%\km" /I"%WDKINC%\shared" /I"%WDKINC%\ucrt" /I"%VCINC%" ^
 /Fd"%OBJ%\kurasagi.pdb" /Fo"%OBJ%\\" ^
 "%ROOT%kurasagi\Entry.cpp" "%ROOT%kurasagi\Global.cpp" "%ROOT%kurasagi\Module.cpp" ^
 "%ROOT%kurasagi\Module\Barricade.cpp" "%ROOT%kurasagi\Module\Context7.cpp" ^
 "%ROOT%kurasagi\Module\Misc.cpp" "%ROOT%kurasagi\Module\Timer.cpp" ^
 "%ROOT%kurasagi\Util\Arith.cpp" "%ROOT%kurasagi\Util\Memory.cpp"

if errorlevel 1 (
    echo [ERROR] Compilation failed, see messages above.
    goto :fail
)

echo [3/3] Linking ...
set "LIBS=ntoskrnl.lib BufferOverflowK.lib libcntpr.lib"
if exist "%WDKLIB%\hal.lib" set "LIBS=%LIBS% hal.lib"
if not exist "%WDKLIB%\libcntpr.lib" echo [WARN] libcntpr.lib not found in WDK libs.

"%LINK%" /nologo /DRIVER /SUBSYSTEM:NATIVE /MACHINE:X64 /ENTRY:DriverEntry ^
 /NODEFAULTLIB /INCREMENTAL:NO /OPT:REF /OPT:ICF /MANIFEST:NO /FIXED:NO ^
 /OUT:"%OUT%\kurasagi.sys" /LIBPATH:"%WDKLIB%" ^
 "%OBJ%\Entry.obj" "%OBJ%\Global.obj" "%OBJ%\Module.obj" ^
 "%OBJ%\Barricade.obj" "%OBJ%\Context7.obj" "%OBJ%\Misc.obj" "%OBJ%\Timer.obj" ^
 "%OBJ%\Arith.obj" "%OBJ%\Memory.obj" %LIBS%

if errorlevel 1 (
    echo [ERROR] Link failed, see messages above.
    goto :fail
)

echo.
echo [OK] Driver built:
dir /b "%OUT%\kurasagi.sys"
echo      Full path: %OUT%\kurasagi.sys
exit /b 0

:fail
echo.
echo [FAILED] Build did not complete.
exit /b 1

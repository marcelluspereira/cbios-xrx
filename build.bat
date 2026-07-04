@echo off
IF %2.==. GOTO NOOPT
echo Assembling %1.asm
goto %2
:NOOPT
echo Error! build.bat should be called from make.bat, please run make.bat
goto no_error
:tniasm
tniasm ..\tools\tniasm-compat %1.asm ..\derived\bin\cbios_%1.rom ..\derived\lst\cbios_%1.sym 1> NUL
if errorlevel 1 goto error
GOTO no_error
:pasmo
C:\Users\marce\Desktop\cbios-0.29a\pasmo.exe -d %1.asm ..\derived\bin\cbios_%1.rom > ..\derived\lst\cbios_%1.sym
if errorlevel 1 goto error
goto no_error
:zds
mkdir ..\derived\obj 2> NUL
mkdir ..\derived\hex 2> NUL
pushd ..\derived\zdsasm
"C:\Program Files (x86)\ZiLOG\ZDS_3.68\bin\zma.exe" -pZ380 -dZDS_BUILD=1 -I. -I..\asm -I..\..\src -l..\lst\cbios_%1.lst -o..\obj\cbios_%1.o %1.asm
set ZDS_ERROR=%errorlevel%
popd
if not "%ZDS_ERROR%"=="0" goto error
findstr /C:"ZMA-E" ..\derived\lst\cbios_%1.lst > NUL
if not errorlevel 1 goto error
"C:\Program Files (x86)\ZiLOG\ZDS_3.68\bin\Zld.exe" -A -a -o ..\derived\hex\cbios_%1.hex ..\derived\obj\cbios_%1.o
if errorlevel 1 goto error
set ZDS_BASE=0x4000
set ZDS_SIZE=16384
echo %1 | findstr /B /C:"main_" > NUL && set ZDS_BASE=0 && set ZDS_SIZE=32768
echo %1 | findstr /B /C:"logo_" > NUL && set ZDS_BASE=0x8000
if /I "%1"=="sub" set ZDS_BASE=0
python ..\tools\intelhex_to_bin.py ..\derived\hex\cbios_%1.hex ..\derived\bin\cbios_%1.rom --base %ZDS_BASE% --size %ZDS_SIZE%
if not "%errorlevel%"=="0" goto error
goto no_error
:error
exit /b 1
:no_error
exit /b 0

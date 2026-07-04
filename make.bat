@echo off
mkdir derived\bin 2> NUL
mkdir derived\lst 2> NUL
IF %1.==. GOTO NOOPT

rem -- TODO: get the SVN version of Changelog into version.asm
mkdir derived\asm 2> NUL
del derived\asm\version.asm 2> NUL
set /p CBIOS_VER=<version.txt
echo   db "C-BIOS %CBIOS_VER%      cbios.sf.net"> derived\asm\version.asm

cd src
IF %1.==pasmo. GOTO ASM
IF %1.==tniasm. GOTO ASM
IF %1.==zds. GOTO PREPZDS
:NOOPT
echo usage make.bat [pasmo or tniasm or zds]
GOTO QUIT
:PREPZDS
cd ..
mkdir derived\zdsasm 2> NUL
powershell -NoProfile -ExecutionPolicy Bypass -File tools\preprocess_zds.ps1 -SourceDir src -OutputDir derived\zdsasm -VersionFile version.txt
cd src
GOTO ASM
:ASM
FOR %%i IN (main_msx1;main_msx2;main_msx2+) DO call ..\build %%i %1
FOR %%i IN (basic;sub;music;disk;logo_msx1;logo_msx2;logo_msx2+) DO call ..\build %%i %1
FOR %%i IN (main_msx1_eu;main_msx2_eu;main_msx2+_eu) DO call ..\build %%i %1
FOR %%i IN (main_msx1_jp;main_msx2_jp;main_msx2+_jp) DO call ..\build %%i %1
FOR %%i IN (main_msx1_br;main_msx2_br;main_msx2+_br) DO call ..\build %%i %1
:END
cd ..
:QUIT

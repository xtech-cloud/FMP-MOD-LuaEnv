
@echo off

REM !!! Generated by the fmp-cli 1.86.0.  DO NOT EDIT!

md LuaEnv\Assets\3rd\fmp-xtc-luaenv

cd ..\vs2022
dotnet build -c Release

copy fmp-xtc-luaenv-lib-mvcs\bin\Release\netstandard2.1\*.dll ..\unity2021\LuaEnv\Assets\3rd\fmp-xtc-luaenv\

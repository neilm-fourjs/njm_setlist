@echo off
rem -- You must complete the following line. FGLDIR must be set to the home directory of the DVM --
set FGLDIR=C:\FourJs\gst-3.00.28\fgl
set FGLPROFILE=%FGLDIR%\etc\fglprofile
rem -- Warning: We add the lib directory to resolve user extension dependencies --
rem -- when an IMPORTED DLL uses another DLL provided in FGLDIR\lib. --
set PATH=%FGLDIR%\bin;%FGLDIR%\lib;%PATH%

set FGLRESOURCEPATH=..\etc

set FGLPROFILE=..\etc\fglprofile

set FGLIMAGEPATH=..\pics\image2font.txt;..\pics

cd bin

fglrun setlist.42r


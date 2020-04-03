@set oldpath=%path%
@set path=c:\bcc7\bin;%oldpath%
..\harbour\bin\win\bcc\hbmk2.exe hbide.hbp -comp=bcc
hbide.exe
@set path=%oldpath%
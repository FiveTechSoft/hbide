#include 'hbclass.ch'
PROCEDURE Main()
 LOCAL cDir:=hb_DirTemp()+'hbide-stamp-'+hb_ntos(hb_RandomInt(999999999)),o,cFile,cBefore,cOther,nPass:=0,nFail:=0
 hb_DirCreate(cDir)
 o:=HBSrcEdit():New('',2,1,20,79,.T.)
 cFile:=cDir+'/literal*.prg'
 cOther:=cDir+'/literal-other.prg'
 hb_MemoWrit(cOther,Replicate('X',8*1024*1024+1))
 hb_MemoWrit(cFile,'AAAA')
 cBefore:=o:DiskStamp(cFile)
 Check(!Empty(cBefore),'literal file stamp present',@nPass,@nFail)
 Check(hb_MD5('AAAA') $ cBefore,'small literal file hashes its own bytes despite large matching sibling',@nPass,@nFail)
 hb_MemoWrit(cFile,'BBBB')
 Check(cBefore!=o:DiskStamp(cFile),'same-size literal change detected',@nPass,@nFail)
 cBefore:=o:DiskStamp(cFile)
 hb_MemoWrit(cOther,'OTHER')
 Check(cBefore==o:DiskStamp(cFile),'matching sibling change does not affect literal stamp',@nPass,@nFail)
 o:cFile:=cFile;o:cLoadStamp:=o:cSeenStamp:=cBefore
 FErase(cFile)
 Check(o:FileVanished(),'literal deletion is vanished despite matching sibling',@nPass,@nFail)
 FErase(cOther);hb_DirDelete(cDir)
 ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
 ErrorLevel(iif(nFail==0,0,1))
 RETURN
STATIC PROCEDURE Check(lOk,cName,nPass,nFail)
 IF lOk
  nPass++
  ? 'PASS',cName
 ELSE
  nFail++
  ? 'FAIL:',cName
 ENDIF
 RETURN
FUNCTION HBIDE_MsgAlert(cText)
 RETURN 1

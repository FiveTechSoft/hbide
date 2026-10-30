// Boundary fixture: a competing creator arrives after temp name selection.
#include "fileio.ch"
PROCEDURE Main(cResult)
   LOCAL cTmp:=cResult+".candidate",nHandle,h:={=>}
   FErase(cTmp)
   h["selected_name_absent"]:=!hb_FileExists(cTmp)
   hb_MemoWrit(cTmp,"OTHER OWNER")
   hb_MemoWrit(cTmp,"EDITOR BYTES")
   h["unchecked_write_clobbered_competitor"]:=hb_MemoRead(cTmp)=="EDITOR BYTES"
   hb_MemoWrit(cTmp,"OTHER OWNER")
   nHandle:=hb_FCreate(cTmp,FC_NORMAL,FO_EXCL)
   h["exclusive_create_refused"]:=nHandle==F_ERROR
   IF nHandle!=F_ERROR
      FClose(nHandle)
   ENDIF
   h["exclusive_path_preserved_competitor"]:=hb_MemoRead(cTmp)=="OTHER OWNER"
   FErase(cTmp)
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   IF !(h["unchecked_write_clobbered_competitor"].and.h["exclusive_create_refused"].and.h["exclusive_path_preserved_competitor"])
      ErrorLevel(1)
   ENDIF
   RETURN

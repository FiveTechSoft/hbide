// Research only: HRB unload is not application/process state reset.
#include "hbhrb.ch"
#include "set.ch"
REQUEST HB_HRBLOAD, HB_HRBDO, HB_HRBUNLOAD, DBCREATE, DBUSEAREA, DBAPPEND, FIELDPUT, DBFCDX
PROCEDURE Main(cResult)
   LOCAL h:={=>},oHrb,cBody,xBreak,nOldDecimals:=Set(_SET_DECIMALS),cDb:=cResult+".dbf"
   LOCAL cCode:="procedure Main(cDb)"+hb_eol()+;
      "PUBLIC restart_probe_public"+hb_eol()+;
      'restart_probe_public:="left-behind"'+hb_eol()+;
      "Set(3,7)"+hb_eol()+;
      'dbCreate(cDb,{{"MARK","C",8,0}},"DBFCDX",.T.,"PROBERES")'+hb_eol()+;
      'dbAppend()'+hb_eol()+;
      'FieldPut(1,"written")'+hb_eol()+;
      'Break("probe-abort")'+hb_eol()+"return"+hb_eol()
   cBody:=hb_CompileFromBuf(cCode,"probe","-n","-q2")
   oHrb:=hb_hrbLoad(HB_HRB_BIND_FORCELOCAL,cBody)
   BEGIN SEQUENCE
      hb_hrbDo(oHrb,cDb)
   RECOVER USING xBreak
      h["caught"]:=xBreak=="probe-abort"
   END SEQUENCE
   hb_hrbUnload(oHrb)
   h["public_survives"]:=__mvExist("RESTART_PROBE_PUBLIC")
   h["decimals_after_unload"]:=Set(_SET_DECIMALS)
   h["workarea_survives"]:=Select("PROBERES")>0
   IF Select("PROBERES")>0
      dbSelectArea("PROBERES")
      h["record_survives"]:=AllTrim(FieldGet(1))=="written"
      dbCloseArea()
   ENDIF
   Set(_SET_DECIMALS,nOldDecimals)
   __mvXRelease("RESTART_PROBE_PUBLIC")
   h["file_survives"]:=hb_FileExists(cDb)
   hb_MemoWrit(cResult,hb_jsonEncode(h))
   FErase(cDb)
   IF !(h["public_survives"].and.h["decimals_after_unload"]==7.and.h["workarea_survives"].and.h["record_survives"].and.h["file_survives"])
      ErrorLevel(1)
   ENDIF
   RETURN

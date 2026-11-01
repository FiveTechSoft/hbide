// Research only. Frame inspection supplements the zero-argument GT hook.
// Not screen swapping or a production policy for unknown VM entry paths.
// __vmNoInternals is irreversible for this isolated process; never call in IDE.
#include 'hbgtinfo.ch'
STATIC aCalls := {}
PROCEDURE Main(cResult)
 LOCAL bOld:=hb_gtInfo(HB_GTI_INKEYREAD,{||RecordFrame()}),a:={},c:='abc',GetList:={}
 Inkey()
 Inkey(.01)
 Inkey(.01,128)
 Inkey(NIL,128)
 Inkey(0)
 Inkey('bad')
 Eval({||Inkey(.01)})
 @ 2,2 GET c
 READ
 __Accept('')
 hb_idleSleep(.01)
 __vmNoInternals()
 Inkey()
 Inkey(.01)
 hb_gtInfo(HB_GTI_INKEYREAD,bOld)
 a:=aCalls
 hb_MemoWrit(cResult,hb_jsonEncode(a))
 RETURN
STATIC FUNCTION RecordFrame()
 LOCAL i,cName,aParams,aFrames:={},cMode:='unknown'
 IF ! FrameAccess('probe-sentinel')
  AAdd(aCalls,{'unavailable',{}, {}})
  RETURN 13
 ENDIF
 FOR i:=1 TO 12
  cName:=ProcName(i)
  IF Empty(cName)
   EXIT
  ENDIF
  aParams:=__dbgVMParLList(i)
  // Preserve only the known INKEY arguments. Other frames can contain data.
  AAdd(aFrames,{i,cName})
  IF cName=='INKEY'
   IF Len(aParams)==0
    cMode:='poll'
   ELSEIF Len(aParams)==1
    cMode:='wait'
   ELSEIF HB_ISNUMERIC(aParams[1])
    cMode:='wait'
   ELSE
    cMode:='poll'
   ENDIF
   AAdd(aCalls,{cMode,aParams,aFrames})
   RETURN 13
  ENDIF
 NEXT
 AAdd(aCalls,{cMode,{},aFrames})
 RETURN 13

STATIC FUNCTION FrameAccess(cSentinel)
 LOCAL a:=__dbgVMParLList(0)
 RETURN Len(a)==1 .AND. a[1]==cSentinel

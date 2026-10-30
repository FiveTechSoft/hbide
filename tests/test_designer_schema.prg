#include "error.ch"
PROCEDURE Main()
   LOCAL a:={{"type"=>"listbox"}},oError,cType,cName,cEvent,cCode,nConflicts,bOld:=ErrorBlock({|e|Break(e)})
   BEGIN SEQUENCE
      DsnNormalizeControls(a)
      Check(Len(a)==1.and.HB_IsString(a[1,"items"]),"missing list items default")
      FOR EACH cType IN {"radiogroup","listbox","combobox"}
         a:={{"type"=>cType,"items"=>123,"variable"=>.F.}}
         DsnNormalizeControls(a)
         Check(HB_IsString(a[1,"items"]).and.HB_IsString(a[1,"variable"]),"invalid items/variable repaired")
         Check(HB_IsString(DsnGenCode({"controls"=>a})),"normalized controls generate")
      NEXT
      a:={{"type"=>"get","variable"=>123}}
      DsnNormalizeControls(a)
      Check(HB_IsString(a[1,"variable"]).and.!Empty(a[1,"variable"]),"nontext variable repaired")
      FOR EACH cName IN {"oDlg","ODLG","GetList","lOk","lDummy"}
         a:={DsnNewControl("get",{})}
         a[1,"variable"]:=cName
         cCode:=DsnGenCode({"controls"=>a},NIL,@nConflicts)
         Check(nConflicts==1,"generator-owned local collision resolved")
      NEXT
      a:={DsnNewControl("get",{}),DsnNewControl("checkbox",{})}
      a[1,"variable"]:="Shared"
      a[2,"variable"]:="sHaReD"
      cCode:=DsnGenCode({"controls"=>a},NIL,@nConflicts)
      Check(nConflicts==1,"case-insensitive cross-type collision resolved")
      FOR EACH cEvent IN {"when","valid","focus","state"}
         a:={DsnNewControl("combobox",{})}
         a[1,cEvent]:=123
         DsnNormalizeControls(a)
         cCode:=DsnGenCode({"controls"=>a})
         Check(!("{|| 123"$cCode),"nontext event ignored")
      NEXT
      a:={{"type"=>"combo"},{"type"=>""}}
      DsnNormalizeControls(a)
      Check(Empty(a),"partial type names rejected")
   RECOVER USING oError
      ? "FAIL: normalization raised",oError:Description,oError:Operation
      ErrorLevel(1)
   END SEQUENCE
   ErrorBlock(bOld)
   ? "PASS schema probe"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN

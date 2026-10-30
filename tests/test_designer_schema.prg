#include "error.ch"
PROCEDURE Main()
   LOCAL a:={{"type"=>"listbox"}},oError,cType,bOld:=ErrorBlock({|e|Break(e)})
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

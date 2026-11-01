// Characterize current Harbour INKEYREAD API. This is not Swap on Input acceptance.
#include 'hbgtinfo.ch'
static aCalls := {}
static nPass := 0, nFail := 0
procedure Check(cName,lOk)
   if lOk
      nPass++
      ? 'PASS',cName
   else
      nFail++
      ? 'FAIL:',cName
   endif
return
procedure Main()
   local bOld, aPoll, aWait, bRestore
   bOld := hb_gtInfo(HB_GTI_INKEYREAD,{|...| AAdd(aCalls,hb_AParams()),0})
   Inkey()
   aPoll := AClone(aCalls)
   aCalls := {}
   Inkey(.01)
   aWait := AClone(aCalls)
   bRestore := hb_gtInfo(HB_GTI_INKEYREAD,bOld)
   Check('poll invokes hook once',Len(aPoll)==1)
   Check('timed wait invokes hook once',Len(aWait)==1)
   if Len(aPoll)==1.and.Len(aWait)==1
      Check('poll hook receives no arguments',Len(aPoll[1])==0)
      Check('timed wait hook receives no arguments',Len(aWait[1])==0)
   endif
   Check('installed hook can be restored',HB_ISBLOCK(bRestore))
   ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
   ErrorLevel(iif(nFail==0,0,1))
return

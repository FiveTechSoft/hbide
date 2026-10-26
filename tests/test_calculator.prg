#include "inkey.ch"
// Model test for demos/calculator.prg. Build:
//   hbmk2 tests/test_calculator.prg demos/calculator.prg -dCALC_TEST -gttrm
// Result file: /tmp/hbide-calculator-tests.txt
PROCEDURE Main()
   LOCAL h,i
   h:=CalcState()
   Assert(h['display']=='0' .AND. h['focus']==1,'fresh state')
   CalcKey(h,Asc('1'));CalcKey(h,Asc('2'))
   Assert(h['display']=='12','digit entry appends')
   CalcKey(h,Asc('+'));CalcKey(h,Asc('7'));CalcKey(h,Asc('='))
   Assert(h['display']=='19','addition')
   // immediate execution, no precedence: 2+3*4 = 20
   h:=CalcState()
   CalcKey(h,Asc('2'));CalcKey(h,Asc('+'));CalcKey(h,Asc('3'));CalcKey(h,Asc('*'));CalcKey(h,Asc('4'));CalcKey(h,Asc('='))
   Assert(h['display']=='20','immediate execution left to right')
   // decimal division
   h:=CalcState()
   CalcKey(h,Asc('1'));CalcKey(h,Asc('0'));CalcKey(h,Asc('/'));CalcKey(h,Asc('4'));CalcKey(h,Asc('='))
   Assert(h['display']=='2.5','decimal division')
   // division by zero, recovery by typing a digit
   h:=CalcState()
   CalcKey(h,Asc('5'));CalcKey(h,Asc('/'));CalcKey(h,Asc('0'));CalcKey(h,Asc('='))
   Assert(h['display']=='Error' .AND. h['error'],'division by zero flags error')
   CalcKey(h,Asc('7'))
   Assert(h['display']=='7' .AND. ! h['error'],'digit recovers from error')
   // C clears everything
   CalcKey(h,Asc('C'))
   Assert(h['display']=='0' .AND. h['acc']==0 .AND. h['op']=='','C resets')
   // decimal multiply renders without trailing zeros
   h:=CalcState()
   CalcKey(h,Asc('1'));CalcKey(h,Asc('.'));CalcKey(h,Asc('5'));CalcKey(h,Asc('*'));CalcKey(h,Asc('2'));CalcKey(h,Asc('='))
   Assert(h['display']=='3','decimal multiply compact render')
   // dot accepted once
   h:=CalcState()
   CalcKey(h,Asc('1'));CalcKey(h,Asc('.'));CalcKey(h,Asc('2'));CalcKey(h,Asc('.'));CalcKey(h,Asc('3'))
   Assert(h['display']=='1.23','dot entered once')
   // leading zero replaced, not appended
   h:=CalcState()
   CalcKey(h,Asc('0'));CalcKey(h,Asc('5'))
   Assert(h['display']=='5','leading zero replaced')
   // display capped at 12 digits
   h:=CalcState()
   FOR i:=1 TO 15;CalcKey(h,Asc('9'));NEXT
   Assert(Len(h['display'])==12,'display digit cap')
   // backspace edits, stops at 0
   h:=CalcState()
   CalcKey(h,Asc('1'));CalcKey(h,Asc('2'));CalcKey(h,K_BS)
   Assert(h['display']=='1','backspace deletes digit')
   CalcKey(h,K_BS)
   Assert(h['display']=='0','backspace stops at zero')
   // focus navigation with clamps and wrap
   h:=CalcState()
   CalcKey(h,K_RIGHT);Assert(h['focus']==2,'right moves focus')
   CalcKey(h,K_LEFT);Assert(h['focus']==1,'left moves focus')
   CalcKey(h,K_LEFT);Assert(h['focus']==17,'left wraps to last')
   CalcKey(h,K_RIGHT);Assert(h['focus']==1,'right wraps to first')
   CalcKey(h,K_UP);Assert(h['focus']==1,'up clamps at top row')
   h['focus']:=16;CalcKey(h,K_DOWN);Assert(h['focus']==17,'down clamps at last')
   CalcKey(h,K_UP);Assert(h['focus']==13,'up moves a row')
   // Enter presses the focused button and reports its index
   h:=CalcState()
   CalcKey(h,K_RIGHT)
   Assert(CalcKey(h,K_ENTER)==2,'enter presses focused button')
   Assert(h['display']=='7','focused button enters its digit')
   // typing a key moves focus to that button
   h:=CalcState()
   Assert(CalcKey(h,Asc('9'))==3 .AND. h['focus']==3,'typed key focuses its button')
   Assert(h['display']=='9','typed key enters digit')
   // after =, a digit starts a new number
   h:=CalcState()
   CalcKey(h,Asc('5'));CalcKey(h,Asc('+'));CalcKey(h,Asc('5'));CalcKey(h,Asc('='))
   Assert(h['display']=='10','sum renders')
   CalcKey(h,Asc('2'))
   Assert(h['display']=='2','digit after equals starts new entry')
   hb_MemoWrit('/tmp/hbide-calculator-tests.txt','PASS entry/arithmetic/immediate-execution/dot/backspace/focus/error-recovery')
   RETURN
PROCEDURE Assert(l,c)
   IF ! l
      hb_MemoWrit('/tmp/hbide-calculator-tests.txt','FAIL '+c)
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN

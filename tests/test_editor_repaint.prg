#include "hbclass.ch"
#include "inkey.ch"
static nPass := 0, nFail := 0
function HBIDE_MsgAlert( cText )
   HB_SYMBOL_UNUSED( cText )
return 1
class PaintProbe from HBSrcEdit
   data nLines init 0
   data nFull init 0
   method DisplayLine( n )
   method Display()
endclass
method DisplayLine( n ) class PaintProbe
   ::nLines++
return ::Super:DisplayLine( n )
method Display() class PaintProbe
   ::nFull++
return ::Super:Display()
procedure Check( cName, lOk )
   if lOk
      nPass++
   else
      nFail++
      hb_MemoWrit( '/tmp/hbide-repaint-failure.txt', cName )
   endif
return
procedure Main()
   local o := PaintProbe():New( 'local a := 1' + hb_eol() + 'return a', 2, 1, 20, 79, .T. )
   local cText
   o:GoTo( 1, 5 )
   o:nLines := o:nFull := 0
   o:Edit( Asc( 'x' ) )
   Check( 'ordinary char exactly one colored line', o:nLines == 1 .and. o:nFull == 0 )
   Check( 'ordinary char persisted', Left( o:GetText(), 1 ) == 'x' )
   o:Undo()
   Check( 'undo restores text', Left( o:GetText(), 5 ) == 'local' )
   o:Redo()
   Check( 'redo restores char', Left( o:GetText(), 1 ) == 'x' )
   o:LoadText( 'local a := 1' + hb_eol() + 'return a' )
   o:GoTo( 1, 5 )
   o:Edit( Asc( '/' ) )
   o:nLines := o:nFull := 0
   o:Edit( Asc( '*' ) )
   Check( 'comment opening full repaint', o:nFull >= 1 )
   Check( 'comment state propagates', o:BlkCmtState( 2 ) )
   o:Edit( Asc( '*' ) )
   o:nLines := o:nFull := 0
   o:Edit( Asc( '/' ) )
   Check( 'comment closing full repaint', o:nFull >= 1 )
   Check( 'comment closed below', ! o:BlkCmtState( 2 ) )
   o:LoadText( 'local alpha := 1' + hb_eol() + 'local beta := 2' + hb_eol() + 'return alpha + beta' )
   o:GoTo( 1, 5 )
   o:Display()
   Inkey( 1 )
   o:Edit( Asc( '/' ) )
   o:Edit( Asc( '*' ) )
   Inkey( 1 )
   o:Display()
   Inkey( 1 )
   o:LoadText( Replicate( 'a', 200 ) )
   o:GoTo( 1, 205 )
   o:Edit( Asc( 'z' ) )
   Check( 'horizontal scroll preserves typed char', Right( o:GetText(), 1 ) == 'z' )
   o:LoadText( 'abcdef' )
   o:GoTo( 1, 5 )
   o:Edit( K_F8 )
   o:Edit( K_RIGHT )
   o:Edit( K_RIGHT )
   o:Edit( Asc( 'X' ) )
   hb_MemoWrit( '/tmp/hbide-selection-result.txt', o:GetText() )
   Check( 'selection replaced not appended', o:GetText() == 'Xdef' )
   o := PaintProbe():New( 'one two three', 2, 1, 20, 79, .T., 16 )
   o:GoTo( 1, 5 )
   o:Edit( Asc( 'Z' ) )
   Check( 'wordwrap path preserves typed character', Left( o:GetText(), 1 ) == 'Z' )
   hb_MemoWrit( '/tmp/hbide-repaint-tests.txt', 'PASS ' + hb_ntos( nPass ) + ' FAIL ' + hb_ntos( nFail ) )
   if nFail > 0
      ErrorLevel( 1 )
   endif
return

/*
 * mccommandline.prg - MCCommandLine: self-sufficient Midnight Commander
 * style command line for the Harbour Commander demo.
 *
 * Layout (stable, two rows above the F1-F10 key bar; panel frames untouched):
 *   row 0: status  - active panel path + user + timestamp
 *   row 1: prompt  - "$ " + command text with cursor, history recall and
 *                    horizontal scrolling
 *
 * Keyboard: Left/Right, Home, End, Del, Backspace, Ins (insert/overwrite
 * toggle when the line is not empty; when empty Ins stays the panel's
 * mark-file key), Ctrl+Up/Ctrl+Down walk the history, printable chars
 * insert/overwrite at the cursor. Esc clears a non-empty line (handled by
 * MCApp). Text is edited bytewise, like the original: non-ASCII input
 * keeps the demo's pre-existing limitation.
 */

#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"

//-----------------------------------------------------------------------------------------//

CREATE CLASS MCCommandLine

   DATA   oApp                    // MCApp owning this command line
   DATA   cText    INIT ""        // command text being edited
   DATA   nPos     INIT 0         // cursor offset inside cText (0..Len)
   DATA   nScroll  INIT 0         // first visible char offset (0-based)
   DATA   lInsert  INIT .T.       // .T. insert mode, .F. overwrite
   DATA   nHist    INIT 0         // 0: live line; >0: aHistory index being browsed
   DATA   cSaved   INIT ""        // live line stashed while browsing history

   METHOD New( oApp )
   METHOD HandleKey( nKey, lCtrl )
   METHOD Append( cAdd )
   METHOD SetText( cText )
   METHOD Show()
   METHOD HistMove( nDir )
   METHOD Rows() INLINE 2

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( oApp ) CLASS MCCommandLine

   ::oApp := oApp

return Self

//-----------------------------------------------------------------------------------------//

// Returns .T. when the key was consumed by the command line.
METHOD HandleKey( nKey, lCtrl ) CLASS MCCommandLine

   local lEmpty := Empty( ::cText )

   do case
   case nKey == K_LEFT .and. ! lEmpty
      if ::nPos > 0
         ::nPos--
         ::nHist := 0
      endif

   case nKey == K_RIGHT .and. ! lEmpty
      if ::nPos < Len( ::cText )
         ::nPos++
         ::nHist := 0
      endif

   case nKey == K_HOME .and. ! lEmpty
      ::nPos := 0
      ::nHist := 0

   case nKey == K_END .and. ! lEmpty
      ::nPos := Len( ::cText )
      ::nHist := 0

   case nKey == K_DEL .and. ! lEmpty
      if ::nPos < Len( ::cText )
         ::cText := Stuff( ::cText, ::nPos + 1, 1, "" )
      endif
      ::nHist := 0

   case nKey == K_BS
      if ::nPos > 0
         ::cText := Stuff( ::cText, ::nPos, 1, "" )
         ::nPos--
      endif
      ::nHist := 0

   case nKey == K_INS .and. ! lCtrl .and. ! lEmpty
      ::lInsert := ! ::lInsert   // empty line: Ins stays "mark file" in the panel

   case nKey == K_CTRL_UP .and. lCtrl
      ::HistMove( -1 )

   case nKey == K_CTRL_DOWN .and. lCtrl
      ::HistMove( 1 )

   case lEmpty .and. ( nKey == 43 .or. nKey == 45 .or. nKey == 42 )
      return .F.                    // '+', '-', '*': panel quick-select keys

   case nKey >= 32 .and. nKey < 256
      if ::lInsert .or. ::nPos == Len( ::cText )
         ::cText := Stuff( ::cText, ::nPos + 1, 0, Chr( nKey ) )
      else
         ::cText := Stuff( ::cText, ::nPos + 1, 1, Chr( nKey ) )
      endif
      ::nPos++
      ::nHist := 0

   otherwise
      return .F.
   endcase

return .T.

//-----------------------------------------------------------------------------------------//

// nDir: -1 older, +1 newer. Ctrl+Up/Ctrl+Down walk oApp:aHistory.
METHOD HistMove( nDir ) CLASS MCCommandLine

   local aHist := ::oApp:aHistory, n

   if Empty( aHist )
      return nil
   endif
   if ::nHist == 0
      if nDir > 0
         return nil                    // already on the live line
      endif
      ::cSaved := ::cText
      ::nHist := Len( aHist ) + 1     // one past the newest
   endif
   n := ::nHist + nDir
   if n < 1
      n := 1
   endif
   if n > Len( aHist )
      ::nHist := 0                    // back to the live line
      ::cText := ::cSaved
      ::nPos := Len( ::cText )
      return nil
   endif
   ::nHist := n
   ::cText := aHist[ n ]
   ::nPos := Len( ::cText )

return nil

//-----------------------------------------------------------------------------------------//

METHOD Append( cAdd ) CLASS MCCommandLine

   ::cText := Stuff( ::cText, ::nPos + 1, 0, cAdd )
   ::nPos += Len( cAdd )
   ::nHist := 0

return nil

//-----------------------------------------------------------------------------------------//

METHOD SetText( cText ) CLASS MCCommandLine

   ::cText := hb_defaultValue( cText, "" )
   ::nPos := Len( ::cText )
   ::nHist := 0

return nil

//-----------------------------------------------------------------------------------------//

// Draws the two command line rows just above the key bar and leaves the
// cursor on the prompt row. Row 0: path + user + timestamp. Row 1: prompt.
METHOD Show() CLASS MCCommandLine

   local nKeyBar := If( ::oApp:lKeybar, 1, 0 )
   local nRow0 := MaxRow() - nKeyBar - 1
   local nRow1 := MaxRow() - nKeyBar
   local nW := MaxCol() + 1
   local cUser := GetEnv( "USER" )
   local cPath := ::oApp:ActivePanel():cPath
   local cStamp := DToC( Date() ) + " " + Time()
   local cLeft := " " + cPath + "  [" + cUser + "]"
   local cStatus, cPrompt := "$ ", nVis

   if hb_ULen( cLeft ) + hb_ULen( cStamp ) + 1 > nW
      cLeft := hb_UPadR( hb_UTF8SubStr( cLeft, 1, nW - hb_ULen( cStamp ) - 1 ), nW - hb_ULen( cStamp ) - 1 )
   endif
   cStatus := cLeft + Space( nW - hb_ULen( cLeft ) - hb_ULen( cStamp ) ) + cStamp
   hb_DispOutAt( nRow0, 0, hb_UPadR( cStatus, nW ), "N/W" )

   // visible window: keep the cursor inside the prompt row
   nVis := Max( nW - hb_ULen( cPrompt ), 1 )
   if ::nPos < ::nScroll
      ::nScroll := ::nPos
   elseif ::nPos > ::nScroll + nVis - 1
      ::nScroll := ::nPos - nVis + 1
   endif

   hb_DispOutAt( nRow1, 0, cPrompt + hb_UPadR( hb_UTF8SubStr( ::cText, ::nScroll + 1, nVis ), nVis ), "N/W" )
   SetCursor( If( ::lInsert, SC_NORMAL, SC_SPECIAL1 ) )
   SetPos( nRow1, Len( cPrompt ) + ::nPos - ::nScroll )

return nil

//-----------------------------------------------------------------------------------------//

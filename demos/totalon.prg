//
// totalon.prg - FoxPro-style multi-window desktop with the TOTAL ON dialog,
// built with hbide's own GUI pieces (HbMenu pulldowns, its window/button
// paint conventions) in pure Harbour.
//
// Visual reference: the classic screen shot - grey menu bar
// (System File Edit Database Record Program Window), blue desktop, cyan
// ITEMS window, calculator, ASCII chart, puzzle, black Debug (Output)
// window, and the magenta TOTAL ON dialog in front.
//
// All controls are functional: menus, record browse, calculator with
// memory, 15-puzzle, ASCII chart scroll, and the dialog totals real
// records into the Debug (Output) window (optional FOR expression and
// Save As file).
//
// Glyph literals are UTF-8 byte escapes: pure-ASCII source, so CP437
// editors (hbide included) open/edit/save it without loss.
//

#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
#include "hbmenu.ch"
#include "hbclass.ch"

#define SCR_ROWS 27
#define SCR_COLS 80

// glyph literals as UTF-8 byte escapes
#define U_UP      e"\xE2\x96\xB2"   // up-pointing triangle
#define U_DOWN    e"\xE2\x96\xBC"   // down-pointing triangle
#define U_PLUSMN  e"\xC2\xB1"       // plus-minus sign

// ITEMS window geometry
#define IT_TOP     2
#define IT_LEFT    2
#define IT_BOTTOM  23
#define IT_RIGHT   76
// Debug (Output) window
#define DBG_TOP    4
#define DBG_LEFT   63
#define DBG_BOTTOM 22
#define DBG_RIGHT  79
// calculator
#define CAL_TOP    10
#define CAL_LEFT   4
#define CAL_BOTTOM 24
#define CAL_RIGHT  25
// puzzle
#define PZ_TOP     14
#define PZ_LEFT    62
#define PZ_BOTTOM  24
#define PZ_RIGHT   75
// ASCII chart
#define AS_TOP     21
#define AS_LEFT    33
#define AS_BOTTOM  24
#define AS_RIGHT   56
// TOTAL ON dialog
#define DL_TOP     4
#define DL_LEFT    17
#define DL_BOTTOM  20
#define DL_RIGHT   63

static s_h
static s_aFldTypes := { { "ITEM", "C" }, { "QUANTITY", "N" }, ;
   { "DESCRIPT", "C" }, { "COST", "N" }, { "PRICE", "N" }, { "TAXABLE", "L" } }

//------------------------------------------------------------
// TotalWindow: a real hbide HbWindow restyled to the photo's look
// (solid grey band frame for desktop windows, line box for dialogs)
class TotalWindow FROM HbWindow

   DATA cFrameColor INIT "N/W"
   DATA cBodyColor  INIT "N/BG"
   DATA lBoxFrame   INIT .F.
   DATA bContent

   METHOD Show( lFocused )
   METHOD PaintContent()

endclass

METHOD Show( lFocused ) CLASS TotalWindow

   ::lFocused := hb_defaultValue( lFocused, .T. )

   DispBegin()
   if ::lShadow
      WinShadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
   endif
   hb_Scroll( ::nTop, ::nLeft, ::nBottom, ::nRight,,, ::cBodyColor )
   if ::lBoxFrame
      hb_DispBox( ::nTop, ::nLeft, ::nBottom, ::nRight, HB_B_SINGLE_UNI, ::cFrameColor )
   else
      hb_Scroll( ::nTop, ::nLeft, ::nTop, ::nRight,,, ::cFrameColor )
      hb_Scroll( ::nBottom, ::nLeft, ::nBottom, ::nRight,,, ::cFrameColor )
      hb_Scroll( ::nTop, ::nLeft, ::nBottom, ::nLeft,,, ::cFrameColor )
      hb_Scroll( ::nTop, ::nRight, ::nBottom, ::nRight,,, ::cFrameColor )
   endif
   if ! Empty( ::cCaption )
      hb_DispOutAt( ::nTop, ;
         Max( ::nLeft + 1, ::nLeft + Int( ( ::nRight - ::nLeft - hb_ULen( ::cCaption ) ) / 2 ) ), ;
         " " + ::cCaption + " ", iif( ::lFocused, "W+/W", ::cFrameColor ) )
   endif
   ::PaintContent()
   DispEnd()

   ::lVisible := .T.

return nil

METHOD PaintContent() CLASS TotalWindow

   if HB_ISEVALITEM( ::bContent )
      Eval( ::bContent, Self )
   endif

return nil

//------------------------------------------------------------
procedure Main()

   local nOldCursor := SetCursor( SC_NONE )
   local cSave := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local nKey

   hb_cdpSelect( "UTF8" )
   SetMode( SCR_ROWS, SCR_COLS )
   Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_EXT )
   Set( _SET_SCOREBOARD, .F. )
   Set( _SET_MESSAGE, SCR_ROWS - 1 )   // READ messages land on the empty margin row, never over the menu bar
   SetColor( "N/B" )
   CLEAR SCREEN

   s_h := DeskState()
   s_h[ "menu" ] := DeskMenu()
   DeskRepaint()
   DlgRun()   // the reference photo shows the TOTAL ON dialog up

   do while ! s_h[ "quit" ]
      DeskRepaint()
      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      if s_h[ "menu" ]:IsOpen()
         s_h[ "menu" ]:ProcessKey( nKey )
         loop
      endif
      do case
      case nKey == K_ESC
         s_h[ "quit" ] := .T.
      case nKey == K_F10
         s_h[ "menu" ]:ShowPopup( 1 )
      case nKey == K_F9
         DlgRun()
      case nKey == K_F4
         WinCycle()
      case nKey == K_LBUTTONDOWN .and. MRow() == 0
         s_h[ "menu" ]:ProcessKey( nKey )
      case AltMenuKey( nKey ) > 0
         s_h[ "menu" ]:ShowPopup( AltMenuKey( nKey ) )
      case nKey == K_LBUTTONDOWN .or. nKey == K_LDBLCLK
         DeskClick( nKey )
      otherwise
         WinKey( ATail( s_h[ "wins" ] ), nKey )
      endcase
   enddo

   SetColor( "W/N" )
   RestScreen( 0, 0, MaxRow(), MaxCol(), cSave )
   SetCursor( nOldCursor )

return

//------------------------------------------------------------
static function AltMenuKey( nKey )

   do case
   case nKey == K_ALT_S ; return 1
   case nKey == K_ALT_F ; return 2
   case nKey == K_ALT_E ; return 3
   case nKey == K_ALT_D ; return 4
   case nKey == K_ALT_R ; return 5
   case nKey == K_ALT_P ; return 6
   case nKey == K_ALT_W ; return 7
   endcase

return 0

//------------------------------------------------------------
static function DeskState()

   local h := { ;
      "quit"  => .F., ;
      "wins"  => { "debug", "items", "calc", "puzzle", "ascii" }, ;
      "rec"   => 1, ;
      "recs"  => {}, ;
      "calc"  => CalcState(), ;
      "ckey"  => 1, ;
      "mem"   => 0, ;
      "puz"   => {}, ;
      "ascii" => 6, ;
      "out"   => {}, ;
      "winobj" => { => } }

   local oW

   // seed records; first one matches the reference photo
   AAdd( h[ "recs" ], RecNew( "10001D", 0, "Wood table", 1, 4, .T. ) )
   AAdd( h[ "recs" ], RecNew( "10002A", 5, "Steel lamp", 3, 9, .T. ) )
   AAdd( h[ "recs" ], RecNew( "10003C", 1, "Oak desk", 8, 15, .F. ) )
   AAdd( h[ "recs" ], RecNew( "10004B", 4, "Pine shelf", 2, 7, .T. ) )
   AAdd( h[ "recs" ], RecNew( "10005E", 3, "Walnut bed", 6, 11, .T. ) )

   // puzzle, same deal as the photo (16 = blank)
   h[ "puz" ] := { 4, 13, 11, 6, 10, 2, 8, 9, 12, 5, 15, 16, 7, 14, 3, 1 }

   OutLine( h, "Debug (Output) ready." )
   OutLine( h, "Database > Total On... (F9) totals ITEMS here." )

   h[ "winobj" ][ "items" ]  := TotalWindow():New( IT_TOP, IT_LEFT, IT_BOTTOM, IT_RIGHT, "ITEMS", "W+/BG" )
   h[ "winobj" ][ "calc" ]   := TotalWindow():New( CAL_TOP, CAL_LEFT, CAL_BOTTOM, CAL_RIGHT, "Calculator", "N/BG" )
   h[ "winobj" ][ "puzzle" ] := TotalWindow():New( PZ_TOP, PZ_LEFT, PZ_BOTTOM, PZ_RIGHT, "Puzzle", "N/BG" )
   h[ "winobj" ][ "ascii" ]  := TotalWindow():New( AS_TOP, AS_LEFT, AS_BOTTOM, AS_RIGHT, "", "N/BG" )
   h[ "winobj" ][ "debug" ]  := TotalWindow():New( DBG_TOP, DBG_LEFT, DBG_BOTTOM, DBG_RIGHT, "Debug (Output)", "W/N" )
   for each oW in h[ "winobj" ]
      oW:lShadow := .T.
      oW:cColor := oW:cBodyColor
   next
   h[ "winobj" ][ "items"  ]:bContent := {|| ItemsPaint() }
   h[ "winobj" ][ "calc"   ]:bContent := {|| CalcPaint() }
   h[ "winobj" ][ "puzzle" ]:bContent := {|| PuzzlePaint() }
   h[ "winobj" ][ "ascii"  ]:bContent := {|| AsciiPaint() }
   h[ "winobj" ][ "debug"  ]:bContent := {|| DebugPaint() }

return h

static function RecNew( cItem, nQty, cDesc, nCost, nPrice, lTax )

return { "ITEM" => cItem, "QUANTITY" => nQty, "DESCRIPT" => cDesc, ;
   "COST" => nCost, "PRICE" => nPrice, "TAXABLE" => lTax }

//------------------------------------------------------------
static procedure OutLine( h, cText )

   AAdd( h[ "out" ], cText )
   if Len( h[ "out" ] ) > 200
      ADel( h[ "out" ], 1 )
      ASize( h[ "out" ], 200 )
   endif

return

//------------------------------------------------------------
// drop shadow: dark cells flush right and below a window
static procedure WinShadow( nT, nL, nB, nR )

   hb_Scroll( nT + 1, nR + 1, nB + 1, nR + 2,,, "N/N" )
   hb_Scroll( nB + 1, nL + 2, nB + 1, nR + 2,,, "N/N" )

return

// grey frame + colored body + centered title on the top frame row
static procedure WinFrame( nT, nL, nB, nR, cTitle, cBody, lFocus )

   hb_Scroll( nT, nL, nB, nR,,, cBody )
   hb_Scroll( nT, nL, nT, nR,,, "N/W" )
   hb_Scroll( nB, nL, nB, nR,,, "N/W" )
   hb_Scroll( nT, nL, nB, nL,,, "N/W" )
   hb_Scroll( nT, nR, nB, nR,,, "N/W" )
   if cTitle != nil
      hb_DispOutAt( nT, Max( nL + 1, nL + Int( ( nR - nL - hb_ULen( cTitle ) ) / 2 ) ), ;
         " " + cTitle + " ", iif( lFocus, "W+/W", "N/W" ) )
   endif

return

//------------------------------------------------------------
static procedure DeskRepaint()

   local cId

   DispBegin()
   hb_Scroll( 0, 0, SCR_ROWS - 1, SCR_COLS - 1,,, "N/B" )
   for each cId in s_h[ "wins" ]
      s_h[ "winobj" ][ cId ]:Show( cId == ATail( s_h[ "wins" ] ) )
   next
   if s_h[ "menu" ] != nil
      hb_Scroll( 0, 0, 0, SCR_COLS - 1,,, "N/W" )   // solid bar: no desktop gaps between items
      s_h[ "menu" ]:Display()
   endif
   DispEnd()

return

//------------------------------------------------------------
// ITEMS: the big grey-framed, cyan-bodied record window
static procedure ItemsPaint()

   local h := s_h, r := h[ "recs" ][ h[ "rec" ] ]

   hb_DispOutAt( IT_TOP + 2, 6,  "Item", "W+/BG" )
   hb_DispOutAt( IT_TOP + 2, 13, r[ "ITEM" ], "W+/BG" )
   hb_DispOutAt( IT_TOP + 3, 6,  "Quantity", "W+/BG" )
   if r[ "QUANTITY" ] > 0
      hb_DispOutAt( IT_TOP + 3, 17, hb_ntos( r[ "QUANTITY" ] ), "W+/BG" )
   endif
   hb_DispOutAt( IT_TOP + 4, 6,  "Descript", "W+/BG" )
   hb_DispOutAt( IT_TOP + 4, 14, r[ "DESCRIPT" ], "W+/BG" )
   hb_DispOutAt( IT_TOP + 5, 6,  "Cost", "W+/BG" )
   hb_DispOutAt( IT_TOP + 5, 17, hb_ntos( r[ "COST" ] ), "W+/BG" )
   hb_DispOutAt( IT_TOP + 6, 6,  "Price", "W+/BG" )
   hb_DispOutAt( IT_TOP + 6, 17, hb_ntos( r[ "PRICE" ] ), "W+/BG" )
   hb_DispOutAt( IT_TOP + 7, 6,  "Taxable", "W+/BG" )
   hb_DispOutAt( IT_TOP + 7, 17, iif( r[ "TAXABLE" ], "T", "F" ), "W+/BG" )

   // record counter at the bottom of the cyan body
   hb_DispOutAt( IT_BOTTOM - 1, IT_LEFT + 2, "Record " + hb_ntos( h[ "rec" ] ) + ;
      "/" + hb_ntos( Len( h[ "recs" ] ) ) + "  (Up/Dn)", "W/BG" )

return

static procedure ItemsKey( nKey )

   local h := s_h

   do case
   case nKey == K_UP .or. nKey == K_PGUP
      h[ "rec" ] := Max( 1, h[ "rec" ] - 1 )
   case nKey == K_DOWN .or. nKey == K_PGDN
      h[ "rec" ] := Min( Len( h[ "recs" ] ), h[ "rec" ] + 1 )
   case nKey == K_HOME
      h[ "rec" ] := 1
   case nKey == K_END
      h[ "rec" ] := Len( h[ "recs" ] )
   case nKey == K_INS
      AAdd( h[ "recs" ], RecNew( "NEW" + hb_ntos( 100 + Len( h[ "recs" ] ) ), ;
         1, "New item", 0, 0, .F. ) )
      h[ "rec" ] := Len( h[ "recs" ] )
   endcase

return

//------------------------------------------------------------
// Debug (Output): black window; content visible when brought to front
static procedure DebugPaint()

   local h := s_h, i, n
   local aVis := {}
   n := DBG_BOTTOM - DBG_TOP - 1
   for i := Max( 1, Len( h[ "out" ] ) - n + 1 ) to Len( h[ "out" ] )
      AAdd( aVis, h[ "out" ][ i ] )
   next
   for i := 1 to Len( aVis )
      hb_DispOutAt( DBG_TOP + i, DBG_LEFT + 1, ;
         PadR( Left( aVis[ i ], DBG_RIGHT - DBG_LEFT - 1 ), DBG_RIGHT - DBG_LEFT - 1 ), "W/N" )
   next

return

//------------------------------------------------------------
// calculator: cyan body, white display, memory keys; classic layout
static function CalcState()

return { "display" => "0", "acc" => 0, "op" => "", "entering" => .T., "error" => .F. }

// key grid: { col, row, caption }
static function CalcKeys()

return { ;
   { 6, 16, "MC" }, { 10, 16, "7" }, { 14, 16, "8" }, { 18, 16, "9" }, { 22, 16, "/" }, ;
   { 6, 18, "MR" }, { 10, 18, "4" }, { 14, 18, "5" }, { 18, 18, "6" }, { 22, 18, "*" }, ;
   { 6, 20, "M+" }, { 10, 20, "1" }, { 14, 20, "2" }, { 18, 20, "3" }, { 22, 20, "-" }, ;
   { 6, 22, "M-" }, { 10, 22, "0" }, { 14, 22, "." }, { 17, 22, U_PLUSMN }, ;
   { 20, 22, "+" }, { 23, 22, "=" } }

static procedure CalcPaint()

   local h := s_h, aK, nFoc := h[ "ckey" ]
   local lF := ATail( h[ "wins" ] ) == "calc"

   // display: inset white box
   hb_Scroll( CAL_TOP + 2, CAL_LEFT + 3, CAL_TOP + 4, CAL_RIGHT - 4,,, "N/W" )
   hb_DispBox( CAL_TOP + 2, CAL_LEFT + 3, CAL_TOP + 4, CAL_RIGHT - 4, HB_B_SINGLE_UNI, "N/W" )
   hb_DispOutAt( CAL_TOP + 3, CAL_LEFT + 4, ;
      PadL( Left( h[ "calc" ][ "display" ], CAL_RIGHT - CAL_LEFT - 9 ), CAL_RIGHT - CAL_LEFT - 9 ), "N/W" )

   // keys
   for each aK in CalcKeys()
      hb_DispOutAt( aK[ 2 ], aK[ 1 ], aK[ 3 ], ;
         iif( lF .and. aK:__enumIndex == nFoc, "W+/B", "B/BG" ) )
   next

return

static procedure CalcKey( nKey )

   local h := s_h, aK := CalcKeys(), nR, nC, nBest, nD, i, cK

   do case
   case nKey == K_LEFT .or. nKey == K_RIGHT
      // move within the same visual row
      nR := aK[ h[ "ckey" ] ][ 2 ]
      i := h[ "ckey" ] + iif( nKey == K_LEFT, -1, 1 )
      if i >= 1 .and. i <= Len( aK ) .and. aK[ i ][ 2 ] == nR
         h[ "ckey" ] := i
      endif
   case nKey == K_UP .or. nKey == K_DOWN
      // nearest key by column one visual row over
      nR := aK[ h[ "ckey" ] ][ 2 ] + iif( nKey == K_UP, -2, 2 )
      nC := aK[ h[ "ckey" ] ][ 1 ]
      nBest := 0
      nD := 99
      for i := 1 to Len( aK )
         if aK[ i ][ 2 ] == nR .and. Abs( aK[ i ][ 1 ] - nC ) < nD
            nD := Abs( aK[ i ][ 1 ] - nC )
            nBest := i
         endif
      next
      if nBest > 0
         h[ "ckey" ] := nBest
      endif
   case nKey == K_ENTER .or. nKey == K_SPACE
      CalcPress( aK[ h[ "ckey" ] ][ 3 ] )
   case nKey == K_BS
      CalcBack()
   case nKey >= 32 .and. nKey <= 126
      cK := Upper( Chr( nKey ) )
      if cK == "C"
         h[ "calc" ] := CalcState()
      else
         i := AScan( aK, {| a | a[ 3 ] == cK } )
         if i > 0
            h[ "ckey" ] := i
            CalcPress( cK )
         endif
      endif
   endcase

return

static procedure CalcBack()

   local c := s_h[ "calc" ]

   if c[ "error" ]
      s_h[ "calc" ] := CalcState()
   elseif c[ "entering" ] .and. Len( c[ "display" ] ) > 1
      c[ "display" ] := Left( c[ "display" ], Len( c[ "display" ] ) - 1 )
   else
      c[ "display" ] := "0"
   endif

return

static function CalcFmt( n )

   local c

   if Abs( n ) >= 999999999999
      return "ERR"
   endif
   c := AllTrim( Str( n, 14, 6 ) )
   do while Right( c, 1 ) == "0" .and. "." $ c
      c := Left( c, Len( c ) - 1 )
   enddo
   if Right( c, 1 ) == "."
      c := Left( c, Len( c ) - 1 )
   endif

return iif( Empty( c ) .or. c == "-0", "0", c )

static procedure CalcApply()

   local c := s_h[ "calc" ]
   local n := Val( c[ "display" ] )

   do case
   case c[ "op" ] == ""  ; c[ "acc" ] := n
   case c[ "op" ] == "+" ; c[ "acc" ] += n
   case c[ "op" ] == "-" ; c[ "acc" ] -= n
   case c[ "op" ] == "*" ; c[ "acc" ] *= n
   case c[ "op" ] == "/"
      if n == 0
         c[ "error" ] := .T.
         c[ "display" ] := "ERR"
         return
      endif
      c[ "acc" ] /= n
   endcase
   c[ "display" ] := CalcFmt( c[ "acc" ] )

return

// immediate-execution four-function calculator + memory keys
static procedure CalcPress( cB )

   local h := s_h, c := h[ "calc" ]

   do case
   case cB == "MC"
      h[ "mem" ] := 0
   case cB == "MR"
      c[ "display" ] := CalcFmt( h[ "mem" ] )
      c[ "entering" ] := .F.
      c[ "error" ] := .F.
   case cB == "M+"
      h[ "mem" ] += Val( c[ "display" ] )
      c[ "entering" ] := .F.
   case cB == "M-"
      h[ "mem" ] -= Val( c[ "display" ] )
      c[ "entering" ] := .F.
   case cB == U_PLUSMN
      c[ "display" ] := CalcFmt( -Val( c[ "display" ] ) )
   case cB $ "0123456789"
      if c[ "error" ] .or. ! c[ "entering" ]
         c[ "display" ] := cB
         c[ "error" ] := .F.
      elseif c[ "display" ] == "0"
         c[ "display" ] := cB
      elseif Len( c[ "display" ] ) < 12
         c[ "display" ] += cB
      endif
      c[ "entering" ] := .T.
   case cB == "."
      if c[ "error" ] .or. ! c[ "entering" ]
         c[ "display" ] := "0."
         c[ "error" ] := .F.
      elseif ! "." $ c[ "display" ]
         c[ "display" ] += "."
      endif
      c[ "entering" ] := .T.
   case cB $ "+-*/"
      if ! c[ "error" ]
         CalcApply()
         c[ "op" ] := cB
         c[ "entering" ] := .F.
      endif
   case cB == "="
      if ! c[ "error" ]
         CalcApply()
         c[ "op" ] := ""
         c[ "entering" ] := .F.
      endif
   endcase

return

//------------------------------------------------------------
// 15-puzzle
static procedure PuzzlePaint()

   local h := s_h, n, nR, nC, v
   local lF := ATail( h[ "wins" ] ) == "puzzle"

   for n := 0 to 15
      v := h[ "puz" ][ n + 1 ]
      nR := 16 + Int( n / 4 ) * 2
      nC := 63 + ( n % 4 ) * 3
      if v != 16
         hb_DispOutAt( nR, nC + 2 - Len( hb_ntos( v ) ), hb_ntos( v ), "B/BG" )
      endif
   next

   hb_DispOutAt( PZ_BOTTOM - 1, PZ_LEFT + 1, "< Shuffle >", iif( lF, "W+/BG", "B/BG" ) )

return

static function PuzzleBlank()

return AScan( s_h[ "puz" ], 16 )

static procedure PuzzleSlide( nPos )

   local h := s_h, nB := PuzzleBlank()

   // swap blank with the tile at nPos if adjacent
   if nPos >= 1 .and. nPos <= 16
      if ( Int( ( nB - 1 ) / 4 ) == Int( ( nPos - 1 ) / 4 ) .and. Abs( nB - nPos ) == 1 ) ;
         .or. Abs( nB - nPos ) == 4
         h[ "puz" ][ nB ] := h[ "puz" ][ nPos ]
         h[ "puz" ][ nPos ] := 16
         if PuzzleSolved()
            OutLine( h, "Puzzle solved!" )
            MsgBox( "Puzzle", { "Puzzle solved!" } )
         endif
      endif
   endif

return

static function PuzzleSolved()

   local h := s_h, i

   for i := 1 to 15
      if h[ "puz" ][ i ] != i
         return .F.
      endif
   next

return .T.

static procedure PuzzleKey( nKey )

   local nB := PuzzleBlank(), nT := 0

   // arrow = slide the adjacent tile into the blank
   do case
   case nKey == K_LEFT  ; nT := nB + 1
   case nKey == K_RIGHT ; nT := nB - 1
   case nKey == K_UP    ; nT := nB + 4
   case nKey == K_DOWN  ; nT := nB - 4
   case nKey == K_ENTER .or. nKey == K_SPACE .or. ;
      ( nKey >= 32 .and. nKey <= 126 .and. Upper( Chr( nKey ) ) == "S" )
      PuzzleShuffle()
      return
   endcase
   PuzzleSlide( nT )

return

static procedure PuzzleShuffle()

   local h := s_h, i, nB, aM, nP

   for i := 1 to 300
      nB := PuzzleBlank()
      aM := {}
      if ( nB % 4 ) != 0
         AAdd( aM, nB + 1 )
      endif
      if ( nB - 1 ) % 4 != 0 .or. nB == 1
         AAdd( aM, nB - 1 )
      endif
      if nB + 4 <= 16
         AAdd( aM, nB + 4 )
      endif
      if nB - 4 >= 1
         AAdd( aM, nB - 4 )
      endif
      nP := aM[ 1 + hb_randomInt( 0, Len( aM ) - 1 ) ]
      h[ "puz" ][ nB ] := h[ "puz" ][ nP ]
      h[ "puz" ][ nP ] := 16
   next

return

//------------------------------------------------------------
// ASCII chart: two visible rows, dec hex glyph caret name, scroll arrows
static function Cp437Glyph( n )

   if n >= 33 .and. n <= 126
      return Chr( n )
   endif

return hb_StrToUTF8( iif( n == 32, Chr( 255 ), Chr( n ) ), "EN" )

static function AsciiName( n )

   local a := { "NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL", ;
      "BS", "HT", "LF", "VT", "FF", "CR", "SO", "SI", "DLE", "DC1", "DC2", ;
      "DC3", "DC4", "NAK", "SYN", "ETB", "CAN", "EM", "SUB", "ESC", "FS", ;
      "GS", "RS", "US", "SP" }

   if n >= 0 .and. n <= 32
      return a[ n + 1 ]
   elseif n == 127
      return "DEL"
   endif

return ""

static function AsciiCaret( n )

   if n < 32
      return "^" + Chr( 64 + n )
   elseif n == 127
      return "^?"
   endif

return ""

// 2-digit lowercase hex, like the reference ("06", "07")
static function DecToHex( n )

   local c := "", d

   if n == 0
      return "00"
   endif
   do while n > 0
      d := n % 16
      c := SubStr( "0123456789abcdef", d + 1, 1 ) + c
      n := Int( n / 16 )
   enddo

return PadL( c, 2, "0" )

static procedure AsciiPaint()

   local h := s_h, i, n

   for i := 0 to 1
      n := h[ "ascii" ] + i
      if n <= 255
         hb_DispOutAt( AS_TOP + 1 + i, AS_LEFT + 2, ;
            PadL( hb_ntos( n ), 3 ) + " " + DecToHex( n ) + "  " + ;
            iif( n == 32, " ", Cp437Glyph( n ) ) + "  " + ;
            PadR( AsciiCaret( n ), 3 ) + " " + AsciiName( n ), "B/BG" )
      endif
   next
   hb_DispOutAt( AS_TOP + 1, AS_RIGHT - 1, U_UP, iif( h[ "ascii" ] > 0, "B/BG", "GR+/BG" ) )
   hb_DispOutAt( AS_TOP + 2, AS_RIGHT - 1, U_DOWN, iif( h[ "ascii" ] < 254, "B/BG", "GR+/BG" ) )

return

static procedure AsciiKey( nKey )

   local h := s_h

   do case
   case nKey == K_UP    ; h[ "ascii" ] := Max( 0, h[ "ascii" ] - 1 )
   case nKey == K_DOWN  ; h[ "ascii" ] := Min( 254, h[ "ascii" ] + 1 )
   case nKey == K_PGUP  ; h[ "ascii" ] := Max( 0, h[ "ascii" ] - 10 )
   case nKey == K_PGDN  ; h[ "ascii" ] := Min( 254, h[ "ascii" ] + 10 )
   case nKey == K_HOME  ; h[ "ascii" ] := 0
   case nKey == K_END   ; h[ "ascii" ] := 254
   endcase

return

//------------------------------------------------------------
static procedure WinKey( cId, nKey )

   do case
   case cId == "items"   ; ItemsKey( nKey )
   case cId == "calc"    ; CalcKey( nKey )
   case cId == "puzzle"  ; PuzzleKey( nKey )
   case cId == "ascii"   ; AsciiKey( nKey )
   endcase

return

static procedure WinCycle()

   local h := s_h

   AAdd( h[ "wins" ], h[ "wins" ][ 1 ] )
   ADel( h[ "wins" ], 1 )
   ASize( h[ "wins" ], Len( h[ "wins" ] ) - 1 )

return

static procedure WinFront( cId )

   local h := s_h, n := AScan( h[ "wins" ], cId )

   if n > 0 .and. n < Len( h[ "wins" ] )
      ADel( h[ "wins" ], n )
      ASize( h[ "wins" ], Len( h[ "wins" ] ) - 1 )
      AAdd( h[ "wins" ], cId )
   endif

return

static function WinAt( nR, nC )

   // front to back
   local a := { ;
      { "ascii",   AS_TOP,  AS_LEFT,  AS_BOTTOM,  AS_RIGHT }, ;
      { "puzzle",  PZ_TOP,  PZ_LEFT,  PZ_BOTTOM,  PZ_RIGHT }, ;
      { "calc",    CAL_TOP, CAL_LEFT, CAL_BOTTOM, CAL_RIGHT }, ;
      { "items",   IT_TOP,  IT_LEFT,  IT_BOTTOM,  IT_RIGHT }, ;
      { "debug",   DBG_TOP, DBG_LEFT, DBG_BOTTOM, DBG_RIGHT } }
   local aW

   for each aW in a
      if nR >= aW[ 2 ] .and. nR <= aW[ 4 ] .and. nC >= aW[ 3 ] .and. nC <= aW[ 5 ]
         return aW[ 1 ]
      endif
   next

return ""

//------------------------------------------------------------
static procedure DeskClick( nKey )

   local h := s_h, nR := MRow(), nC := MCol(), cW, aK, n

   cW := WinAt( nR, nC )
   if Empty( cW )
      return
   endif
   WinFront( cW )
   do case
   case cW == "calc"
      for each aK in CalcKeys()
         if nR == aK[ 2 ] .and. nC >= aK[ 1 ] .and. nC <= aK[ 1 ] + hb_ULen( aK[ 3 ] ) + 1
            h[ "ckey" ] := aK:__enumIndex
            CalcPress( aK[ 3 ] )
            return
         endif
      next
      // click on the display clears
      if nR >= CAL_TOP + 2 .and. nR <= CAL_TOP + 4 .and. ;
         nC >= CAL_LEFT + 3 .and. nC <= CAL_RIGHT - 4
         h[ "calc" ] := CalcState()
      endif
   case cW == "puzzle"
      if nR == PZ_BOTTOM - 1 .and. nC >= PZ_LEFT + 1 .and. nC <= PZ_LEFT + 12
         PuzzleShuffle()
      elseif nR >= 16 .and. nR <= 22 .and. ( nR - 16 ) % 2 == 0 .and. ;
         nC >= 63 .and. nC <= 74
         n := Int( ( nR - 16 ) / 2 ) * 4 + Int( ( nC - 63 ) / 3 ) + 1
         PuzzleSlide( n )
      endif
   case cW == "ascii"
      if nC == AS_RIGHT - 1 .and. nR == AS_TOP + 1
         h[ "ascii" ] := Max( 0, h[ "ascii" ] - 1 )
      elseif nC == AS_RIGHT - 1 .and. nR == AS_TOP + 2
         h[ "ascii" ] := Min( 254, h[ "ascii" ] + 1 )
      endif
   case cW == "items"
      if nKey == K_LDBLCLK
         ItemsKey( K_DOWN )
      endif
   endcase

return

//------------------------------------------------------------
// centred message box as a real HbWindow dialog with an OK pushbutton
static procedure MsgBox( cTitle, aLines )

   local nW := 12, i, nT, nL, nB, nR, nMask, cOldSh
   local lDummy := .F., GetList := {}, oDlg

   for each i in aLines
      nW := Max( nW, hb_ULen( i ) + 6 )
   next
   nW := Max( nW, hb_ULen( cTitle ) + 8 )
   nB := Len( aLines ) + 4
   nT := Int( ( SCR_ROWS - nB ) / 2 )
   nL := Int( ( SCR_COLS - nW ) / 2 )
   nR := nL + nW - 1
   nB += nT - 1

   oDlg := TotalWindow():New( nT, nL, nB, nR, cTitle, "N/W" )
   oDlg:cColor := "N/W"
   oDlg:lShadow := .T.
   oDlg:bRepaint := {|| DeskRepaint() }
   oDlg:bContent := {|| MsgLines( aLines, nT, nL ) }
   oDlg:Show()

   cOldSh := HBBtnShadowColor( "N/W" )
   @ nB - 1, nL + Max( 1, Int( ( nW - 8 ) / 2 ) ) GET lDummy PUSHBUTTON ;
      CAPTION "  OK  " COLOR "N/W,W+/W,N/W,R/W" STATE {|| oDlg:End() }

   // core READ uses classic Inkey(0): drop HB_INKEY_EXT from the event mask
   // during the READ (otherwise Escape arrives as EXKEY_ESC and does not exit)
   nMask := Set( _SET_EVENTMASK, hb_bitAnd( Set( _SET_EVENTMASK ), hb_bitNot( HB_INKEY_EXT ) ) )
   oDlg:Activate( GetList )
   Set( _SET_EVENTMASK, nMask )
   HBBtnShadowColor( cOldSh )
   DeskRepaint()

return

static procedure MsgLines( aLines, nT, nL )

   local i

   for i := 1 to Len( aLines )
      hb_DispOutAt( nT + i, nL + 3, aLines[ i ], "N/W" )
   next

return

//------------------------------------------------------------
// TOTAL ON dialog: decorative labels + white panels (photo layout)
static procedure DlgDeco()

   hb_DispOutAt( DL_TOP + 1, DL_LEFT + 3, "TOTAL ON:", "W+/RB" )
   // white panel around the checkbox group
   hb_DispBox( DL_TOP + 2, DL_LEFT + 25, DL_TOP + 10, DL_LEFT + 39, HB_B_SINGLE_UNI, "W/RB" )
   hb_DispOutAt( DL_TOP + 11, DL_LEFT + 3, "<Expr... >", "W/RB" )
   // white panel around Save As (button + entry)
   hb_DispBox( DL_TOP + 12, DL_LEFT + 2, DL_TOP + 15, DL_LEFT + 30, HB_B_SINGLE_UNI, "W/RB" )
   hb_DispOutAt( DL_TOP + 13, DL_LEFT + 3, "<Save As...>", "W/RB" )

return

// modal TOTAL ON dialog: real HbWindow + hbide GET controls
// (LISTBOX, CHECKBOX, plain GETs, PUSHBUTTONs), like hbide's own dialogs
static procedure DlgRun()

   local oDlg, GetList := {}, nMask, cOldSh, aF
   local nField := 1, lScope := .F., lFor := .F., lWhile := .F., lFields := .F.
   local cExpr := Space( 17 ), cSaveAs := Space( 27 )
   // button GET vars are written back on deactivation: keep them separate
   // from the lOk flag or varPut() clobbers the STATE assignment
   local lOk := .F., lBtnOk := .F., lBtnCancel := .F.
   local aIt := {}

   for each aF in s_aFldTypes
      AAdd( aIt, PadR( aF[ 1 ], 10 ) + aF[ 2 ] )
   next

   oDlg := TotalWindow():New( DL_TOP, DL_LEFT, DL_BOTTOM, DL_RIGHT, "", "W/RB" )
   oDlg:cFrameColor := "W/RB"
   oDlg:cBodyColor  := "W/RB"
   oDlg:cColor      := "W/RB"
   oDlg:lBoxFrame   := .T.
   oDlg:lShadow     := .T.
   oDlg:bRepaint    := {|| DeskRepaint() }
   oDlg:bContent    := {|| DlgDeco() }
   oDlg:Show()

   cOldSh := HBBtnShadowColor( "N/RB" )   // flat buttons over the magenta body

   @ DL_TOP + 3, DL_LEFT + 3, DL_TOP + 10, DL_LEFT + 19 GET nField ;
      LISTBOX aIt COLOR "W+/BG,W+/B,W+/BG,W+/B,W+/BG,W+/BG,W+/BG"
   @ DL_TOP + 3, DL_LEFT + 26 GET lScope  CHECKBOX CAPTION "Scope..."  STYLE "[x ]" COLOR "W/RB,W+/RB,W/RB,W+/RB"
   @ DL_TOP + 5, DL_LEFT + 26 GET lFor    CHECKBOX CAPTION "For..."    STYLE "[x ]" COLOR "W/RB,W+/RB,W/RB,W+/RB"
   @ DL_TOP + 7, DL_LEFT + 26 GET lWhile  CHECKBOX CAPTION "While..."  STYLE "[x ]" COLOR "W/RB,W+/RB,W/RB,W+/RB"
   @ DL_TOP + 9, DL_LEFT + 26 GET lFields CHECKBOX CAPTION "Fields..." STYLE "[x ]" COLOR "W/RB,W+/RB,W/RB,W+/RB"
   @ DL_TOP + 11, DL_LEFT + 13 GET cExpr   PICTURE "@S17" COLOR "N/BG,N/BG,W/BG,W/BG"
   @ DL_TOP + 14, DL_LEFT + 3  GET cSaveAs PICTURE "@S27" COLOR "N/BG,N/BG,W/BG,W/BG"
   @ DL_TOP + 12, DL_LEFT + 31 GET lBtnOk     PUSHBUTTON CAPTION "<<  OK  >>" ;
      COLOR "W/RB,W+/RB,N/RB,GR+/RB" STYLE "  " STATE {|| lOk := .T., oDlg:End() }
   @ DL_TOP + 14, DL_LEFT + 31 GET lBtnCancel PUSHBUTTON CAPTION "< Cancel >" ;
      COLOR "W/RB,W+/RB,N/RB,GR+/RB" STYLE "  " STATE {|| oDlg:End() }

   // core READ uses classic Inkey(0): drop HB_INKEY_EXT from the event mask
   // during the READ (otherwise Escape arrives as EXKEY_ESC and does not exit)
   nMask := Set( _SET_EVENTMASK, hb_bitAnd( Set( _SET_EVENTMASK ), hb_bitNot( HB_INKEY_EXT ) ) )
   oDlg:Activate( GetList )
   Set( _SET_EVENTMASK, nMask )
   HBBtnShadowColor( cOldSh )

   if lOk
      DlgOk( nField, lScope, lFor, lWhile, lFields, ;
         AllTrim( cExpr ), AllTrim( cSaveAs ) )
   endif
   DeskRepaint()

return

//------------------------------------------------------------
// evaluate a FOR expression against one record (fields as memvars)
// returns .T./.F.; NIL on expression error (cDesc gets the description)
static function RecEval( r, cExpr, cDesc )

   local u, oErr
   private ITEM := r[ "ITEM" ], QUANTITY := r[ "QUANTITY" ], ;
      DESCRIPT := r[ "DESCRIPT" ], COST := r[ "COST" ], ;
      PRICE := r[ "PRICE" ], TAXABLE := r[ "TAXABLE" ]

   cDesc := ""
   BEGIN SEQUENCE WITH {| o | oErr := o, Break( o ) }
      u := &( cExpr )
   RECOVER
      if oErr != NIL
         cDesc := oErr:description
      endif
      return NIL
   END SEQUENCE

return HB_ISLOGICAL( u ) .and. u

//------------------------------------------------------------
static procedure DlgOk( nField, lScope, lFor, lWhile, lFields, cExpr, cSaveAs )

   local h := s_h
   local aNums := {}, aLines := {}, cFld, i, nCnt := 0, nFrom := 1
   local aTotals := { => }, r, lUse, cTxt := "", uEv
   local lForErr := .F., cForDesc := ""

   if lScope
      nFrom := h[ "rec" ]      // REST from the current record
   endif
   if lFields
      for i := 1 to Len( s_aFldTypes )
         if s_aFldTypes[ i ][ 2 ] == "N"
            AAdd( aNums, s_aFldTypes[ i ][ 1 ] )
         endif
      next
   else
      if s_aFldTypes[ nField ][ 2 ] != "N"
         OutLine( h, "TOTAL ON " + s_aFldTypes[ nField ][ 1 ] + ;
            ": not a numeric field, nothing to total." )
         WinFront( "debug" )
         return
      endif
      AAdd( aNums, s_aFldTypes[ nField ][ 1 ] )
   endif
   for each cFld in aNums
      aTotals[ cFld ] := 0
   next
   for i := nFrom to Len( h[ "recs" ] )
      r := h[ "recs" ][ i ]
      lUse := .T.
      if lFor .and. ! Empty( cExpr )
         uEv := RecEval( r, cExpr, @cForDesc )
         if uEv == NIL
            lForErr := .T.
            exit
         endif
         lUse := uEv
      endif
      if lUse
         nCnt++
         for each cFld in aNums
            aTotals[ cFld ] += r[ cFld ]
         next
      endif
   next

   if lForErr
      // never write silent partial totals: report the error and cancel
      OutLine( h, "FOR expression error on record " + hb_ntos( i ) + ": " + cForDesc )
      OutLine( h, "Total cancelled; no partial totals written." )
      WinFront( "debug" )
      return
   endif

   AAdd( aLines, "TOTAL ON " + iif( lScope, "REST", "ALL" ) + ;
      iif( lFor .and. ! Empty( cExpr ), " FOR " + cExpr, "" ) + ;
      iif( lWhile, " WHILE (demo: same as FOR)", "" ) + ":" )
   for each cFld in aNums
      AAdd( aLines, "  " + PadR( cFld, 9 ) + " = " + CalcFmt( aTotals[ cFld ] ) )
   next
   AAdd( aLines, "  " + hb_ntos( nCnt ) + " record(s) counted" )

   for i := 1 to Len( aLines )
      OutLine( h, aLines[ i ] )
      cTxt += aLines[ i ] + hb_eol()
   next
   if ! Empty( cSaveAs )
      if hb_FileExists( cSaveAs )
         OutLine( h, "Save As: '" + cSaveAs + "' already exists; NOT overwritten." )
      elseif hb_MemoWrit( cSaveAs, cTxt )
         OutLine( h, "Saved to " + cSaveAs )
      else
         OutLine( h, "Could not save to " + cSaveAs )
      endif
   endif

   WinFront( "debug" )

return

//------------------------------------------------------------
// menu bar: System File Edit Database Record Program Window
static function DeskMenu()

   local oMenu

   MENU oMenu
      MENUITEM " ~System "
      MENU
         MENUITEM "~About..."   ACTION MsgBox( "About", { ;
            "Multi-window desktop + TOTAL ON dialog", "", ;
            "Built with hbide's own GUI (pure Harbour):", ;
            "HbMenu pulldowns, window paint conventions.", ;
            "Sample ITEMS data; no real database." } )
         MENUITEM "~Help"       ACTION MsgBox( "Help", { ;
            "F10/Alt+letter - menus, mouse works too", ;
            "F4 - cycle windows, F9 - TOTAL ON dialog", ;
            "Items: Up/Dn browse, Ins append", ;
            "Calculator: arrows + Enter or type the key", ;
            "Puzzle: arrows slide, S shuffle", ;
            "ASCII chart: Up/Dn/PgUp/PgDn scroll", ;
            "Esc - close dialog / quit" } )
      ENDMENU
      MENUITEM " ~File "
      MENU
         MENUITEM "E~xit      Esc"  ACTION s_h[ "quit" ] := .T.
      ENDMENU
      MENUITEM " ~Edit "
      MENU
         MENUITEM "~Clear output"   ACTION s_h[ "out" ] := {}
      ENDMENU
      MENUITEM " ~Database "
      MENU
         MENUITEM "~Total On...  F9"  ACTION DlgRun()
         MENUITEM "~Items window"     ACTION WinFront( "items" )
      ENDMENU
      MENUITEM " ~Record "
      MENU
         MENUITEM "~Append     Ins"   ACTION ItemsKey( K_INS )
         MENUITEM "~Next       PgDn"  ACTION ItemsKey( K_PGDN )
         MENUITEM "~Previous   PgUp"  ACTION ItemsKey( K_PGUP )
         MENUITEM "~First      Home"  ACTION ItemsKey( K_HOME )
         MENUITEM "~Last       End"   ACTION ItemsKey( K_END )
      ENDMENU
      MENUITEM " ~Program "
      MENU
         MENUITEM "~Calculator"  ACTION WinFront( "calc" )
         MENUITEM "~Puzzle"      ACTION WinFront( "puzzle" )
         MENUITEM "~ASCII chart" ACTION WinFront( "ascii" )
      ENDMENU
      MENUITEM " ~Window "
      MENU
         MENUITEM "~Cycle      F4"    ACTION WinCycle()
         MENUITEM "~ITEMS"            ACTION WinFront( "items" )
         MENUITEM "~Calculator"       ACTION WinFront( "calc" )
         MENUITEM "~Puzzle"           ACTION WinFront( "puzzle" )
         MENUITEM "~ASCII chart"      ACTION WinFront( "ascii" )
         MENUITEM "~Debug (Output)"   ACTION WinFront( "debug" )
      ENDMENU
   ENDMENU

   DeskMenuColors( oMenu )

return oMenu

static procedure DeskMenuColors( oMenu )

   local oItem

   oMenu:cClrPopup    := "N/W"
   oMenu:cClrHotKey   := "R/W"
   oMenu:cClrHilite   := "N/BG"
   oMenu:cClrHotFocus := "R/BG"
   for each oItem in oMenu:aItems
      if HB_ISOBJECT( oItem:bAction )
         DeskMenuColors( oItem:bAction )
      endif
   next

return

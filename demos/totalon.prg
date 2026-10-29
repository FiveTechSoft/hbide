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

#define SCR_ROWS 25
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
procedure Main()

   local nOldCursor := SetCursor( SC_NONE )
   local cSave := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local nKey

   hb_cdpSelect( "UTF8" )
   SetMode( SCR_ROWS, SCR_COLS )
   Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_EXT )
   SetColor( "N/B" )
   CLEAR SCREEN

   s_h := DeskState()
   s_h[ "menu" ] := DeskMenu()
   DlgOpen()   // the reference photo shows the TOTAL ON dialog up

   do while ! s_h[ "quit" ]
      DeskRepaint()
      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      if s_h[ "menu" ]:IsOpen()
         s_h[ "menu" ]:ProcessKey( nKey )
         loop
      endif
      if s_h[ "dlg" ] != nil
         DlgKey( nKey )
         loop
      endif
      do case
      case nKey == K_ESC
         s_h[ "quit" ] := .T.
      case nKey == K_F10
         s_h[ "menu" ]:ShowPopup( 1 )
      case nKey == K_F9
         DlgOpen()
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
      "dlg"   => nil }

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
      do case
      case cId == "debug"   ; DebugPaint()
      case cId == "items"   ; ItemsPaint()
      case cId == "calc"    ; CalcPaint()
      case cId == "puzzle"  ; PuzzlePaint()
      case cId == "ascii"   ; AsciiPaint()
      endcase
   next
   if s_h[ "dlg" ] != nil
      DlgPaint()
   endif
   if s_h[ "menu" ] != nil
      s_h[ "menu" ]:Display()
   endif
   DispEnd()

return

//------------------------------------------------------------
// ITEMS: the big grey-framed, cyan-bodied record window
static procedure ItemsPaint()

   local h := s_h, r := h[ "recs" ][ h[ "rec" ] ]
   local lF := ( ATail( h[ "wins" ] ) == "items" ) .and. h[ "dlg" ] == nil

   WinShadow( IT_TOP, IT_LEFT, IT_BOTTOM, IT_RIGHT )
   WinFrame( IT_TOP, IT_LEFT, IT_BOTTOM, IT_RIGHT, "ITEMS", "N/BG", lF )

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
   local lF := ( ATail( h[ "wins" ] ) == "debug" ) .and. h[ "dlg" ] == nil
   local aVis := {}

   WinShadow( DBG_TOP, DBG_LEFT, DBG_BOTTOM, DBG_RIGHT )
   WinFrame( DBG_TOP, DBG_LEFT, DBG_BOTTOM, DBG_RIGHT, "Debug (Output)", "N/N", lF )
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
   local lF := ( ATail( h[ "wins" ] ) == "calc" ) .and. h[ "dlg" ] == nil

   WinShadow( CAL_TOP, CAL_LEFT, CAL_BOTTOM, CAL_RIGHT )
   WinFrame( CAL_TOP, CAL_LEFT, CAL_BOTTOM, CAL_RIGHT, "Calculator", "N/BG", lF )

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
   local lF := ( ATail( h[ "wins" ] ) == "puzzle" ) .and. h[ "dlg" ] == nil

   WinShadow( PZ_TOP, PZ_LEFT, PZ_BOTTOM, PZ_RIGHT )
   WinFrame( PZ_TOP, PZ_LEFT, PZ_BOTTOM, PZ_RIGHT, "Puzzle", "N/BG", lF )

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
   local lF := ( ATail( h[ "wins" ] ) == "ascii" ) .and. h[ "dlg" ] == nil

   WinShadow( AS_TOP, AS_LEFT, AS_BOTTOM, AS_RIGHT )
   WinFrame( AS_TOP, AS_LEFT, AS_BOTTOM, AS_RIGHT, nil, "N/BG", lF )

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
// simple centred message box in the desktop's grey style
static procedure MsgBox( cTitle, aLines )

   local nW := 12, i, nT, nL, nB, nR
   local cSave

   for each i in aLines
      nW := Max( nW, hb_ULen( i ) + 6 )
   next
   nW := Max( nW, hb_ULen( cTitle ) + 8 )
   nB := Len( aLines ) + 3
   nT := Int( ( SCR_ROWS - nB ) / 2 )
   nL := Int( ( SCR_COLS - nW ) / 2 )
   nR := nL + nW - 1
   nB += nT - 1

   cSave := SaveScreen( nT, nL, nB + 1, nR + 2 )
   WinShadow( nT, nL, nB, nR )
   WinFrame( nT, nL, nB, nR, cTitle, "N/W", .F. )
   for i := 1 to Len( aLines )
      hb_DispOutAt( nT + i, nL + 3, aLines[ i ], "N/W" )
   next
   hb_DispOutAt( nB - 1, nL + Max( 1, Int( ( nW - 16 ) / 2 ) ), " Press any key ", "N/W*" )
   Inkey( 0 )
   RestScreen( nT, nL, nB + 1, nR + 2, cSave )

return

//------------------------------------------------------------
// TOTAL ON dialog (modal)
static procedure DlgOpen()

   s_h[ "dlg" ] := { ;
      "focus"  => 0, ;       // 0 list, 1..4 checks, 5 expr, 6 saveas, 7 ok, 8 cancel
      "field"  => 1, ;       // selected field (ITEM, highlighted in the photo)
      "scope"  => .F., ;
      "for"    => .F., ;
      "while"  => .F., ;
      "fields" => .F., ;
      "expr"   => "", ;
      "saveas" => "", ;
      "ecur"   => 1, ;       // expr cursor
      "scur"   => 1 }        // saveas cursor

return

// { id, kind, row, col, caption } - rows/cols are absolute screen coords
static function DlgControls()

return { ;
   { 0, "list",  DL_TOP + 4,  DL_LEFT + 4,  "" }, ;
   { 1, "check", DL_TOP + 4,  DL_LEFT + 25, "Scope..." }, ;
   { 2, "check", DL_TOP + 6,  DL_LEFT + 25, "For..." }, ;
   { 3, "check", DL_TOP + 8,  DL_LEFT + 25, "While..." }, ;
   { 4, "check", DL_TOP + 10, DL_LEFT + 25, "Fields..." }, ;
   { 5, "get",   DL_TOP + 11, DL_LEFT + 3,  "<Expr... >" }, ;
   { 6, "get",   DL_TOP + 13, DL_LEFT + 3,  "<Save As...>" }, ;
   { 7, "btn",   DL_TOP + 12, DL_LEFT + 31, "<<  OK  >>" }, ;
   { 8, "btn",   DL_TOP + 14, DL_LEFT + 31, "< Cancel >" } }

static procedure DlgPaint()

   local d := s_h[ "dlg" ], i, aF
   local aC := DlgControls()

   // shadow + magenta body + frame + title
   WinShadow( DL_TOP, DL_LEFT, DL_BOTTOM, DL_RIGHT )
   hb_Scroll( DL_TOP, DL_LEFT, DL_BOTTOM, DL_RIGHT,,, "W/RB" )
   hb_DispBox( DL_TOP, DL_LEFT, DL_BOTTOM, DL_RIGHT, HB_B_SINGLE_UNI, "W/RB" )
   hb_DispOutAt( DL_TOP + 1, DL_LEFT + 3, "TOTAL ON:", "W+/RB" )

   // field list box (blue) with type column
   hb_Scroll( DL_TOP + 3, DL_LEFT + 3, DL_TOP + 10, DL_LEFT + 19,,, "W+/BG" )
   hb_DispBox( DL_TOP + 3, DL_LEFT + 3, DL_TOP + 10, DL_LEFT + 19, HB_B_SINGLE_UNI, "W+/BG" )
   for i := 1 to Len( s_aFldTypes )
      aF := s_aFldTypes[ i ]
      hb_DispOutAt( DL_TOP + 3 + i, DL_LEFT + 5,  PadR( aF[ 1 ], 9 ), ;
         iif( i == d[ "field" ], "W+/B", "W+/BG" ) )
      hb_DispOutAt( DL_TOP + 3 + i, DL_LEFT + 15, aF[ 2 ], ;
         iif( i == d[ "field" ], "W+/B", "W+/BG" ) )
   next

   // checkboxes
   for i := 2 to 5
      hb_DispOutAt( aC[ i ][ 3 ], aC[ i ][ 4 ], ;
         iif( d[ { "scope", "for", "while", "fields" }[ i - 1 ] ], "[x] ", "[ ] " ) + ;
         aC[ i ][ 5 ], iif( d[ "focus" ] == aC[ i ][ 1 ], "W+/RB", "W/RB" ) )
   next

   // Expr + Save As buttons with their entry boxes
   hb_DispOutAt( aC[ 6 ][ 3 ], aC[ 6 ][ 4 ], aC[ 6 ][ 5 ], ;
      iif( d[ "focus" ] == 5, "W+/RB", "W/RB" ) )
   hb_DispOutAt( aC[ 6 ][ 3 ], DL_LEFT + 13, PadR( d[ "expr" ], 18 ), ;
      iif( d[ "focus" ] == 5, "N/BG*", "N/BG" ) )
   hb_DispOutAt( aC[ 7 ][ 3 ], aC[ 7 ][ 4 ], aC[ 7 ][ 5 ], ;
      iif( d[ "focus" ] == 6, "W+/RB", "W/RB" ) )
   hb_DispOutAt( aC[ 7 ][ 3 ] + 1, DL_LEFT + 3, PadR( d[ "saveas" ], 28 ), ;
      iif( d[ "focus" ] == 6, "N/BG*", "N/BG" ) )

   // OK / Cancel
   hb_DispOutAt( aC[ 8 ][ 3 ], aC[ 8 ][ 4 ], aC[ 8 ][ 5 ], ;
      iif( d[ "focus" ] == 7, "W+/RB", "W/RB" ) )
   hb_DispOutAt( aC[ 9 ][ 3 ], aC[ 9 ][ 4 ], aC[ 9 ][ 5 ], ;
      iif( d[ "focus" ] == 8, "W+/RB", "W/RB" ) )

   // list focus marker
   if d[ "focus" ] == 0
      hb_DispOutAt( DL_TOP + 3 + d[ "field" ], DL_LEFT + 5, PadR( s_aFldTypes[ d[ "field" ] ][ 1 ], 9 ), "W+/B" )
      hb_DispOutAt( DL_TOP + 3 + d[ "field" ], DL_LEFT + 15, s_aFldTypes[ d[ "field" ] ][ 2 ], "W+/B" )
   endif

return

//------------------------------------------------------------
// line editing inside the two dialog entry boxes
static procedure DlgEditKey( nKey, cFld, cCur )

   local d := s_h[ "dlg" ]
   local c := d[ cFld ], p := d[ cCur ]

   do case
   case nKey == K_LEFT
      d[ cCur ] := Max( 1, p - 1 )
   case nKey == K_RIGHT
      d[ cCur ] := Min( Len( c ) + 1, p + 1 )
   case nKey == K_HOME
      d[ cCur ] := 1
   case nKey == K_END
      d[ cCur ] := Len( c ) + 1
   case nKey == K_BS
      if p > 1
         c := Left( c, p - 2 ) + SubStr( c, p )
         d[ cFld ] := c
         d[ cCur ] := p - 1
      endif
   case nKey == K_DEL
      if p <= Len( c )
         d[ cFld ] := Left( c, p - 1 ) + SubStr( c, p + 1 )
      endif
   case nKey >= 32 .and. nKey <= 126 .and. Len( c ) < 16
      d[ cFld ] := Left( c, p - 1 ) + Chr( nKey ) + SubStr( c, p )
      d[ cCur ] := p + 1
   endcase

return

static procedure DlgKey( nKey )

   local d := s_h[ "dlg" ]

   do case
   case nKey == K_ESC
      s_h[ "dlg" ] := nil
   case nKey == K_TAB
      d[ "focus" ] := ( d[ "focus" ] + 1 ) % 9
   case nKey == K_SH_TAB
      d[ "focus" ] := Mod( d[ "focus" ] + 8, 9 )
   case nKey == K_LBUTTONDOWN .or. nKey == K_LDBLCLK
      DlgClick( nKey )
   case d[ "focus" ] == 0
      do case
      case nKey == K_UP   ; d[ "field" ] := Max( 1, d[ "field" ] - 1 )
      case nKey == K_DOWN ; d[ "field" ] := Min( Len( s_aFldTypes ), d[ "field" ] + 1 )
      case nKey == K_ENTER ; d[ "focus" ] := 7
      endcase
   case d[ "focus" ] >= 1 .and. d[ "focus" ] <= 4
      if nKey == K_SPACE
         DlgToggle( d )
      elseif nKey == K_ENTER
         d[ "focus" ] := 7
      endif
   case d[ "focus" ] == 5
      if nKey == K_ENTER
         d[ "focus" ] := 7
      else
         DlgEditKey( nKey, "expr", "ecur" )
      endif
   case d[ "focus" ] == 6
      if nKey == K_ENTER
         d[ "focus" ] := 7
      else
         DlgEditKey( nKey, "saveas", "scur" )
      endif
   case d[ "focus" ] == 7
      do case
      case nKey == K_ENTER .or. nKey == K_SPACE
         DlgOk()
      case nKey == K_LEFT .or. nKey == K_RIGHT .or. nKey == K_UP .or. nKey == K_DOWN
         d[ "focus" ] := 8
      endcase
   case d[ "focus" ] == 8
      do case
      case nKey == K_ENTER .or. nKey == K_SPACE
         s_h[ "dlg" ] := nil
      case nKey == K_LEFT .or. nKey == K_RIGHT .or. nKey == K_UP .or. nKey == K_DOWN
         d[ "focus" ] := 7
      endcase
   endcase

return

static procedure DlgToggle( d )

   // Space or Enter toggles the focused checkbox
   do case
   case d[ "focus" ] == 1 ; d[ "scope" ]  := ! d[ "scope" ]
   case d[ "focus" ] == 2 ; d[ "for" ]    := ! d[ "for" ]
   case d[ "focus" ] == 3 ; d[ "while" ]  := ! d[ "while" ]
   case d[ "focus" ] == 4 ; d[ "fields" ] := ! d[ "fields" ]
   endcase

return

static procedure DlgClick( nKey )

   local d := s_h[ "dlg" ], aC, nR := MRow(), nC := MCol(), i

   for each aC in DlgControls()
      if nR == aC[ 3 ] .and. nC >= aC[ 4 ] .and. nC <= aC[ 4 ] + 16
         d[ "focus" ] := aC[ 1 ]
         if aC[ 2 ] == "check"
            DlgToggle( d )
         elseif aC[ 2 ] == "btn" .and. nKey == K_LDBLCLK
            if aC[ 1 ] == 7
               DlgOk()
            else
               s_h[ "dlg" ] := nil
            endif
         endif
         return
      endif
   next
   // click in the list box selects a field
   if nR >= DL_TOP + 4 .and. nR <= DL_TOP + 9 .and. ;
      nC >= DL_LEFT + 4 .and. nC <= DL_LEFT + 18
      d[ "focus" ] := 0
      d[ "field" ] := nR - DL_TOP - 3
   endif

return

//------------------------------------------------------------
// evaluate a FOR expression against one record (fields as memvars)
static function RecEval( r, cExpr )

   local u
   private ITEM := r[ "ITEM" ], QUANTITY := r[ "QUANTITY" ], ;
      DESCRIPT := r[ "DESCRIPT" ], COST := r[ "COST" ], ;
      PRICE := r[ "PRICE" ], TAXABLE := r[ "TAXABLE" ]

   BEGIN SEQUENCE WITH {| o | Break( o ) }
      u := &( cExpr )
   RECOVER
      return .F.
   END SEQUENCE

return HB_ISLOGICAL( u ) .and. u

//------------------------------------------------------------
static procedure DlgOk()

   local h := s_h, d := h[ "dlg" ]
   local aNums := {}, aLines := {}, cFld, i, nCnt := 0, nFrom := 1
   local aTotals := { => }, r, lUse, cTxt := ""

   if d[ "scope" ]
      nFrom := h[ "rec" ]      // REST from the current record
   endif
   if d[ "fields" ]
      for i := 1 to Len( s_aFldTypes )
         if s_aFldTypes[ i ][ 2 ] == "N"
            AAdd( aNums, s_aFldTypes[ i ][ 1 ] )
         endif
      next
   else
      if s_aFldTypes[ d[ "field" ] ][ 2 ] != "N"
         OutLine( h, "TOTAL ON " + s_aFldTypes[ d[ "field" ] ][ 1 ] + ;
            ": not a numeric field, nothing to total." )
         s_h[ "dlg" ] := nil
         WinFront( "debug" )
         return
      endif
      AAdd( aNums, s_aFldTypes[ d[ "field" ] ][ 1 ] )
   endif
   for each cFld in aNums
      aTotals[ cFld ] := 0
   next
   for i := nFrom to Len( h[ "recs" ] )
      r := h[ "recs" ][ i ]
      lUse := .T.
      if d[ "for" ] .and. ! Empty( AllTrim( d[ "expr" ] ) )
         lUse := RecEval( r, AllTrim( d[ "expr" ] ) )
      endif
      if lUse
         nCnt++
         for each cFld in aNums
            aTotals[ cFld ] += r[ cFld ]
         next
      endif
   next

   AAdd( aLines, "TOTAL ON " + iif( d[ "scope" ], "REST", "ALL" ) + ;
      iif( d[ "for" ] .and. ! Empty( AllTrim( d[ "expr" ] ) ), ;
      " FOR " + AllTrim( d[ "expr" ] ), "" ) + ;
      iif( d[ "while" ], " WHILE (demo: same as FOR)", "" ) + ":" )
   for each cFld in aNums
      AAdd( aLines, "  " + PadR( cFld, 9 ) + " = " + CalcFmt( aTotals[ cFld ] ) )
   next
   AAdd( aLines, "  " + hb_ntos( nCnt ) + " record(s) counted" )

   for i := 1 to Len( aLines )
      OutLine( h, aLines[ i ] )
      cTxt += aLines[ i ] + hb_eol()
   next
   if ! Empty( AllTrim( d[ "saveas" ] ) )
      if hb_MemoWrit( AllTrim( d[ "saveas" ] ), cTxt )
         OutLine( h, "Saved to " + AllTrim( d[ "saveas" ] ) )
      else
         OutLine( h, "Could not save to " + AllTrim( d[ "saveas" ] ) )
      endif
   endif

   s_h[ "dlg" ] := nil
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
         MENUITEM "~Total On...  F9"  ACTION DlgOpen()
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

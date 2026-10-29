//
// addressbook.prg - Address Book + Time Planner, built with hbide's own GUI
// (HbWindow dialogs, 3D shadowed PushButtons, GETs, HbMenu pulldowns).
//
// Visual reference: classic address-book card file - green shadowed buttons,
// A-Z index row, teal entry fields, binder rings, "Card n/N" footer.
// Sample data only; the Dial button never makes real calls.
//

#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
#include "hbmenu.ch"

#define SCR_ROWS 34
#define SCR_COLS 110

// book window geometry (screen coords, 0-based)
#define BK_TOP     2
#define BK_LEFT    2
#define BK_BOTTOM  29
#define BK_RIGHT   107

static s_h
static s_aShColor := {}

//------------------------------------------------------------
procedure Main()

   local nOldCursor := SetCursor( SC_NONE )
   local cSave := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local nKey

   hb_cdpSelect( "UTF8" )
   SetMode( SCR_ROWS, SCR_COLS )
   Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_EXT )
   SetColor( "N/W" )
   CLEAR SCREEN

   s_h := AgendaState()
   s_h[ "menu" ] := AgendaMenu()

   do while ! s_h[ "quit" ]
      AgendaRepaint()
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
      case nKey == K_LBUTTONDOWN .and. MRow() == 0
         s_h[ "menu" ]:ProcessKey( nKey )
      case nKey >= K_ALT_Q .and. nKey <= K_ALT_M
         s_h[ "menu" ]:ProcessKey( nKey )
      case s_h[ "view" ] == "book"
         BookKey( nKey )
      otherwise
         PlanKey( nKey )
      endcase
   enddo

   AgendaSave()
   SetColor( "W/N" )
   RestScreen( 0, 0, MaxRow(), MaxCol(), cSave )
   SetCursor( nOldCursor )

return

//------------------------------------------------------------
static function AgendaState()

   local h := { ;
      "quit"    => .F., ;
      "view"    => "book", ;
      "card"    => 1, ;
      "cards"   => {}, ;
      "speed"   => {}, ;
      "appts"   => { => }, ;
      "todos"   => {}, ;
      "planDate"=> 0d20260427, ;
      "apptSel" => 5, ;
      "todoSel" => 1, ;
      "planFoc" => "appt" }

   AgendaSeed( h )
   AgendaLoad( h )

return h

//------------------------------------------------------------
static function AgendaSeed( h )

   AAdd( h[ "cards" ], CardNew( "Mustermann", "Erika", "", "", "Dr.", ;
      "Mustermann GmbH & Co. KG", "Bahnhofstraße 123", "Coburg", "Bayern", ;
      "96450", "(09561) 123456789", "(09561) 987654321", "", "Nervensäge" ) )
   AAdd( h[ "cards" ], CardNew( "Adams", "Martha", "J.", "A-100", "", ;
      "Acme Corp", "5 Cherry Lane", "Springfield", "IL", "62701", ;
      "(217) 555-0100", "(217) 555-0101", "", "First customer" ) )
   AAdd( h[ "cards" ], CardNew( "Bauer", "Klaus", "", "B-200", "Ing.", ;
      "Bauer AG", "Hauptstr. 8", "München", "Bayern", "80331", ;
      "(089) 555100", "(089) 555101", "", "" ) )
   AAdd( h[ "cards" ], CardNew( "Keller", "Sabine", "M.", "K-300", "", ;
      "Keller & Partner", "Marktplatz 3", "Köln", "NRW", "50667", ;
      "(0221) 555200", "", "", "" ) )
   AAdd( h[ "cards" ], CardNew( "Zimmermann", "Hans", "", "Z-400", "", ;
      "", "Waldweg 12", "Freiburg", "BW", "79098", "(0761) 555300", "", ;
      "", "" ) )

   h[ "appts" ][ "20260427" ] := { { "12.00", "Mittagessen" } }
   h[ "todos" ] := { "Wikipedia Artikel bearbeiten", "Screenshot machen" }

return nil

static function CardNew( cLast, cFirst, cMiddle, cCode, cTitle, cCompany, ;
   cStreet, cTown, cCounty, cPcode, cHome, cBus, cAlt, cNotes )

return { "last" => cLast, "first" => cFirst, "middle" => cMiddle, ;
   "code" => cCode, "title" => cTitle, "company" => cCompany, ;
   "street" => cStreet, "town" => cTown, "county" => cCounty, ;
   "pcode" => cPcode, "home" => cHome, "bus" => cBus, "alt" => cAlt, ;
   "notes" => cNotes }

//------------------------------------------------------------
// field layout: { key, label, label row/col, box row/col, width }
static function AgendaFields()

return { ;
   { "last",    "Last Name",       9, 8,  10, 8,  28 }, ;
   { "first",   "First Name",      9, 38, 10, 38, 28 }, ;
   { "middle",  "Middle Name",     9, 68, 10, 68, 28 }, ;
   { "code",    "Code",            12, 8, 13, 8,  10 }, ;
   { "title",   "Title",           12, 22, 13, 22, 34 }, ;
   { "company", "Company",         12, 60, 13, 60, 40 }, ;
   { "street",  "Street",          15, 8, 16, 8,  60 }, ;
   { "town",    "Town/City",       18, 8, 19, 8,  24 }, ;
   { "county",  "County/State",    18, 38, 19, 38, 24 }, ;
   { "pcode",   "Postcode",        18, 68, 19, 68, 12 }, ;
   { "home",    "Home Phone",      21, 8, 22, 8,  28 }, ;
   { "bus",     "Business Phone",  21, 38, 22, 38, 28 }, ;
   { "alt",     "Alternate Phone", 21, 68, 22, 68, 28 }, ;
   { "notes",   "Notes",           24, 8, 25, 8,  88 } }

// buttons: { caption, row, col, id }
static function BookButtons()

return { ;
   { "New",     4, 8,  "new" }, ;
   { "Delete",  4, 24, "del" }, ;
   { "▲",       4, 42, "prev" }, ;
   { "▼",       4, 56, "next" }, ;
   { "Dial",    4, 70, "dial" }, ;
   { "+ Speed", 4, 88, "speed" } }

//------------------------------------------------------------
static function PadU( c, n )

   local l := hb_ULen( c )

return iif( l >= n, hb_ULeft( c, n ), c + Space( n - l ) )

//------------------------------------------------------------
static procedure AgendaRepaint()

   DispBegin()
   hb_Scroll( 0, 0, SCR_ROWS - 1, SCR_COLS - 1,,, "N/W" )
   if s_h[ "view" ] == "book"
      BookPaint()
      PaintStatus( " Ins-New Card   F8-Edit   ^L-Dial   ?-Search   *-Index   A-Z-Goto Section   F10-Menu " )
   else
      PlanPaint()
      PaintStatus( " Left/Right-Day   PgUp/PgDn-Month   Tab-Appts/ToDo   Enter-Edit   Ins-Add   Del-Delete   F10-Menu " )
   endif
   if s_h[ "menu" ] != nil
      s_h[ "menu" ]:Display()
   endif
   DispEnd()

return

//------------------------------------------------------------
static procedure PaintStatus( cText )

   hb_DispOutAt( SCR_ROWS - 1, 0, PadR( cText, SCR_COLS - 1 ), "N/W" )

return

//------------------------------------------------------------
static procedure BookPaint()

   local h := s_h
   local aB, cL, nCol, i, cLetter, hCard, aF, nCards := Len( h[ "cards" ] )
   local cCurLetter

   // shadow + body + frame
   hb_Scroll( BK_TOP + 1, BK_RIGHT + 1, BK_BOTTOM + 1, BK_RIGHT + 2,,, "N/N" )
   hb_Scroll( BK_BOTTOM + 1, BK_LEFT + 2, BK_BOTTOM + 1, BK_RIGHT + 2,,, "N/N" )
   hb_Scroll( BK_TOP, BK_LEFT, BK_BOTTOM, BK_RIGHT,,, "N/W" )
   hb_DispBox( BK_TOP, BK_LEFT, BK_BOTTOM, BK_RIGHT, HB_B_SINGLE_UNI, "N/W" )

   // dark title band, like the reference
   hb_DispOutAt( BK_TOP, BK_LEFT, ;
      hb_UTF8ToStr( "┌" ) + Replicate( hb_UTF8ToStr( "─" ), BK_RIGHT - BK_LEFT - 1 ) + hb_UTF8ToStr( "┐" ), "W/N" )
   hb_DispOutAt( BK_TOP, BK_LEFT + 2, "[", "W/N" )
   hb_DispOutAt( BK_TOP, BK_LEFT + 3, hb_UTF8ToStr( "■" ), "G/N" )
   hb_DispOutAt( BK_TOP, BK_LEFT + 4, "]", "W/N" )
   hb_DispOutAt( BK_TOP, BK_LEFT + Int( ( BK_RIGHT - BK_LEFT - 22 ) / 2 ), " Address Book - ADDRESS ", "W+/N" )
   hb_DispOutAt( BK_TOP, BK_RIGHT - 7, "2-[", "W/N" )
   hb_DispOutAt( BK_TOP, BK_RIGHT - 4, hb_UTF8ToStr( "↑" ), "W/N" )
   hb_DispOutAt( BK_TOP, BK_RIGHT - 3, "]", "W/N" )

   // buttons, hbide 3D half-cell shadow look (hbbutton.prg BtnDisplay)
   for each aB in BookButtons()
      PaintBtn( aB[ 2 ], aB[ 3 ], aB[ 1 ], .F. )
   next

   // A-Z index row
   nCol := 8
   cCurLetter := iif( nCards > 0, Upper( Left( h[ "cards" ][ h[ "card" ] ][ "last" ], 1 ) ), "" )
   for i := 1 to 26
      cLetter := Chr( 64 + i )
      hb_DispOutAt( 6, nCol, cLetter, iif( cLetter == cCurLetter, "N/G", "GR+/W" ) )
      nCol += 2
   next
   hb_DispOutAt( 6, 88, "INDEX", "GR+/W" )

   // labels + teal fields
   hCard := h[ "cards" ][ h[ "card" ] ]
   for each aF in AgendaFields()
      hb_DispOutAt( aF[ 3 ], aF[ 4 ], aF[ 2 ], "B/W" )
      hb_DispOutAt( aF[ 5 ], aF[ 6 ], PadU( hCard[ aF[ 1 ] ], aF[ 7 ] ), "W/BG" )
   next

   // footer inside the window, below the hooks, on the grey background
   hb_DispOutAt( BK_BOTTOM + 3, 8, "Card " + hb_ntos( h[ "card" ] ) + "/" + hb_ntos( nCards ) + ;
      " " + Replicate( hb_UTF8ToStr( "─" ), 76 ), "N/W" )

   // binder rings: three separate hooks - dark head on the card, white
   // strap hanging through the card's bottom edge, ending above the footer
   for each i in { 18, 52, 86 }
      hb_DispOutAt( 27, i, Space( 3 ), "N/N" )
      hb_DispOutAt( 28, i, " ", "N/N" )
      hb_DispOutAt( 28, i + 1, " ", "N/W*" )
      hb_DispOutAt( 28, i + 2, " ", "N/N" )
      hb_DispOutAt( 29, i + 1, " ", "N/W*" )
      hb_DispOutAt( 30, i + 1, " ", "N/W*" )
   next

return

//------------------------------------------------------------
// paints one green 3D button with the hbide half-cell shadow:
// face one cell right of nCol (left inset keeps the body color),
// ▄ cell flush right of the face, ▀ stripe below shifted one right.
static procedure PaintBtn( nRow, nCol, cCaption, lFocus )

   local nLen := hb_ULen( cCaption )

   hb_DispOutAt( nRow, nCol + 1, " " + cCaption + " ", iif( lFocus, "W+/G", "N/G" ) )
   hb_DispOutAt( nRow, nCol + nLen + 3, hb_UTF8ToStr( "▄" ), HBBtnShadowColor() )
   hb_DispOutAt( nRow + 1, nCol + 2, Replicate( hb_UTF8ToStr( "▀" ), nLen + 2 ), HBBtnShadowColor() )

return

//------------------------------------------------------------
static procedure BookKey( nKey )

   local h := s_h
   local nCards := Len( h[ "cards" ] )

   do case
   case nKey == K_F8
      BookEdit()
   case nKey == K_INS
      BookNewCard()
   case nKey == K_DEL
      BookDelete()
   case nKey == K_UP .or. nKey == K_PGUP
      h[ "card" ] := Max( 1, h[ "card" ] - 1 )
   case nKey == K_DOWN .or. nKey == K_PGDN
      h[ "card" ] := Min( nCards, h[ "card" ] + 1 )
   case nKey == K_HOME
      h[ "card" ] := 1
   case nKey == K_END
      h[ "card" ] := nCards
   case nKey == 12                    // Ctrl+L
      BookDial()
   case nKey == Asc( "+" )
      BookSpeedAdd()
   case nKey == Asc( "?" )
      BookSearch()
   case nKey == Asc( "*" )
      BookIndexDlg()
   case nKey >= Asc( "A" ) .and. nKey <= Asc( "Z" )
      BookGotoLetter( Chr( nKey ) )
   case nKey >= Asc( "a" ) .and. nKey <= Asc( "z" )
      BookGotoLetter( Upper( Chr( nKey ) ) )
   case nKey == K_LBUTTONDOWN .or. nKey == K_LDBLCLK
      BookClick( nKey )
   endcase

return

//------------------------------------------------------------
static procedure BookGotoLetter( cLetter )

   local h := s_h, n

   for n := 1 to Len( h[ "cards" ] )
      if Upper( Left( h[ "cards" ][ n ][ "last" ], 1 ) ) == cLetter
         h[ "card" ] := n
         exit
      endif
   next

return

//------------------------------------------------------------
static procedure BookClick( nKey )

   local h := s_h
   local nR := MRow(), nC := MCol(), aB, nLen, n

   // buttons row
   for each aB in BookButtons()
      nLen := hb_ULen( aB[ 1 ] )
      if nR == aB[ 2 ] .and. nC >= aB[ 3 ] + 1 .and. nC <= aB[ 3 ] + nLen + 2
         do case
         case aB[ 4 ] == "new"   ; BookNewCard()
         case aB[ 4 ] == "del"   ; BookDelete()
         case aB[ 4 ] == "prev"  ; h[ "card" ] := Max( 1, h[ "card" ] - 1 )
         case aB[ 4 ] == "next"  ; h[ "card" ] := Min( Len( h[ "cards" ] ), h[ "card" ] + 1 )
         case aB[ 4 ] == "dial"  ; BookDial()
         case aB[ 4 ] == "speed" ; BookSpeedAdd()
         endcase
         return
      endif
   next

   // A-Z row
   if nR == 6 .and. nC >= 8 .and. nC <= 58 .and. ( nC - 8 ) % 2 == 0
      n := Int( ( nC - 8 ) / 2 ) + 1
      if n >= 1 .and. n <= 26
         BookGotoLetter( Chr( 64 + n ) )
      endif
   endif

   // double-click a field edits the card
   if nKey == K_LDBLCLK
      BookEdit()
   endif

return

//------------------------------------------------------------
static procedure BookNewCard()

   local h := s_h

   AAdd( h[ "cards" ], CardNew( "", "", "", "", "", "", "", "", "", "", "", "", "", "" ) )
   h[ "card" ] := Len( h[ "cards" ] )
   AgendaRepaint()
   BookEdit()

return

//------------------------------------------------------------
static procedure BookDelete()

   local h := s_h

   if Len( h[ "cards" ] ) <= 1
      h[ "cards" ] := { CardNew( "", "", "", "", "", "", "", "", "", "", "", "", "", "" ) }
      h[ "card" ] := 1
   else
      ADel( h[ "cards" ], h[ "card" ] )
      ASize( h[ "cards" ], Len( h[ "cards" ] ) - 1 )
      h[ "card" ] := Min( h[ "card" ], Len( h[ "cards" ] ) )
   endif

return

//------------------------------------------------------------
// F8: edit the current card in place, over the painted fields
static procedure BookEdit()

   local h := s_h
   local hCard := h[ "cards" ][ h[ "card" ] ]
   local hTmp := hb_HClone( hCard )   // edit a copy; Esc discards it
   local aF, GetList := {}, nOld := SetCursor( SC_NORMAL ), nMask
   local oGet

   // GET buffer length = initial value length: pad to the box width or an
   // empty field (new card) would reject any typing
   for each aF in AgendaFields()
      hTmp[ aF[ 1 ] ] := PadR( hb_ValToStr( hTmp[ aF[ 1 ] ] ), aF[ 7 ] )
   next
   for each aF in AgendaFields()
      oGet := GetNew( aF[ 5 ], aF[ 6 ], {| x | iif( x == NIL, hTmp[ aF[ 1 ] ], ;
         hTmp[ aF[ 1 ] ] := x ) }, aF[ 1 ] )
      oGet:picture := "@S" + hb_ntos( aF[ 7 ] )
      oGet:colorSpec := "W/BG,N/G,W/BG,R/BG"
      AAdd( GetList, oGet )
   next

   // El READ core usa Inkey(0) clasico: retira HB_INKEY_EXT del eventmask
   // durante el READ (si no, Escape llega como EXKEY_ESC y no sale).
   nMask := Set( _SET_EVENTMASK, hb_bitAnd( Set( _SET_EVENTMASK ), hb_bitNot( HB_INKEY_EXT ) ) )
   READ
   Set( _SET_EVENTMASK, nMask )

   SetCursor( nOld )
   if LastKey() != K_ESC
      for each aF in AgendaFields()
         hCard[ aF[ 1 ] ] := AllTrim( hb_ValToStr( hTmp[ aF[ 1 ] ] ) )
      next
      AgendaSave()
   endif

return

//------------------------------------------------------------
static function CardPhone( hCard )

return iif( ! Empty( hCard[ "bus" ] ), hCard[ "bus" ], ;
       iif( ! Empty( hCard[ "home" ] ), hCard[ "home" ], hCard[ "alt" ] ) )

static function CardName( hCard )

return AllTrim( hCard[ "first" ] + " " + hCard[ "last" ] )

//------------------------------------------------------------
static procedure BookDial()

   local h := s_h
   local hCard := h[ "cards" ][ h[ "card" ] ]
   local cPhone := CardPhone( hCard )

   if Empty( cPhone )
      MsgBox( "Phone - Dial", { "No phone number on this card." } )
   else
      MsgBox( "Phone - Dial", { "Dialing " + cPhone + " ...", CardName( hCard ), ;
         "(demo sample - no real call)" } )
   endif

return

static procedure BookSpeedAdd()

   local h := s_h
   local hCard := h[ "cards" ][ h[ "card" ] ]
   local cPhone := CardPhone( hCard )

   if Empty( cPhone )
      BookFlash( "No phone number on this card" )
   elseif AScan( h[ "speed" ], {| a | a[ 2 ] == cPhone } ) > 0
      MsgBox( "Speed Dial", { "Already in the Speed Dial list." } )
   else
      AAdd( h[ "speed" ], { CardName( hCard ), cPhone } )
      AgendaSave()
      MsgBox( "Speed Dial", { "Added to Speed Dial:", CardName( hCard ) + "  " + cPhone } )
   endif

return

static procedure BookSearch()

   local h := s_h, n, cQ

   cQ := AskBox( "Search", "Text to find in Last Name:", "" )
   if cQ != NIL .and. ! Empty( cQ )
      for n := 1 to Len( h[ "cards" ] )
         if Upper( cQ ) $ Upper( h[ "cards" ][ n ][ "last" ] )
            h[ "card" ] := n
            exit
         endif
      next
      if n > Len( h[ "cards" ] )
         MsgBox( "Search", { "'" + cQ + "' not found" } )
      endif
   endif

return

static procedure BookIndexDlg()

   local h := s_h, n, cL, oDlg, GetList := {}, lDummy
   local aLetters := {}, aItems := {}, nSel := 1, nH

   for n := 1 to 26
      cL := Chr( 64 + n )
      if AScan( h[ "cards" ], {| c | Upper( Left( c[ "last" ], 1 ) ) == cL } ) > 0
         AAdd( aLetters, cL )
      endif
   next
   if Empty( aLetters )
      return
   endif
   for each cL in aLetters
      n := AScan( h[ "cards" ], {| c | Upper( Left( c[ "last" ], 1 ) ) == cL } )
      AAdd( aItems, " " + cL + "  " + h[ "cards" ][ n ][ "last" ] )
   next
   nH := Min( Len( aItems ) + 5, 16 )
   oDlg := NewDlg( "Index", 26, nH )
   @ oDlg:nTop + 1, oDlg:nLeft + 2, oDlg:nBottom - 3, oDlg:nRight - 2 ;
      GET nSel LISTBOX aItems COLOR "N/W,W+/N,N/W,W+/G,N/W,W+/W,GR+/W"
   @ oDlg:nBottom - 2, oDlg:nLeft + 8 GET lDummy PUSHBUTTON CAPTION " &Goto " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )
   BookGotoLetter( aLetters[ nSel ] )

return

// transient notice on the status row
static procedure BookFlash( cMsg )

   hb_DispOutAt( SCR_ROWS - 1, 0, PadR( " " + cMsg, SCR_COLS - 1 ), "N/R" )
   Inkey( 1.2 )

return

//------------------------------------------------------------
static procedure AgendaSave()

   local h := s_h

   if h != nil
      hb_MemoWrit( "addressbook.dat", hb_Serialize( { h[ "cards" ], h[ "speed" ], h[ "appts" ], h[ "todos" ] } ) )
   endif

return

static procedure AgendaLoad( h )

   local u

   if hb_FileExists( "addressbook.dat" )
      BEGIN SEQUENCE WITH {| o | Break( o ) }
         u := hb_Deserialize( hb_MemoRead( "addressbook.dat" ) )
         if HB_ISARRAY( u ) .and. Len( u ) == 4
            h[ "cards" ] := u[ 1 ]
            h[ "speed" ] := u[ 2 ]
            h[ "appts" ] := u[ 3 ]
            h[ "todos" ] := u[ 4 ]
         endif
      RECOVER
      END SEQUENCE
   endif
   if Empty( h[ "cards" ] )
      AAdd( h[ "cards" ], CardNew( "", "", "", "", "", "", "", "", "", "", "", "", "", "" ) )
   endif

return

//------------------------------------------------------------
static procedure AgendaView( cView )

   s_h[ "view" ] := cView

return

static procedure BookNav( n )

   local h := s_h

   h[ "card" ] := Max( 1, Min( Len( h[ "cards" ] ), h[ "card" ] + n ) )

return

static procedure BookGotoDlg()

   local h := s_h, cN

   cN := AskBox( "Goto card", "Card number (1-" + hb_ntos( Len( h[ "cards" ] ) ) + "):", ;
      hb_ntos( h[ "card" ] ) )
   if cN != NIL .and. Val( cN ) >= 1 .and. Val( cN ) <= Len( h[ "cards" ] )
      h[ "card" ] := Int( Val( cN ) )
   endif

return

//------------------------------------------------------------
// menu bar: File Edit Search Records SpeedDial Phone Window Help
static function AgendaMenu()

   local oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~Address Book"        ACTION AgendaView( "book" )
         MENUITEM "~Time Planner"        ACTION AgendaView( "plan" )
         SEPARATOR
         MENUITEM "E~xit"                ACTION s_h[ "quit" ] := .T.
      ENDMENU
      MENUITEM " ~Edit "
      MENU
         MENUITEM "~Edit card    F8"     ACTION BookEdit()
         MENUITEM "~New card    Ins"     ACTION BookNewCard()
         MENUITEM "~Delete card Del"     ACTION BookDelete()
      ENDMENU
      MENUITEM " ~Search "
      MENU
         MENUITEM "~Find...     ?"       ACTION BookSearch()
         MENUITEM "~Index...    *"       ACTION BookIndexDlg()
         MENUITEM "~Goto card..."        ACTION BookGotoDlg()
      ENDMENU
      MENUITEM " ~Records "
      MENU
         MENUITEM "~New        Ins"      ACTION BookNewCard()
         MENUITEM "~Delete     Del"      ACTION BookDelete()
         MENUITEM "~Next       PgDn"     ACTION BookNav( 1 )
         MENUITEM "~Previous   PgUp"     ACTION BookNav( -1 )
      ENDMENU
      MENUITEM " ~SpeedDial "
      MENU
         MENUITEM "~Add current  +"      ACTION BookSpeedAdd()
         MENUITEM "~Speed dial..."       ACTION SpeedDialList()
      ENDMENU
      MENUITEM " ~Phone "
      MENU
         MENUITEM "~Dial    Ctrl+L"      ACTION BookDial()
      ENDMENU
      MENUITEM " ~Window "
      MENU
         MENUITEM "~Address Book"        ACTION AgendaView( "book" )
         MENUITEM "~Time Planner"        ACTION AgendaView( "plan" )
      ENDMENU
      MENUITEM " ~Help "
      MENU
         MENUITEM "~About..."            ACTION MsgBox( "About", { ;
            "Address Book + Time Planner", "", ;
            "Built with hbide's own GUI (pure Harbour):", ;
            "HbWindow, shadowed PushButtons, GETs, HbMenu.", ;
            "Sample data only; Dial never makes real calls." } )
      ENDMENU
   ENDMENU

   AgendaMenuColors( oMenu )

return oMenu

static procedure AgendaMenuColors( oMenu )

   local oItem

   oMenu:cClrPopup    := "N/W"
   oMenu:cClrHotKey   := "R/W"
   oMenu:cClrHilite   := "N/BG"
   oMenu:cClrHotFocus := "R/BG"
   for each oItem in oMenu:aItems
      if HB_ISOBJECT( oItem:bAction )
         AgendaMenuColors( oItem:bAction )
      endif
   next

return

//------------------------------------------------------------
// small dialogs on hbide's HbWindow + shadowed PushButtons
// NewDlg: bright-white caption; DlgActivate: button shadows in the
// dialog's teal body color (BtnDisplay default "N/W" is for grey bodies)
// PushButtons paint at @-time (before Activate), so the teal shadow color
// must be armed in NewDlg and stay until DlgActivate restores it. A stack
// keeps nested dialogs right.
static function NewDlg( cTitle, nW, nH )

   local oDlg := HBWindow():Dialog( cTitle, nW, nH )

   AAdd( s_aShColor, HBBtnShadowColor( "N/BG" ) )
   if __objHasData( oDlg, "cCaptionColor" )
      oDlg:cCaptionColor := "N/W"   // white title patch, like Run arguments
      oDlg:Hide()
      oDlg:Show()
   endif

return oDlg

static procedure DlgActivate( oDlg, GetList )

   oDlg:Activate( GetList )
   if ! Empty( s_aShColor )
      HBBtnShadowColor( ATail( s_aShColor ) )
      ASize( s_aShColor, Len( s_aShColor ) - 1 )
   endif

return

static procedure MsgBox( cTitle, aLines )

   local oDlg, GetList := {}, lDummy, i
   local nW := 12, nH := Len( aLines ) + 5

   for each i in aLines
      nW := Max( nW, hb_ULen( i ) + 6 )
   next
   oDlg := NewDlg( cTitle, nW, nH )
   for i := 1 to Len( aLines )
      hb_DispOutAt( oDlg:nTop + 1 + i, oDlg:nLeft + 3, aLines[ i ], "N/BG" )
   next
   @ oDlg:nBottom - 2, oDlg:nLeft + Int( ( nW - 8 ) / 2 ) GET lDummy ;
      PUSHBUTTON CAPTION " &OK " COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )

return

static function AskBox( cTitle, cPrompt, cValue )

   local oDlg, GetList := {}, lOk := .F., lDummy
   local nW := Max( hb_ULen( cPrompt ) + 6, 42 )

   oDlg := NewDlg( cTitle, nW, 9 )
   hb_DispOutAt( oDlg:nTop + 2, oDlg:nLeft + 3, cPrompt, "N/BG" )
   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cValue PICTURE "@S" + hb_ntos( nW - 8 ) ;
      COLOR "N/W,N/G,N/W,R/W"
   @ oDlg:nBottom - 2, oDlg:nLeft + nW - 22 GET lDummy PUSHBUTTON CAPTION " &OK " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| lOk := .T., oDlg:End()}
   @ oDlg:nBottom - 2, oDlg:nLeft + nW - 12 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )

return iif( lOk, AllTrim( hb_ValToStr( cValue ) ), NIL )

static function ConfirmBox( cTitle, cMsg )

   local oDlg, GetList := {}, lYes := .F., lDummy
   local nW := Max( hb_ULen( cMsg ) + 6, 34 )

   oDlg := NewDlg( cTitle, nW, 8 )
   hb_DispOutAt( oDlg:nTop + 2, oDlg:nLeft + 3, cMsg, "N/BG" )
   @ oDlg:nBottom - 2, oDlg:nLeft + nW - 22 GET lDummy PUSHBUTTON CAPTION " &Yes " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| lYes := .T., oDlg:End()}
   @ oDlg:nBottom - 2, oDlg:nLeft + nW - 12 GET lDummy PUSHBUTTON CAPTION " &No " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )

return lYes

static procedure SpeedDialList()

   local h := s_h, aItems := {}, a, oDlg, GetList := {}
   local nSel := 1, lDummy, nH, lDial := .F.

   if Empty( h[ "speed" ] )
      MsgBox( "Speed Dial", { "The Speed Dial list is empty.", ;
         "Use + Speed on a card to add its number." } )
      return
   endif
   for each a in h[ "speed" ]
      AAdd( aItems, " " + PadR( a[ 1 ], 18 ) + " " + a[ 2 ] )
   next
   nH := Min( Len( aItems ) + 6, 16 )
   oDlg := NewDlg( "Speed Dial", 44, nH )
   @ oDlg:nTop + 1, oDlg:nLeft + 2, oDlg:nBottom - 3, oDlg:nRight - 2 ;
      GET nSel LISTBOX aItems COLOR "N/W,W+/N,N/W,W+/G,N/W,W+/W,GR+/W"
   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON CAPTION " &Dial " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| lDial := .T., oDlg:End()}
   @ oDlg:nBottom - 2, oDlg:nLeft + 24 GET lDummy PUSHBUTTON CAPTION " &Close " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )
   if lDial
      a := h[ "speed" ][ nSel ]
      MsgBox( "Phone - Dial", { "Dialing " + a[ 2 ], a[ 1 ], ;
         "(demo sample - no real call)" } )
   endif

return

// delete current card with confirmation
static procedure BookDeleteAsk()

   if ConfirmBox( "Delete card", "Delete this card?" )
      BookDelete()
   endif

return

//------------------------------------------------------------
// Time Planner
static function NextMonth( d )

   local d2 := d + 32

return d2 - Day( d2 ) + 1

static function PrevMonth( d )

   local d1 := d - Day( d )       // last day of previous month

return d1 - Day( d1 ) + 1

// visible appointment rows for a date: base hours 8..15 plus custom times
static function PlanRows( d )

   local h := s_h
   local aBase := {}, aX, a, cT, aRet := {}, n, i

   for i := 8 to 15
      AAdd( aBase, hb_ntos( i ) + ".00" )
   next
   aX := hb_HGetDef( h[ "appts" ], DToS( d ), {} )
   for each a in aX
      if AScan( aBase, a[ 1 ] ) == 0
         AAdd( aBase, a[ 1 ] )
      endif
   next
   ASort( aBase,,, {| x, y | TimeMin( x ) < TimeMin( y ) } )
   for each cT in aBase
      n := AScan( aX, {| a | a[ 1 ] == cT } )
      AAdd( aRet, { cT, iif( n > 0, aX[ n ][ 2 ], "" ) } )
   next

return aRet

static function TimeMin( cT )

   local a := hb_ATokens( cT, "." )

return Val( a[ 1 ] ) * 60 + iif( Len( a ) > 1, Val( a[ 2 ] ), 0 )

static procedure CalMonth( nTop, nLeft, dMonth, dSel )

   local cName := CMonth( dMonth )
   local nFirst := dMonth - Day( dMonth ) + 1
   local nDow0 := Dow( nFirst ) - 1          // 0 = Sunday
   local nDays := Day( NextMonth( dMonth ) - 1 )
   local nDay, nOff, lSel

   hb_DispOutAt( nTop, nLeft + Int( ( 20 - Len( cName ) ) / 2 ), cName, "B/BG" )
   hb_DispOutAt( nTop + 1, nLeft, "Su Mo Tu We Th Fr Sa", "B/BG" )
   for nDay := 1 to nDays
      nOff := nDow0 + nDay - 1
      lSel := dSel != NIL .and. nDay == Day( dSel )
      hb_DispOutAt( nTop + 2 + Int( nOff / 7 ), nLeft + ( nOff % 7 ) * 3, ;
         PadL( hb_ntos( nDay ), 2 ), iif( lSel, "N/G", "N/BG" ) )
   next

return

static procedure PlanPaint()

   local h := s_h
   local d := h[ "planDate" ]
   local aRows := PlanRows( d ), i, nR, lSel
   local nTopAppt, cPrevSh

   // title band
   hb_DispOutAt( 1, 0, Space( SCR_COLS ), "W/N" )
   hb_DispOutAt( 1, Int( ( SCR_COLS - 18 ) / 2 ), "Time Planner - APP", "W/N" )
   hb_DispOutAt( 1, SCR_COLS - 3, "1-", "W/N" )

   // day navigation
   PaintBtn( 3, 4, hb_UTF8ToStr( "◄" ), .F. )
   PaintBtn( 3, 99, hb_UTF8ToStr( "►" ), .F. )
   hb_DispOutAt( 3, Int( ( SCR_COLS - 26 ) / 2 ), ;
      CDow( d ) + "  " + hb_ntos( Day( d ) ) + " " + Left( CMonth( d ), 3 ) + ;
      " " + hb_ntos( Year( d ) ), "B/W" )

   // two-month calendar panel
   hb_Scroll( 5, 4, 24, 31,,, "N/BG" )
   CalMonth( 5, 5, d, d )
   cPrevSh := HBBtnShadowColor( "N/BG" )
   PaintBtn( 12, 26, hb_UTF8ToStr( "▲" ), .F. )
   PaintBtn( 14, 26, hb_UTF8ToStr( "▼" ), .F. )
   HBBtnShadowColor( cPrevSh )
   CalMonth( 16, 5, NextMonth( d ), NIL )

   // appointments panel
   hb_Scroll( 5, 34, 16, 109,,, "W/B" )
   hb_DispOutAt( 5, 34 + Int( ( 74 - 12 ) / 2 ), "Appointments", "W+/B" )
   h[ "apptSel" ] := Max( 1, Min( h[ "apptSel" ], Max( 1, Len( aRows ) ) ) )
   nTopAppt := Max( 1, Min( h[ "apptSel" ] - 4, Max( 1, Len( aRows ) - 7 ) ) )
   for i := 0 to 8
      if nTopAppt + i > Len( aRows )
         exit
      endif
      nR := 7 + i
      lSel := h[ "planFoc" ] == "appt" .and. nTopAppt + i == h[ "apptSel" ]
      if lSel
         hb_DispOutAt( nR, 36, Space( 70 ), "N/G" )
         hb_DispOutAt( nR, 35, "[", "GR+/B" )
      endif
      hb_DispOutAt( nR, 40, PadR( aRows[ nTopAppt + i ][ 1 ], 7 ), ;
         iif( lSel, "N/G", "GR+/B" ) )
      hb_DispOutAt( nR, 50, aRows[ nTopAppt + i ][ 2 ], iif( lSel, "N/G", "W/B" ) )
   next

   // divider + ToDo panel
   hb_DispOutAt( 17, 34, Replicate( hb_UTF8ToStr( "─" ), 76 ), "GR/B" )
   hb_Scroll( 18, 34, 24, 109,,, "W/B" )
   hb_DispOutAt( 18, 34 + Int( ( 74 - 9 ) / 2 ), "ToDo list", "W/B" )
   h[ "todoSel" ] := Max( 1, Min( h[ "todoSel" ], Max( 1, Len( h[ "todos" ] ) ) ) )
   for i := 1 to Min( Len( h[ "todos" ] ), 4 )
      nR := 19 + i
      lSel := h[ "planFoc" ] == "todo" .and. i == h[ "todoSel" ]
      if lSel
         hb_DispOutAt( nR, 36, Space( 70 ), "N/G" )
      endif
      hb_DispOutAt( nR, 38, hb_UTF8ToStr( "•" ), iif( lSel, "N/G", "GR+/B" ) )
      hb_DispOutAt( nR, 40, h[ "todos" ][ i ], iif( lSel, "N/G", "W/B" ) )
   next

return

static procedure PlanKey( nKey )

   local h := s_h
   local d := h[ "planDate" ]

   do case
   case nKey == K_LEFT
      h[ "planDate" ] := d - 1
   case nKey == K_RIGHT
      h[ "planDate" ] := d + 1
   case nKey == K_PGUP
      h[ "planDate" ] := PrevMonth( d )
   case nKey == K_PGDN
      h[ "planDate" ] := NextMonth( d )
   case nKey == K_UP
      if h[ "planFoc" ] == "appt"
         h[ "apptSel" ] := Max( 1, h[ "apptSel" ] - 1 )
      else
         h[ "todoSel" ] := Max( 1, h[ "todoSel" ] - 1 )
      endif
   case nKey == K_DOWN
      if h[ "planFoc" ] == "appt"
         h[ "apptSel" ] := Min( Max( 1, Len( PlanRows( d ) ) ), h[ "apptSel" ] + 1 )
      else
         h[ "todoSel" ] := Min( Max( 1, Len( h[ "todos" ] ) ), h[ "todoSel" ] + 1 )
      endif
   case nKey == K_TAB
      h[ "planFoc" ] := iif( h[ "planFoc" ] == "appt", "todo", "appt" )
   case nKey == K_ENTER
      if h[ "planFoc" ] == "appt"
         PlanEditAppt( .F. )
      else
         PlanEditTodo( .F. )
      endif
   case nKey == K_INS
      if h[ "planFoc" ] == "appt"
         PlanEditAppt( .T. )
      else
         PlanEditTodo( .T. )
      endif
   case nKey == K_DEL
      if h[ "planFoc" ] == "appt"
         PlanDelAppt()
      else
         PlanDelTodo()
      endif
   case nKey == K_LBUTTONDOWN .or. nKey == K_LDBLCLK
      PlanClick( nKey )
   endcase

return

static procedure PlanClick( nKey )

   local h := s_h
   local nR := MRow(), nC := MCol(), aRows, n, nDow0, nDays, d := h[ "planDate" ]

   do case
   case nR == 3 .and. nC >= 5 .and. nC <= 7      // prev day
      h[ "planDate" ] := d - 1
   case nR == 3 .and. nC >= 100 .and. nC <= 102  // next day
      h[ "planDate" ] := d + 1
   case ( nR == 12 .or. nR == 13 ) .and. nC >= 26 .and. nC <= 30   // month up
      h[ "planDate" ] := PrevMonth( d )
   case ( nR == 14 .or. nR == 15 ) .and. nC >= 26 .and. nC <= 30   // month down
      h[ "planDate" ] := NextMonth( d )
   case nR >= 7 .and. nR <= 12 .and. nC >= 5 .and. nC <= 25   // calendar 1
      nDow0 := Dow( d - Day( d ) + 1 ) - 1
      nDays := Day( NextMonth( d ) - 1 )
      n := ( nR - 7 ) * 7 + Int( ( nC - 5 ) / 3 ) + 1 - nDow0
      if n >= 1 .and. n <= nDays
         h[ "planDate" ] := d - Day( d ) + n
      endif
   case nR >= 18 .and. nR <= 23 .and. nC >= 5 .and. nC <= 25  // calendar 2
      d := NextMonth( d )
      nDow0 := Dow( d ) - 1
      nDays := Day( NextMonth( d ) - 1 )
      n := ( nR - 18 ) * 7 + Int( ( nC - 5 ) / 3 ) + 1 - nDow0
      if n >= 1 .and. n <= nDays
         h[ "planDate" ] := d + n - 1
      endif
   case nR >= 7 .and. nR <= 15 .and. nC >= 35    // appointment rows
      aRows := PlanRows( h[ "planDate" ] )
      n := nR - 7 + Max( 1, Min( h[ "apptSel" ] - 4, Max( 1, Len( aRows ) - 7 ) ) )
      if n >= 1 .and. n <= Len( aRows )
         h[ "planFoc" ] := "appt"
         h[ "apptSel" ] := n
         if nKey == K_LDBLCLK
            PlanEditAppt( .F. )
         endif
      endif
   case nR >= 20 .and. nR <= 23 .and. nC >= 35   // todo rows
      n := nR - 19
      if n >= 1 .and. n <= Len( h[ "todos" ] )
         h[ "planFoc" ] := "todo"
         h[ "todoSel" ] := n
         if nKey == K_LDBLCLK
            PlanEditTodo( .F. )
         endif
      endif
   endcase

return

static function ApptDialog( cTime, cText )

   local oDlg, GetList := {}, lOk := .F., lDummy

   cText := PadR( cText, 40 )   // a "" buffer would reject any typing
   oDlg := NewDlg( "Appointment", 46, 10 )
   hb_DispOutAt( oDlg:nTop + 2, oDlg:nLeft + 3, "Time (HH.MM):", "N/BG" )
   @ oDlg:nTop + 2, oDlg:nLeft + 18 GET cTime PICTURE "@S10" COLOR "N/W,N/G,N/W,R/W"
   hb_DispOutAt( oDlg:nTop + 3, oDlg:nLeft + 3, "Text:", "N/BG" )
   @ oDlg:nTop + 3, oDlg:nLeft + 18 GET cText PICTURE "@S24" COLOR "N/W,N/G,N/G,R/W"
   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON CAPTION " &OK " ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| lOk := .T., oDlg:End()}
   @ oDlg:nBottom - 2, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "N/G,W+/G,N/G,R/G" STATE {|| oDlg:End()}
   DlgActivate( oDlg, GetList )

return iif( lOk, { AllTrim( cTime ), AllTrim( cText ) }, NIL )

static procedure PlanEditAppt( lNew )

   local h := s_h, d := h[ "planDate" ]
   local aRows := PlanRows( d ), aX, aOld, cTime, cText, u, n

   if lNew
      cTime := iif( ! Empty( aRows ), aRows[ Min( h[ "apptSel" ], Len( aRows ) ) ][ 1 ], "12.00" )
      cText := ""
      aOld := NIL
   else
      if Empty( aRows )
         return
      endif
      aOld := aRows[ Min( h[ "apptSel" ], Len( aRows ) ) ]
      cTime := aOld[ 1 ]
      cText := aOld[ 2 ]
   endif
   u := ApptDialog( cTime, cText )
   if u != NIL
      aX := hb_HGetDef( h[ "appts" ], DToS( d ), {} )
      if aOld != NIL .and. aOld[ 1 ] != u[ 1 ]
         n := AScan( aX, {| x | x[ 1 ] == aOld[ 1 ] } )
         if n > 0
            ADel( aX, n )
            ASize( aX, Len( aX ) - 1 )
         endif
      endif
      n := AScan( aX, {| x | x[ 1 ] == u[ 1 ] } )
      if n > 0
         aX[ n ][ 2 ] := u[ 2 ]
      else
         AAdd( aX, { u[ 1 ], u[ 2 ] } )
      endif
      h[ "appts" ][ DToS( d ) ] := aX
      AgendaSave()
   endif

return

static procedure PlanDelAppt()

   local h := s_h, d := h[ "planDate" ]
   local aRows := PlanRows( d ), aX, a, n

   if Empty( aRows )
      return
   endif
   a := aRows[ Min( h[ "apptSel" ], Len( aRows ) ) ]
   // a stored appointment may have empty text: check existence in the
   // stored array, not the displayed text
   aX := hb_HGetDef( h[ "appts" ], DToS( d ), {} )
   n := AScan( aX, {| x | x[ 1 ] == a[ 1 ] } )
   if n == 0
      BookFlash( "No appointment at " + a[ 1 ] )
      return
   endif
   if ConfirmBox( "Delete", iif( Empty( a[ 2 ] ), "Delete the appointment at " + a[ 1 ] + "?", ;
      "Delete '" + a[ 2 ] + "' at " + a[ 1 ] + "?" ) )
      ADel( aX, n )
      ASize( aX, Len( aX ) - 1 )
      h[ "appts" ][ DToS( d ) ] := aX
      AgendaSave()
   endif

return

static procedure PlanEditTodo( lNew )

   local h := s_h, cT, n

   if lNew
      cT := AskBox( "ToDo", "New task:", "" )
      if cT != NIL .and. ! Empty( cT )
         AAdd( h[ "todos" ], cT )
         h[ "todoSel" ] := Len( h[ "todos" ] )
         AgendaSave()
      endif
   else
      if Empty( h[ "todos" ] )
         return
      endif
      n := Min( h[ "todoSel" ], Len( h[ "todos" ] ) )
      cT := AskBox( "ToDo", "Task:", h[ "todos" ][ n ] )
      if cT != NIL .and. ! Empty( cT )
         h[ "todos" ][ n ] := cT
         AgendaSave()
      endif
   endif

return

static procedure PlanDelTodo()

   local h := s_h, n

   if Empty( h[ "todos" ] )
      return
   endif
   n := Min( h[ "todoSel" ], Len( h[ "todos" ] ) )
   if ConfirmBox( "Delete", "Delete '" + h[ "todos" ][ n ] + "'?" )
      ADel( h[ "todos" ], n )
      ASize( h[ "todos" ], Len( h[ "todos" ] ) - 1 )
      h[ "todoSel" ] := Max( 1, Min( h[ "todoSel" ], Len( h[ "todos" ] ) ) )
      AgendaSave()
   endif

return

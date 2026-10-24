/*
 * mcview.prg - internal viewer (F3) and editor (F4) of the Commander
 */

#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "mc.ch"

//-----------------------------------------------------------------------------------------//

function MCViewer( cFile )

   local cText := MemoRead( cFile )

return MCViewerRun( cFile, cText )

//-----------------------------------------------------------------------------------------//

function MCViewerText( cTitle, cText )

return MCViewerRun( cTitle, cText )

//-----------------------------------------------------------------------------------------//

static function MCViewerRun( cTitle, cText )

   local aLines := hb_aTokens( StrTran( hb_defaultValue( cText, "" ), Chr( 13 ) ), Chr( 10 ) )
   local nTop := 0, nLeft := 0, nKey, lHex := .F., lWrap := .F., lEnd := .F.
   local nW := MaxCol() + 1, nRows := MaxRow() - 1, nMaxTop
   local nHexOff := 0, cSearch := "", nRow, cStatus
   local cBack := SaveScreen( 0, 0, MaxRow(), MaxCol() )

   SetCursor( SC_NONE )
   while ! lEnd
      nMaxTop := Max( 0, Len( aLines ) - nRows )
      nTop := Min( Max( nTop, 0 ), nMaxTop )
      nLeft := Max( nLeft, 0 )
      DispBegin()
      hb_Scroll( 0, 0, MaxRow(), MaxCol(), 0, 0, "N/BG", " " )
      hb_DispOutAt( 0, 0, hb_UPadR( " " + hb_UTF8SubStr( cTitle, 1, nW - 30 ) + ;
                    "  " + If( lHex, "Hex", If( lWrap, "Wrap", "Text" ) ) + ;
                    "  line " + hb_ntos( nTop + 1 ) + "/" + hb_ntos( Len( aLines ) ), nW ), "N/W" )
      if lHex
         ViewerHex( cText, nHexOff, nRows, nW )
      else
         for nRow := 1 to Min( nRows, Len( aLines ) - nTop )
            hb_DispOutAt( nRow, 0, hb_UPadR( hb_UTF8SubStr( aLines[ nTop + nRow ], nLeft + 1, ;
                          If( lWrap, nW, nW ) ), nW ), "N/BG" )
         next
      endif
      cStatus := " F3 quit  F4 hex  F2 wrap  F5 goto  F7 search  arrows scroll "
      hb_DispOutAt( MaxRow(), 0, hb_UPadR( cStatus, nW ), "N/W" )
      DispEnd()

      nKey := InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )
      do case
         case nKey == K_ESC .or. nKey == K_F10 .or. nKey == K_F3 .or. nKey == 113 // q
            lEnd := .T.
         case nKey == K_F4
            lHex := ! lHex
            if lHex
               nHexOff := 0
            endif
         case nKey == K_F2 ; lWrap := ! lWrap
         case nKey == K_UP
            if lHex ; nHexOff := Max( 0, nHexOff - 16 ) ; else ; nTop-- ; endif
         case nKey == K_DOWN
            if lHex ; nHexOff := Min( Max( 0, Len( cText ) - 16 ), nHexOff + 16 ) ; else ; nTop++ ; endif
         case nKey == K_LEFT  ; nLeft := Max( 0, nLeft - 8 )
         case nKey == K_RIGHT ; nLeft += 8
         case nKey == K_PGUP
            if lHex ; nHexOff := Max( 0, nHexOff - 16 * nRows ) ; else ; nTop -= nRows ; endif
         case nKey == K_PGDN
            if lHex ; nHexOff := Min( Max( 0, Len( cText ) - 16 ), nHexOff + 16 * nRows ) ; else ; nTop += nRows ; endif
         case nKey == K_HOME ; nTop := 0 ; nHexOff := 0
         case nKey == K_END
            nTop := nMaxTop
            nHexOff := Max( 0, ( Int( ( Len( cText ) - 1 ) / 16 ) - nRows + 1 ) * 16 )
         case nKey == K_F5
            nTop := Max( 0, ViewerGoto( Len( aLines ) ) - 1 )
            nHexOff := nTop * 16
         case nKey == K_F7
            cSearch := ViewerSearch( aLines, cSearch )
            if ! Empty( cSearch )
               n := ViewerFind( aLines, cSearch, If( lHex, 0, nTop + 1 ) )
               if n > 0
                  nTop := n - 1
               else
                  n := ViewerFind( aLines, cSearch, 0 )   // wrap
                  if n > 0
                     nTop := n - 1
                  endif
               endif
            endif
      endcase
   end

   RestScreen( 0, 0, MaxRow(), MaxCol(), cBack )

return nil

//-----------------------------------------------------------------------------------------//

static function ViewerHex( cText, nOff, nRows, nW )

   local nRow, nPos, cHex, cAsc, n

   for nRow := 1 to nRows
      nPos := nOff + ( nRow - 1 ) * 16
      if nPos >= Len( cText )
         exit
      endif
      cHex := ""
      cAsc := ""
      for n := 1 to 16
         if nPos + n <= Len( cText )
            cHex += hb_NumToHex( Asc( SubStr( cText, nPos + n, 1 ) ), 2 ) + ;
                    If( n % 4 == 0, "  ", " " )
            cAsc += If( Asc( SubStr( cText, nPos + n, 1 ) ) >= 32 .and. ;
                        Asc( SubStr( cText, nPos + n, 1 ) ) < 127, ;
                        SubStr( cText, nPos + n, 1 ), "." )
         else
            cHex += "    "
            cAsc += " "
         endif
      next
      hb_DispOutAt( nRow, 0, PadR( hb_NumToHex( nPos, 8 ) + "  " + cHex + " " + cAsc, nW ), "N/BG" )
   next

return nil

//-----------------------------------------------------------------------------------------//

static function ViewerGoto( nMax )

   local cLine := Space( 8 ), nRow := Int( MaxRow() / 2 ) - 2, nCol := Int( MaxCol() / 2 ) - 14
   local cBack := SaveScreen( nRow, nCol, nRow + 4, nCol + 28 ), GetList := {}

   hb_DispBox( nRow, nCol, nRow + 4, nCol + 28, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nRow + 1, nCol + 1, nRow + 3, nCol + 27, 0, 0, "N/W", " " )
   hb_DispOutAt( nRow + 1, nCol + 2, " Goto line (1-" + hb_ntos( nMax ) + ")", "N/W" )
   @ nRow + 2, nCol + 2 GET cLine COLOR "N/BG"
   READ
   RestScreen( nRow, nCol, nRow + 4, nCol + 28, cBack )

return Min( Max( Val( AllTrim( cLine ) ), 1 ), Max( nMax, 1 ) )

//-----------------------------------------------------------------------------------------//

static function ViewerSearch( aLines, cLast )

   local cFind := Space( 30 ), nRow := Int( MaxRow() / 2 ) - 2, nCol := Int( MaxCol() / 2 ) - 18
   local cBack := SaveScreen( nRow, nCol, nRow + 4, nCol + 36 ), GetList := {}

   cFind := PadR( cLast, 30 )
   hb_DispBox( nRow, nCol, nRow + 4, nCol + 36, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nRow + 1, nCol + 1, nRow + 3, nCol + 35, 0, 0, "N/W", " " )
   hb_DispOutAt( nRow + 1, nCol + 2, " Search for:", "N/W" )
   @ nRow + 2, nCol + 2 GET cFind COLOR "N/BG"
   READ
   RestScreen( nRow, nCol, nRow + 4, nCol + 36, cBack )

return AllTrim( cFind )

//-----------------------------------------------------------------------------------------//

static function ViewerFind( aLines, cSearch, nFrom )

   local n

   for n := nFrom + 1 to Len( aLines )
      if Lower( cSearch ) $ Lower( aLines[ n ] )
         return n
      endif
   next

return 0

//-----------------------------------------------------------------------------------------//

CLASS MCEditor FROM HBEditor

   METHOD SetFile( cFileName ) INLINE ( ::cFile := cFileName )

ENDCLASS

//-----------------------------------------------------------------------------------------//

function MCEditFile( cFile )

   local cBack := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local oEditor := MCEditor():New( "", 0, 0, MaxRow() - 1, MaxCol(), .T. )
   local nKey, lEnd := .F., nOldCursor := SetCursor( SC_NORMAL )

   hb_Scroll( 0, 0, MaxRow(), MaxCol(), 0, 0, "W/B", " " )

   if hb_FileExists( cFile )
      oEditor:LoadFile( cFile )
   else
      oEditor:SetFile( cFile )
   endif
   oEditor:SetColor( "W/B,N/BG" )
   oEditor:Display()

   while ! lEnd
      hb_DispOutAt( MaxRow(), 0, hb_UPadR( " F2 save  F10/Esc quit  " + cFile + ;
                    If( oEditor:Changed(), " [modified]", "" ), MaxCol() + 1 ), "N/W" )
      nKey := InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )
      do case
         case nKey == K_F2
            oEditor:SaveFile()
         case nKey == K_F10 .or. nKey == K_ESC
            if oEditor:Changed()
               if DlgConfirmS( "File modified. Save before quitting?" )
                  oEditor:SaveFile()
                  lEnd := .T.
               elseif DlgConfirmS( "Quit without saving?" )
                  lEnd := .T.
               endif
            else
               lEnd := .T.
            endif
         otherwise
            oEditor:Edit( nKey )
            SetCursor( SC_NORMAL )
            SetPos( oEditor:RowPos(), oEditor:ColPos() )
      endcase
   end

   SetCursor( nOldCursor )
   RestScreen( 0, 0, MaxRow(), MaxCol(), cBack )

return nil

//-----------------------------------------------------------------------------------------//

static function DlgConfirmS( cMsg )

   local nRow := Int( MaxRow() / 2 ) - 2, nCol := Int( MaxCol() / 2 ) - 20
   local cBack := SaveScreen( nRow, nCol, nRow + 4, nCol + 40 ), nKey, lRet := .F.

   hb_DispBox( nRow, nCol, nRow + 4, nCol + 40, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nRow + 1, nCol + 1, nRow + 3, nCol + 39, 0, 0, "N/W", " " )
   hb_DispOutAt( nRow + 2, nCol + 2, hb_UPadR( cMsg, 38 ), "N/W" )
   hb_DispOutAt( nRow + 3, nCol + 2, "Y = yes, N = no", "N/W" )
   while .T.
      nKey := InKey( 0 )
      if nKey == Asc( "y" ) .or. nKey == Asc( "Y" )
         lRet := .T.
         exit
      elseif nKey == Asc( "n" ) .or. nKey == Asc( "N" ) .or. nKey == K_ESC
         exit
      endif
   end
   RestScreen( nRow, nCol, nRow + 4, nCol + 40, cBack )

return lRet

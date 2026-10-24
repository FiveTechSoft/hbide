// mcbutton.prg - vendored copy of ../hbbutton.prg for the MC demo.
// The original is shared with the IDE (sibling lanes) and stays untouched.
// Only change: CP437 glyph bytes (Chr(255)/Chr(220)/Chr(223)) replaced by
// their UTF-8 literals, because the demo runs on the UTF-8 codepage.
// If ../hbbutton.prg changes, re-vendor this file.

function BtnDisplay()

   local Self := QSelf()

   LOCAL cColor
   // UTF-8 glyphs built at runtime: source literals get recoded by the
   // compiler, these are the exact bytes (U+2584/U+2580) that render.
   LOCAL cHalfDn := hb_BChar( 0xE2 ) + hb_BChar( 0x96 ) + hb_BChar( 0x84 )
   LOCAL cHalfUp := hb_BChar( 0xE2 ) + hb_BChar( 0x96 ) + hb_BChar( 0x80 )
   LOCAL cStyle := "  " // ::cStyle
   LOCAL cCaption := ::cCaption
   LOCAL nRow := ::nRow
   LOCAL nCol := ::nCol
   LOCAL nPos

   DispBegin()

   DO CASE
   CASE ::lBuffer
      cColor := hb_ColorIndex( ::cColorSpec, 2 )
   CASE ::lHasFocus
      cColor := hb_ColorIndex( ::cColorSpec, 1 )
   OTHERWISE
      cColor := hb_ColorIndex( ::cColorSpec, 0 )
   ENDCASE

   IF ( nPos := At( "&", cCaption ) ) == 0
   ELSEIF nPos == Len( cCaption )
      nPos := 0
   ELSE
      cCaption := Stuff( cCaption, nPos, 1, "" )
   ENDIF

   IF ! Empty( cStyle )

      nCol++

      IF Len( cStyle ) == 2
         if ::lBuffer
            hb_DispOutAt( ::nRow, ::nCol, " ", "N/W" )
         endif   
         hb_DispOutAt( ::nRow, ::nCol + If( ::lBuffer, 1, 0 ), SubStr( cStyle, 1, 1 ), cColor )
         hb_DispOutAt( ::nRow, ::nCol + Len( cCaption ) + 1 + If( ::lBuffer, 1, 0 ), SubStr( cStyle, 2, 1 ), cColor )
      ELSE
         nRow++
         hb_DispBox( ::nRow, ::nCol + If( ::lBuffer, 1, 0 ), ::nRow + 2, ::nCol + Len( cCaption ) + 1, cStyle, cColor )
      ENDIF
   ENDIF

   IF ! Empty( cCaption )

      hb_DispOutAt( nRow, nCol + If( ::lBuffer, 1, 0 ), cCaption, cColor )

      IF nPos != 0
         hb_DispOutAt( nRow, nCol + nPos - 1 + If( ::lBuffer, 1, 0 ),;
                       SubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )
      ENDIF
   ENDIF

   hb_DispOutAt( nRow, ::nCol + Len( cCaption ) + 2 + If( ::lBuffer, 1, 0 ),;
                 If( ::lBuffer, " ", cHalfDn ), "N/W" )
   hb_DispOutAt( ::nRow + 1, ::nCol + 1,;
                 Replicate( If( ::lBuffer, " ", cHalfUp ), Len( cCaption ) + 2 ), "N/W" )

   DispEnd()

   RETURN Self

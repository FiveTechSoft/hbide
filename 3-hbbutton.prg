function BtnDisplay()

   local Self := QSelf()

   LOCAL cColor
   LOCAL cStyle := Chr( 255 )+ Chr( 255 ) // ::cStyle
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
                 If( ::lBuffer, " ", HbBtnShadowChars()[ 1 ] ), "N/W" )
   hb_DispOutAt( ::nRow + 1, ::nCol + 1,;
                 Replicate( If( ::lBuffer, " ", HbBtnShadowChars()[ 2 ] ), Len( cCaption ) + 2 ), "N/W" )

   DispEnd()

   RETURN Self

// Shadow glyphs follow the application's active codepage (same pattern as
// HBWindow's DrawBorder): under CP437 they are the raw half blocks 220/223,
// byte-identical to before; under the UTF-8 opt-in they become the proper
// multi-byte encoding instead of rendering as '?'.
function HbBtnShadowChars()

return { hb_UTF8ToStr( "▄" ), hb_UTF8ToStr( "▀" ) }

// Registers the hbide PushButton display (with its 3D shadow) for any
// program that links this file, including designer-generated dialogs
// compiled standalone. hbide.prg applies the same patch for the IDE;
// repeating __ClsModMsg with the same method is harmless.
INIT PROCEDURE BtnPatch()

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )

return

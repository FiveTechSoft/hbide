function BtnDisplay()

   local Self := QSelf()

   LOCAL cColor
   LOCAL cStyle := HbBtnPadChars()   // CP-aware caption pads (CP437: two Chr(255))
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

      if ::lBuffer
         hb_DispOutAt( ::nRow, ::nCol, " ", "N/W" )
      endif
      hb_DispOutAt( ::nRow, ::nCol + If( ::lBuffer, 1, 0 ), cStyle[ 1 ], cColor )
      hb_DispOutAt( ::nRow, ::nCol + Len( cCaption ) + 1 + If( ::lBuffer, 1, 0 ), cStyle[ 2 ], cColor )
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

// the two pads flanking the caption: U+00A0 (CP437 255) converted for the active
// codepage, so under the UTF-8 opt-in they stay valid instead of rendering as ?
function HbBtnPadChars()

return { hb_UTF8ToStr( " " ), hb_UTF8ToStr( " " ) }

// Registers the hbide PushButton display (with its 3D shadow) for any
// program that links this file, including designer-generated dialogs
// compiled standalone. hbide.prg applies the same patch for the IDE;
// repeating __ClsModMsg with the same method is harmless.
INIT PROCEDURE BtnPatch()

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )

return

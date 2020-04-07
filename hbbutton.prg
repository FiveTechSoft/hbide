function BtnDisplay()

   local Self := QSelf()

   LOCAL cColor
   LOCAL cStyle := ::cStyle
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
                 If( ::lBuffer, " ", Chr( 220 ) ), "N/W" )
   hb_DispOutAt( ::nRow + 1, ::nCol + 1,;
                 Replicate( If( ::lBuffer, " ", Chr( 223 ) ), Len( cCaption ) + 2 ), "N/W" )

   DispEnd()

   RETURN Self

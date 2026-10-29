function BtnDisplay()

   local Self := QSelf()

   LOCAL cColor
   LOCAL aPads := HbBtnPadChars()   // CP-aware caption pads (CP437: two Chr(255))
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

   IF ( nPos := hb_UAt( "&", cCaption ) ) == 0
   ELSEIF nPos == hb_ULen( cCaption )
      nPos := 0
   ELSE
      cCaption := hb_ULeft( cCaption, nPos - 1 ) + hb_USubStr( cCaption, nPos + 1 )
   ENDIF

   IF Len( ::cStyle ) == 2 .AND. ::cStyle != "<>"

      // bracket look (STYLE "[]" etc.): one row, no shadow
      hb_DispOutAt( ::nRow, ::nCol, ;
         hb_ULeft( ::cStyle, 1 ) + " " + cCaption + " " + hb_USubStr( ::cStyle, 2, 1 ), cColor )
      IF nPos != 0
         hb_DispOutAt( ::nRow, ::nCol + nPos + 1, ;
            hb_USubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )
      ENDIF

      DispEnd()

      RETURN Self
   ENDIF

   IF ! Empty( aPads )

      nCol++

      if ::lBuffer
         hb_DispOutAt( ::nRow, ::nCol, " ", "N/W" )
      endif
      hb_DispOutAt( ::nRow, ::nCol + If( ::lBuffer, 1, 0 ), aPads[ 1 ], cColor )
      hb_DispOutAt( ::nRow, ::nCol + hb_ULen( cCaption ) + 1 + If( ::lBuffer, 1, 0 ), aPads[ 2 ], cColor )
   ENDIF

   IF ! Empty( cCaption )

      hb_DispOutAt( nRow, nCol + If( ::lBuffer, 1, 0 ), cCaption, cColor )

      IF nPos != 0
         hb_DispOutAt( nRow, nCol + nPos - 1 + If( ::lBuffer, 1, 0 ),;
                       hb_USubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )
      ENDIF
   ENDIF

   hb_DispOutAt( nRow, ::nCol + hb_ULen( cCaption ) + 2 + If( ::lBuffer, 1, 0 ),;
                 " ", If( ::lBuffer, "N/W", "N/N" ) )
   hb_DispOutAt( ::nRow + 1, ::nCol + 1,;
                 Replicate( " ", hb_ULen( cCaption ) + 2 ), If( ::lBuffer, "N/W", "N/N" ) )

   DispEnd()

   RETURN Self

// Button shadow: solid dark cells (plain spaces with a black-on-black color).
// Half-block glyphs (U+2584/U+2580) have no ACSC fallback in Harbour's gttrm
// charmap, so on non-UTF8 terminals they rendered as literal '?'. Solid cells
// are codepage-independent, match the classic Turbo Vision button shadow and
// look identical on GTWVT and on UTF-8 and non-UTF8 terminals alike.

// the two pads flanking the caption: plain ASCII spaces. They used to be
// U+00A0 (CP437 255), but gttrm's charmap has no mapping for byte 255 on
// non-UTF8 terminals, so the pads rendered as '?'. A space painted with the
// button face color is visually identical everywhere.
function HbBtnPadChars()

return { " ", " " }

// The stock hitTest covers caption + 2 cells for a two-char style, but the
// bracket look paints "[ Caption ]" (caption + 4 cells): the trailing
// " ]" would be dead clicks. Cover the real painted extent here; the
// shadow column of the 3D look stays decorative (not clickable).
function BtnHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nLen := hb_ULen( ::cCaption )
   local nAccelPos

   if ( nAccelPos := hb_UAt( "&", ::cCaption ) ) > 0 .and. nAccelPos < nLen
      nLen--
   endif
   if Len( ::cStyle ) == 2 .and. ::cStyle != "<>"
      nLen += 4   // "[ " + caption + " ]"
   else
      nLen += 2   // stock extent: pads around the caption
   endif

   if nMRow >= ::Row .and. nMCol >= ::Col .and. ;
      nMRow < ::Row + 1 .and. nMCol < ::Col + nLen
      return -2049   // HTCLIENT
   endif

return 0   // HTNOWHERE

// Registers the hbide PushButton display (with its 3D shadow) for any
// program that links this file, including designer-generated dialogs
// compiled standalone. hbide.prg applies the same patch for the IDE;
// repeating __ClsModMsg with the same method is harmless.
INIT PROCEDURE BtnPatch()

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )
   __ClsModMsg( PushButton( 0, 0 ):ClassH, "HITTEST", @BtnHitTest() )

return

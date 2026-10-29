static s_cBtnShadowColor := "N/W"

// Shadow/clear color for the 3D look. Default "N/W" suits grey bodies;
// dialogs with another body color set theirs around Activate and restore.
function HBBtnShadowColor( cNew )

   local cPrev := s_cBtnShadowColor

   if PCount() > 0 .and. HB_ISSTRING( cNew )
      s_cBtnShadowColor := cNew
   endif

return cPrev

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
         hb_DispOutAt( ::nRow, ::nCol, "  ", "N/W" )
      endif
      hb_DispOutAt( ::nRow, ::nCol + 1 + If( ::lBuffer, 1, 0 ), aPads[ 1 ], cColor )
      hb_DispOutAt( ::nRow, ::nCol + hb_ULen( cCaption ) + 2 + If( ::lBuffer, 1, 0 ), aPads[ 2 ], cColor )
   ENDIF

   IF ! Empty( cCaption )

      hb_DispOutAt( nRow, nCol + 1 + If( ::lBuffer, 1, 0 ), cCaption, cColor )

      IF nPos != 0
         hb_DispOutAt( nRow, nCol + nPos + If( ::lBuffer, 1, 0 ),;
                       hb_USubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )
      ENDIF
   ENDIF

   // The face sits one cell right of ::nCol: the left inset and the
   // lower-left cells keep the dialog color (the invisible half of the
   // classic Turbo Vision shadow). Clear the stripe row first so switching
   // between the normal and pressed (lBuffer) states leaves no stray cells.
   hb_DispOutAt( ::nRow + 1, ::nCol + 1, Replicate( " ", hb_ULen( cCaption ) + 4 ), s_cBtnShadowColor )
   IF HBBtnShadowUtf8()
      // Turbo Vision half-cell shadow: the cell right of the face keeps the
      // dialog color on its upper half and shows the shadow on its lower
      // half; the stripe below shows the shadow on its upper half, shifted
      // one cell right. Half the thickness of a solid-cell shadow: the
      // classic TV button look (same as demos/calculator.prg CalcBtnShadow).
      hb_DispOutAt( nRow, ::nCol + hb_ULen( cCaption ) + 3 + If( ::lBuffer, 1, 0 ),;
                    hb_UTF8ToStr( "▄" ), s_cBtnShadowColor )
      hb_DispOutAt( ::nRow + 1, ::nCol + 2 + If( ::lBuffer, 1, 0 ),;
                    Replicate( hb_UTF8ToStr( "▀" ), hb_ULen( cCaption ) + 2 ), s_cBtnShadowColor )
   ELSE
      // codepage-safe fallback: solid dark cells (gttrm's ACSC charmap has
      // no mapping for the half blocks on non-UTF8 terminals: they print '?')
      hb_DispOutAt( nRow, ::nCol + hb_ULen( cCaption ) + 3 + If( ::lBuffer, 1, 0 ),;
                    " ", "N/N" )
      hb_DispOutAt( ::nRow + 1, ::nCol + 2 + If( ::lBuffer, 1, 0 ),;
                    Replicate( " ", hb_ULen( cCaption ) + 2 ), "N/N" )
   ENDIF

   DispEnd()

   RETURN Self

// Button shadow: the classic Turbo Vision look is a half-cell shadow drawn
// with half-block glyphs (U+2584 right of the face, U+2580 stripe below) in a
// black-on-dialog-color attribute, so the unpainted halves blend into the
// dialog. GTWVT and UTF-8 terminals render those glyphs directly; on a
// non-UTF8 POSIX terminal gttrm's ACSC charmap has no mapping for them (they
// print '?'), so there BtnDisplay falls back to solid dark cells.

// .T. when the terminal can render the half-block shadow glyphs: the
// Windows GTs (GTWVT) take them natively; on POSIX they only survive a
// UTF-8 locale. Kept local to this file because hbbutton.prg is also linked
// standalone into designer-generated dialogs (no hbide.prg there).
function HBBtnShadowUtf8()

   local cLoc := "", cName

   if "WINDOWS" $ Upper( OS() )
      return .T.
   endif
   for each cName in { "LC_ALL", "LC_CTYPE", "LANG" }
      cLoc := GetEnv( cName )
      if ! Empty( cLoc )
         exit
      endif
   next
   cLoc := Upper( cLoc )

return "UTF-8" $ cLoc .or. "UTF8" $ cLoc

// the two pads flanking the caption: plain ASCII spaces. They used to be
// U+00A0 (CP437 255), but gttrm's charmap has no mapping for byte 255 on
// non-UTF8 terminals, so the pads rendered as '?'. A space painted with the
// button face color is visually identical everywhere.
function HbBtnPadChars()

return { " ", " " }

// The stock hitTest covers caption + 2 cells for a two-char style, but the
// bracket look paints "[ Caption ]" (caption + 4 cells): the trailing
// " ]" would be dead clicks. Cover the real painted extent here; the
// left inset cell and the shadow column of the 3D look stay decorative
// (not clickable).
function BtnHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nLen := hb_ULen( ::cCaption )
   local nAccelPos
   local nOff := 0

   if ( nAccelPos := hb_UAt( "&", ::cCaption ) ) > 0 .and. nAccelPos < nLen
      nLen--
   endif
   if Len( ::cStyle ) == 2 .and. ::cStyle != "<>"
      nLen += 4   // "[ " + caption + " ]"
   else
      nLen += 2   // pads around the caption
      nOff := 1   // the 3D face starts one cell right of ::Col (left inset)
   endif

   if nMRow >= ::Row .and. nMCol >= ::Col + nOff .and. ;
      nMRow < ::Row + 1 .and. nMCol < ::Col + nLen + nOff
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

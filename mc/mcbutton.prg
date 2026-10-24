// mcbutton.prg - vendored control displays for the MC demo (pushbuttons and
// checkboxes). The shared originals (../hbbutton.prg, Harbour RTL CheckBox)
// stay untouched for the IDE lanes.
//
// Button style contract (aligned with the designer's per-button "style"
// property, relayed via main on 2026-10-24):
//   oBtn:style == "brackets" -> Midnight Commander text buttons
//      "[ Caption ]" drawn on the dialog background: width = caption + 4,
//      height 1, no per-button shadow.
//   anything else ("shadow", "<>", any 2-char pair) -> hbide block button:
//      colored face with the pair chars as caps (spaces when not a 2-char
//      pair) and a solid shadow one cell right and one row down (height 2).
// A button whose cargo is .T. is the dialog default and renders as
// "[< Caption >]" in the brackets style (mc's DEFPUSH_BUTTON).
// Colors: the body honors ::cColorSpec indices 0/1/2 (normal/focus/buffer);
// the hotkey letter is derived per state (red on the normal background,
// bright yellow on the focus background) because the RTL single hotkey
// slot cannot be right in both states.

function BtnDisplay()

   local Self := QSelf()

   LOCAL cBody, cHot, cBg
   LOCAL cCaption := ::cCaption
   LOCAL nPos, cOut, nW
   LOCAL lBrackets := ( ::cStyle == "brackets" )
   LOCAL lDefault  := ( ::cargo == .T. )

   DispBegin()

   DO CASE
   CASE ::lBuffer
      cBody := hb_ColorIndex( ::cColorSpec, 2 )
   CASE ::lHasFocus
      cBody := hb_ColorIndex( ::cColorSpec, 1 )
   OTHERWISE
      cBody := hb_ColorIndex( ::cColorSpec, 0 )
   ENDCASE
   cBg  := SubStr( cBody, At( "/", cBody ) + 1 )
   cHot := If( ::lHasFocus .or. ::lBuffer, "GR+/" + cBg, ;
               If( Empty( hb_ColorIndex( ::cColorSpec, 3 ) ), "R/" + cBg, hb_ColorIndex( ::cColorSpec, 3 ) ) )

   cCaption := AllTrim( cCaption )
   IF ( nPos := At( "&", cCaption ) ) == 0
   ELSEIF nPos == Len( cCaption )
      nPos := 0
   ELSE
      cCaption := Stuff( cCaption, nPos, 1, "" )
   ENDIF

   IF lBrackets
      cOut := If( lDefault, "[< ", "[ " ) + cCaption + If( lDefault, " >]", " ]" )
      hb_DispOutAt( ::nRow, ::nCol, cOut, cBody )
      IF nPos != 0
         hb_DispOutAt( ::nRow, ::nCol + nPos + If( lDefault, 3, 2 ) - 1,;
            SubStr( cCaption, nPos, 1 ), cHot )
      ENDIF
   ELSE
      nW := Len( cCaption ) + 2
      hb_DispOutAt( ::nRow, ::nCol,;
         If( Len( ::cStyle ) == 2, SubStr( ::cStyle, 1, 1 ), " " ) + " " + ;
         cCaption + " " + ;
         If( Len( ::cStyle ) == 2, SubStr( ::cStyle, 2, 1 ), " " ), cBody )
      IF nPos != 0
         hb_DispOutAt( ::nRow, ::nCol + nPos + 1, SubStr( cCaption, nPos, 1 ), cHot )
      ENDIF
      hb_DispOutAt( ::nRow, ::nCol + nW + 2, " ", If( ::lBuffer, "N/W", "N/N" ) )
      hb_DispOutAt( ::nRow + 1, ::nCol + 2, Space( nW + 1 ),;
         If( ::lBuffer, "N/W", "N/N" ) )
   ENDIF

   DispEnd()

   RETURN Self

// Checkbox display, MC look: unfocused caption in the dialog normal color
// with a red hotkey; focused caption in the focus color (black on cyan in
// the demo dialogs) with a bright yellow hotkey. The RTL display reuses one
// color slot for the focused caption AND the unfocused hotkey, which cannot
// be right in both states at once.

function ChkDisplay()

   local Self := QSelf()

   LOCAL cGlyph, cFrame, cCap, cHot, cBg
   LOCAL cStyle := ::cStyle, cCaption := ::cCaption
   LOCAL nPos

   DispBegin()

   cGlyph := hb_ColorIndex( ::cColorSpec, If( ::lHasFocus, 1, 0 ) )
   cFrame := hb_ColorIndex( ::cColorSpec, 2 )
   cCap   := hb_ColorIndex( ::cColorSpec, If( ::lHasFocus, 1, 2 ) )
   cBg    := SubStr( cCap, At( "/", cCap ) + 1 )
   cHot   := If( ::lHasFocus, "GR+/" + cBg, ;
                 If( Empty( hb_ColorIndex( ::cColorSpec, 3 ) ), "R/" + cBg, hb_ColorIndex( ::cColorSpec, 3 ) ) )

   hb_DispOutAt( ::nRow, ::nCol + 1,;
      If( ::lBuffer, SubStr( cStyle, 2, 1 ), SubStr( cStyle, 3, 1 ) ), cGlyph )
   hb_DispOutAt( ::nRow, ::nCol, Left( cStyle, 1 ), cFrame )
   hb_DispOutAt( ::nRow, ::nCol + 2, Right( cStyle, 1 ), cFrame )

   IF ! Empty( cCaption )
      IF ( nPos := At( "&", cCaption ) ) == 0
      ELSEIF nPos == Len( cCaption )
         nPos := 0
      ELSE
         cCaption := Stuff( cCaption, nPos, 1, "" )
      ENDIF
      hb_DispOutAt( ::nCapRow, ::nCapCol, cCaption, cCap )
      IF nPos != 0
         hb_DispOutAt( ::nCapRow, ::nCapCol + nPos - 1,;
            SubStr( cCaption, nPos, 1 ), cHot )
      ENDIF
   ENDIF

   DispEnd()

   RETURN Self

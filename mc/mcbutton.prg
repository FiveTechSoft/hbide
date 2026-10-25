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
//      colored face with a solid shadow one cell right and one row down
//      (height 2). Caps are the pair chars for an explicit custom pair; the
//      RTL "<>" default paints clean spaces (plain label, user 2026-10-25).
// A button whose cargo is .T. is the dialog default and renders as
// "[< Caption >]" in the brackets style (mc's DEFPUSH_BUTTON).
// Colors: the body honors ::cColorSpec indices 0/1/2 (normal/focus/buffer);
// the hotkey letter is derived per state (red on the normal background,
// bright yellow on the focus background) because the RTL single hotkey
// slot cannot be right in both states.

#include "button.ch"

function BtnDisplay()

   local Self := QSelf()

   LOCAL cBody, cHot, cBg, cCaps
   LOCAL cCaption := ::cCaption
   LOCAL nPos, cOut, nW
   // designer codegen emits STYLE "[]" for brackets; "brackets" kept as legacy alias
   LOCAL lBrackets := ( ::cStyle == "[]" .or. ::cStyle == "brackets" )
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

   // Padding is significant for the shadow style (it sets the face width);
   // only the brackets style trims, adjusting the hotkey offset accordingly.
   IF ( nPos := At( "&", cCaption ) ) == 0
   ELSEIF nPos == Len( cCaption )
      nPos := 0
   ELSE
      cCaption := Stuff( cCaption, nPos, 1, "" )
   ENDIF

   IF lBrackets
      IF nPos != 0
         nPos -= Len( cCaption ) - Len( LTrim( cCaption ) )
      ENDIF
      cCaption := AllTrim( cCaption )
      cOut := If( lDefault, "[< ", "[ " ) + cCaption + If( lDefault, " >]", " ]" )
      hb_DispOutAt( ::nRow, ::nCol, cOut, cBody )
      IF nPos != 0
         hb_DispOutAt( ::nRow, ::nCol + nPos + If( lDefault, 3, 2 ) - 1,;
            SubStr( cCaption, nPos, 1 ), cHot )
      ENDIF
   ELSE
      // "<>" is only the RTL default (no explicit STYLE): paint clean caps.
      // User, 2026-10-25: shadow buttons show a plain label, no < > or [].
      // Face width keeps the caption's own padding (CAPTION "  &OK  "): the
      // original AllTrim shrank short buttons until the shadow slab was as
      // wide as the face ("black blocks", user 2026-10-25). The shadow is
      // the hbide half-block strip (Chr(220)/Chr(223), ../hbbutton.prg):
      // half a cell tall/deep, displaced one right and one down, not the
      // full-cell N/N slabs that read as thick blocks under each button.
      cCaps := If( Len( ::cStyle ) == 2 .and. ! ::cStyle == "<>", ::cStyle, "  " )
      nW := Len( cCaption )
      IF ::lBuffer
         hb_DispOutAt( ::nRow, ::nCol, " ", "N/W" )
      ENDIF
      hb_DispOutAt( ::nRow, ::nCol + If( ::lBuffer, 1, 0 ),;
         SubStr( cCaps, 1, 1 ) + ;
         cCaption + ;
         SubStr( cCaps, 2, 1 ), cBody )
      IF nPos != 0
         hb_DispOutAt( ::nRow, ::nCol + nPos + If( ::lBuffer, 1, 0 ),;
            SubStr( cCaption, nPos, 1 ), cHot )
      ENDIF
      // hbide half-block shadow (../hbbutton.prg): U+2584 at the right edge
      // and a U+2580 strip one row down, painted with fg=black bg=dialog so
      // only HALF of each shadow cell is dark. Requires the terminal in
      // UTF-8 mode: gttrm decides that from its DSR probe (hb_trm_isUTF8),
      // which xterm.js answers correctly; a dumb PTY that answers the probe
      // with the wrong column renders '?' instead (test-harness caveat, not
      // an app defect).
      hb_DispOutAt( ::nRow, ::nCol + nW + 2,;
         If( ::lBuffer, " ", "▄" ), "N/W" )
      hb_DispOutAt( ::nRow + 1, ::nCol + 1,;
         Replicate( If( ::lBuffer, " ", "▀" ), nW + 2 ), "N/W" )
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

//-----------------------------------------------------------------------------------------//

// hit test honoring the rendered sizes: brackets "[ text ]" = caption + 4,
// "[< text >]" = caption + 6, block buttons = caption + 4 x 2 rows
function BtnHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nLen := hb_ULen( StrTran( ::cCaption, "&", "" ) )
   local nH := 1

   if ::cStyle == "[]" .or. ::cStyle == "brackets"
      nLen += 4
      if ::cargo == .T.
         nLen += 2   // "[< >]" default marker
      endif
   else
      nLen += 2      // clickable face; the shadow cell is painted, not clickable
      nH := 2
   endif

   if nMRow >= ::nRow .and. nMRow < ::nRow + nH .and. ;
      nMCol >= ::nCol .and. nMCol < ::nCol + nLen
      return HTCLIENT
   endif

return HTNOWHERE

//-----------------------------------------------------------------------------------------//

// RadioButtn display, mc style: the FOCUSED item draws glyph + caption in
// black-on-cyan, other items black-on-gray; the hotkey is red unfocused and
// yellow on the focused row.  colorSpec contract (vendored): index 4 caption
// normal, index 5 hotkey normal, index 6 focused body.
function RadDisplay()

   local Self := QSelf()
   local cStyle, cColor, cKeyColor, nPos, nCapRow, nCapCol
   local lCurrent

   cStyle := Left( ::cStyle, 1 ) + If( ::lBuffer, SubStr( ::cStyle, 2, 1 ), " " ) + SubStr( ::cStyle, 3 )

   // RadioGroup:setFocus() marks EVERY item focused; the current row is the
   // selected one (lBuffer), like mc: that row goes black-on-cyan, the rest
   // stay black-on-gray.
   lCurrent := ( ::lHasFocus .and. ::lBuffer )

   cColor := If( lCurrent, ;
                 hb_ColorIndex( ::colorSpec, 6 ), ;
                 hb_ColorIndex( ::colorSpec, 4 ) )
   cKeyColor := If( lCurrent, ;
                    "GR+/" + SubStr( cColor, At( "/", cColor ) + 1 ), ;
                    hb_ColorIndex( ::colorSpec, 5 ) )

   hb_DispOutAt( ::nRow, ::nCol, cStyle, cColor )

   if ! Empty( ::cCaption )
      nCapRow := If( ! Empty( ::capRow ) .and. ! Empty( ::capCol ), ::capRow, ::nRow )
      nCapCol := If( ! Empty( ::capRow ) .and. ! Empty( ::capCol ), ::capCol, ::nCol + Len( cStyle ) + 1 )
      // paint the caption without "&" and recolor the hotkey letter in place
      // (nPos keeps the pre-strip index, which equals the painted offset)
      nPos := At( "&", ::cCaption )
      hb_DispOutAt( nCapRow, nCapCol, StrTran( ::cCaption, "&", "" ), cColor )
      if nPos > 0
         hb_DispOutAt( nCapRow, nCapCol + nPos - 1, SubStr( ::cCaption, nPos + 1, 1 ), cKeyColor )
      endif
   endif

return nil

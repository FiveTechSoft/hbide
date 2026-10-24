// mcbutton.prg - vendored copy of ../hbbutton.prg for the MC demo.
// The original is shared with the IDE (sibling lanes) and stays untouched.
// Look: authentic Midnight Commander buttons - "[ Caption ]" text buttons
// drawn directly on the dialog background (no solid blocks, no per-button
// shadow): unfocused black-on-dialog-gray with a red hotkey letter,
// focused black-on-cyan with a yellow hotkey letter. Reference:
// mc's lib/widget/button.c (NORMAL_BUTTON draws "[ " + text + " ]").
// If ../hbbutton.prg changes, re-vendor this file.

function BtnDisplay()

   local Self := QSelf()

   LOCAL cBody, cHot
   LOCAL cCaption := ::cCaption
   LOCAL nPos, cOut

   DispBegin()

   IF ::lHasFocus .or. ::lBuffer
      cBody := "N/BG"   // black on cyan
      cHot  := "GR+/BG" // yellow hotkey
   ELSE
      cBody := "N/W"    // black on the dialog background gray
      cHot  := "R/W"    // red hotkey
   ENDIF

   cCaption := AllTrim( cCaption )
   IF ( nPos := At( "&", cCaption ) ) == 0
   ELSEIF nPos == Len( cCaption )
      nPos := 0
   ELSE
      cCaption := Stuff( cCaption, nPos, 1, "" )
   ENDIF

   cOut := "[ " + cCaption + " ]"
   hb_DispOutAt( ::nRow, ::nCol, cOut, cBody )
   IF nPos != 0
      hb_DispOutAt( ::nRow, ::nCol + nPos + 1, SubStr( cCaption, nPos, 1 ), cHot )
   ENDIF

   DispEnd()

   RETURN Self

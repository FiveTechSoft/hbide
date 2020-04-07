#include "hbclass.ch"
#include "box.ch"

//-----------------------------------------------------------------------------------------//

CLASS HbMenu FROM HBDbMenu

   METHOD LoadColors()

   METHOD Display()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD LoadColors() CLASS HbMenu

   local aColors := { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" } 
   local oMenuItem

   ::cClrPopup    := aColors[  8 ]
   ::cClrHotKey   := aColors[  9 ]
   ::cClrHilite   := aColors[ 10 ]
   ::cClrHotFocus := aColors[ 11 ]

   for each oMenuItem in ::aItems
      if HB_ISOBJECT( oMenuItem:bAction )
         oMenuItem:bAction:LoadColors()
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD Display() CLASS HbMenu
   
   local oMenuItem

   if ::lPopup
      ::cBackImage := __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2 )
      hb_DispBox( ::nTop, ::nLeft, ::nBottom, ::nRight, HB_B_SINGLE_UNI, ::cClrPopup )
      hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
   else
      hb_DispOutAt( 0, 0, Space( MaxCol() + 1 ), ::cClrPopup )
   endif

   FOR EACH oMenuItem IN ::aItems
      IF oMenuItem:cPrompt == "-"  // Separator
         hb_DispOutAtBox( oMenuItem:nRow, ::nLeft, ;
            hb_UTF8ToStrBox( "├" + Replicate( "─", ::nRight - ::nLeft - 1 ) + "┤" ), ::cClrPopup )
      ELSE
         oMenuItem:Display( ::cClrPopup, ::cClrHotKey )
      ENDIF
   NEXT

return nil

//-----------------------------------------------------------------------------------------//
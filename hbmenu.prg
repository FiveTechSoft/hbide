#include "hbclass.ch"

CLASS HbMenu FROM HBDbMenu

   METHOD LoadColors()

ENDCLASS

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

#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"

#xcommand MENU [<oMenu>] => [ <oMenu> := ] HBMenu():New()
#xcommand MENUITEM [ <oMenuItem> PROMPT ] <cPrompt> ;
          [ IDENT <nIdent> ] [ ACTION <uAction,...> ] ;
          [ CHECKED <bChecked> ] => ;
   [ <oMenuItem> := ] HBMenu():AddItem( HBDbMenuItem():New( <cPrompt>, ;
   [{|| <uAction> }], [<bChecked>], [<nIdent>] ) )
#xcommand SEPARATOR => HBMenu():AddItem( HBDbMenuItem():New( "-" ) )
#xcommand ENDMENU => ATail( HBMenu():aMenus ):Build()

//-----------------------------------------------------------------------------------------//

function Main()

   local cBack := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local oMenu := BuildMenu()

   SetCursor( SC_NONE )
   SET COLOR TO "W/B"
   CLEAR SCREEN
   
   oMenu:Display()
   oMenu:ShowPopup( 1 )

   while ( nKey := Inkey( 0, INKEY_ALL ) ) != K_ESC
      oMenu:ProcessKey( nKey )
   end

   RestScreen( cBack, 0, 0, MaxRow(), MaxCol() )

return nil

//-----------------------------------------------------------------------------------------//

CREATE CLASS HbMenu FROM HBDbMenu

   METHOD LoadColors()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD LoadColors() CLASS HbMenu
   
   // LOCAL aColors := __dbgColors()
   LOCAL oMenuItem

   ::cClrPopup    := "N/W"   // aColors[  8 ]
   ::cClrHotKey   := "R+/W"  // aColors[  9 ]
   ::cClrHilite   := "N/BG"  // aColors[ 10 ]
   ::cClrHotFocus := "R+/BG" // aColors[ 11 ]

   FOR EACH oMenuItem IN ::aItems
      IF HB_ISOBJECT( oMenuItem:bAction )
         oMenuItem:bAction:LoadColors()
      ENDIF
   NEXT

RETURN

//-----------------------------------------------------------------------------------------//

FUNCTION BuildMenu()

   LOCAL oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~New"              ACTION Alert( "new" )
         MENUITEM "~Open..."          ACTION Alert( "open" )
         MENUITEM "~Save"             ACTION Alert( "save" )
         MENUITEM "Save ~As... "      ACTION Alert( "saveas" )
         SEPARATOR
         MENUITEM "E~xit"             ACTION __Quit()
      ENDMENU

      MENUITEM " ~Edit "
      MENU
         MENUITEM "~Copy "
         MENUITEM "~Paste "
         SEPARATOR
         MENUITEM "~Find... "
         MENUITEM "~Repeat Last Find  F3 "
         MENUITEM "~Change..."   
      ENDMENU

      MENUITEM " ~Run "
      MENU
         MENUITEM "~Start "
         MENUITEM "S~cript "
         MENUITEM "~Debug "   
      ENDMENU

      MENUITEM " ~Options "
      MENU
         MENUITEM "~Compiler Flags... "
         MENUITEM "~Display... "           
      ENDMENU 

      MENUITEM " ~Help "
      MENU
         MENUITEM "~Index "
         MENUITEM "~Contents "
         SEPARATOR
         MENUITEM "~About... "      ACTION Alert( "HbIde 1.0" )
      ENDMENU  
   ENDMENU

return oMenu

//-----------------------------------------------------------------------------------------//

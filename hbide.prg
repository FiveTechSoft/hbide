#include "hbclass.ch"

#pragma -b-

#xcommand MENU [<oMenu>] => [ <oMenu> := ] HBDbMenu():New()
#xcommand MENUITEM [ <oMenuItem> PROMPT ] <cPrompt> ;
          [ IDENT <nIdent> ] [ ACTION <uAction,...> ] ;
          [ CHECKED <bChecked> ] => ;
   [ <oMenuItem> := ] HBDbMenu():AddItem( HBDbMenuItem():New( <cPrompt>, ;
   [{|| <uAction> }], [<bChecked>], [<nIdent>] ) )
#xcommand SEPARATOR => HBDbMenu():AddItem( HBDbMenuItem():New( "-" ) )
#xcommand ENDMENU => ATail( HBDbMenu():aMenus ):Build()

function Main()

   local oHBIde := HBIde():New()
   
   oHbIde:Activate()

return nil

CREATE CLASS HBIde FROm HBDebugger

   METHOD LoadCallStack() VIRTUAL
   METHOD LoadVars() VIRTUAL

ENDCLASS

FUNCTION __dbgBuildMenu( oHbIde )  

   LOCAL oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~New"              ACTION Alert( "new" )
         MENUITEM "~Open..."          ACTION Alert( "open" )
         MENUITEM "~Save"             ACTION Alert( "save" )
         MENUITEM "Save ~As... "      ACTION Alert( "saveas" )
         SEPARATOR
         MENUITEM "E~xit"             ACTION oHbide:Quit()
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
         MENUITEM "~About... " ACTION Alert( "HBIde 1.0" ) 
      ENDMENU  
   ENDMENU

return oMenu

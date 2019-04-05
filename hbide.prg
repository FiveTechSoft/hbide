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
         MENUITEM " ~Open..."         ACTION Alert( "open" )
         MENUITEM " ~Resume"          ACTION Alert( "Resume" )
         MENUITEM " O~S Shell"        ACTION Alert( "shell" )
         SEPARATOR
         MENUITEM " e~Xit    Alt-X "  ACTION oHbide:Quit()
      ENDMENU

      MENUITEM " ~Edit "
      MENU
         MENUITEM " ~Copy "
         MENUITEM " ~Paste "
      ENDMENU
   ENDMENU

return oMenu

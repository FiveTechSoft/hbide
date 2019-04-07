// Harbour debugger pulldown and popup menus

#ifndef __DBGMENU_CH
#define __DBGMENU_CH

#xcommand MENU [<oMenu>] => [ <oMenu> := ] HBDbMenu():New()

#xcommand MENUITEM [ <oMenuItem> PROMPT ] <cPrompt> ;
          [ IDENT <nIdent> ] [ ACTION <uAction,...> ] ;
          [ CHECKED <bChecked> ] => ;
   [ <oMenuItem> := ] HBDbMenu():AddItem( HBDbMenuItem():New( <cPrompt>, ;
   [{|| <uAction> }], [<bChecked>], [<nIdent>] ) )

#xcommand SEPARATOR => HBDbMenu():AddItem( HBDbMenuItem():New( "-" ) )

#xcommand ENDMENU => ATail( HBDbMenu():aMenus ):Build()

#endif

// pulldown and popup menus

#ifndef __HBMENU_CH
#define __HBMENU_CH

#xcommand MENU [<oMenu>] => [ <oMenu> := ] HBMenu():New()

#xcommand MENUITEM [ <oMenuItem> PROMPT ] <cPrompt> ;
          [ IDENT <nIdent> ] [ ACTION <uAction,...> ] ;
          [ CHECKED <bChecked> ] => ;
   [ <oMenuItem> := ] HBMenu():AddItem( HBDbMenuItem():New( <cPrompt>, ;
   [{|| <uAction> }], [<bChecked>], [<nIdent>] ) )

#xcommand SEPARATOR => HBMenu():AddItem( HBDbMenuItem():New( "-" ) )

#xcommand ENDMENU => ATail( HBMenu():aMenus ):Build()

#endif

#include "inkey.ch"
#include "setcurs.ch"
#include "dbgmenu.ch"

//-----------------------------------------------------------------------------------------//

function Main()

   local cBack := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local oMenu := BuildMenu()
   local oWndCode := HBDbWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   local oEditor  := BuildEditor()
   local nOldCursor := SetCursor( SC_NORMAL )

   CLEAR SCREEN
   SetPos( 2, 1 )
   
   oMenu:Display()
   oWndCode:Show( .T. )
   oEditor:Display()
   ShowStatus( oEditor )
   
   while .T.
      nKey = Inkey( 0, INKEY_ALL )
      if nKey == K_LBUTTONDOWN
         if MRow() == 0 .or. oMenu:IsOpen()
            nOldCursor = SetCursor( SC_NONE )
            oMenu:ProcessKey( nKey )
            if ! oMenu:IsOpen()
               SetCursor( nOldCursor )
            endif 
         endif
      else 
         if oMenu:IsOpen() 
            oMenu:ProcessKey( nKey )
            if ! oMenu:IsOpen()
               SetCursor( nOldCursor )
            endif
         else
            SetCursor( nOldCursor )
            oEditor:Edit( nKey )
            ShowStatus( oEditor ) 
         endif
      endif
   end

   RestScreen( 0, 0, MaxRow(), MaxCol(), cBack )

return nil

//-----------------------------------------------------------------------------------------//

function ShowStatus( oEditor )

   DispBegin()
   hb_DispOutAt( MaxRow(), 0, Space( MaxCol() + 1 ), __DbgColors()[ 8 ] )
   hb_DispOutAt( MaxRow(), MaxCol() - 17,;
                 "row: " + AllTrim( Str( oEditor:RowPos() ) ) + ", " + ;
                 "col: " + AllTrim( Str( oEditor:ColPos() ) )+ " ",;
                 __DbgColors()[ 8 ] )
   DispEnd()

return nil

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
         SEPARATOR
         MENUITEM "~Goto Line..."    
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

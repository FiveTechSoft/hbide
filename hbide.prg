#include "hbclass.ch"
#include "hbmenu.ch"
#include "inkey.ch"
#include "setcurs.ch"

#define HB_INKEY_GTEVENT   1024

//-----------------------------------------------------------------------------------------//

function Main()

   local oHbIde := HBIde():New()

   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )

   oHbIde:Activate()
   
return nil

//-----------------------------------------------------------------------------------------//

CLASS HbIde

   DATA   cBackScreen
   DATA   oMenu
   DATA   oWndCode
   DATA   oEditor
   DATA   nOldCursor
   DATA   lEnd

   METHOD New()
   METHOD BuildMenu()
   METHOD Show()
   METHOD ShowStatus()
   METHOD Start()
   METHOD Script()
   METHOD Activate()
   METHOD End() INLINE ::lEnd := .T.   
   METHOD Hide() INLINE RestScreen( 0, 0, MaxRow(), MaxCol(), ::cBackScreen )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New() CLASS HBIde

   SetMode( 33, 100 )
   ::cBackScreen = SaveScreen( 0, 0, MaxRow(), MaxCol() )
   ::oMenu       = ::BuildMenu()
   ::oWndCode    = HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   ::oEditor     = BuildEditor()
   ::nOldCursor  = SetCursor( SC_NORMAL )

return Self

//-----------------------------------------------------------------------------------------//

METHOD Show() CLASS HBIde

   ::oMenu:Display()
   ::oWndCode:Show( .T. )
   ::oEditor:Display()
   ::ShowStatus()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowStatus() CLASS HBIde

   local aColors := ;
      { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

   DispBegin()
   hb_DispOutAt( MaxRow(), 0, Space( MaxCol() + 1 ), aColors[ 8 ] )
   hb_DispOutAt( MaxRow(), MaxCol() - 17,;
                 "row: " + AllTrim( Str( ::oEditor:RowPos() ) ) + ", " + ;
                 "col: " + AllTrim( Str( ::oEditor:ColPos() - 4 ) ) + " ",;
                 aColors[ 8 ] )
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HBIde

   local nKey, nKeyStd

   ::lEnd = .F.
   ::oEditor:Goto( 1, 5 )
   ::Show()

   while ! ::lEnd
      nKey = Inkey( 0 )
      // nKeyStd = hb_keyStd( nKey )
      if nKey == K_LBUTTONDOWN
         if MRow() == 0 .or. ::oMenu:IsOpen()
            ::nOldCursor = SetCursor( SC_NONE )
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               SetCursor( ::nOldCursor )
            endif
         endif
      else
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               SetCursor( ::nOldCursor )
            endif
         else
            SetCursor( ::nOldCursor )
            ::oEditor:Edit( nKey )
            ::ShowStatus()
         endif
      endif
   end

   ::Hide()

return nil

//-----------------------------------------------------------------------------------------//

METHOD BuildMenu() CLASS HBIde

   local oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~New"              ACTION Alert( "new" )
         MENUITEM "~Open..."          ACTION Alert( "open" )
         MENUITEM "~Save"             ACTION Alert( "save" )
         MENUITEM "Save ~As... "      ACTION Alert( "saveas" )
         SEPARATOR
         MENUITEM "E~xit"             ACTION ::End()
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
         MENUITEM "~Start "            ACTION ::Start()
         MENUITEM "S~cript "           ACTION ::Script()
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

METHOD Start() CLASS HbIde

   ::oEditor:SaveFile()

   if File( "../harbour/bin/darwin/clang/hbmk2" )
      hb_Run( "../harbour/bin/darwin/clang/hbmk2 noname.prg > info.txt" )
      Alert( MemoRead( "./info.txt" ) )
      hb_Run( "./noname" )
      SetCursor( SC_NORMAL )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Script() CLASS HbIde
   
   local oHrb, bOldError

   if File( "../harbour/lib/android/clang/libhbvm.a" )
      oHrb = hb_CompileFromBuf( StrTran( ::oEditor:GetText(), "Main", "__Main" ),;
                                .T., "-n", "-I../harbour/include" ) 
      ::Show()

      if ! Empty( oHrb )
         BEGIN SEQUENCE
            bOldError = ErrorBlock( { | o | DoBreak( o ) } )
            hb_HrbRun( oHrb )
         END SEQUENCE
         ErrorBlock( bOldError )
      endif
   endif

return nil      

//-----------------------------------------------------------------------------------------//

function DoBreak( oError )

   Alert( oError:Description )

return nil

//-----------------------------------------------------------------------------------------//

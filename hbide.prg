#include "hbclass.ch"
#include "hbmenu.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include 'hbgtinfo.ch'

#xcommand DEFAULT <uVar1> := <uVal1> ;
               [, <uVarN> := <uValN> ] => ;
                  If( <uVar1> == nil, <uVar1> := <uVal1>, ) ;;
                [ If( <uVarN> == nil, <uVarN> := <uValN>, ); ]

#define HB_INKEY_GTEVENT   1024

//-----------------------------------------------------------------------------------------//

function Main()

   local oHbIde := HBIde():New()

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
   METHOD Hide() INLINE RestScreen( 0, 0, MaxRow(), MaxCol(), ::cBackScreen )   
   METHOD Show()
   METHOD ShowStatus()
   METHOD Start()
   METHOD Script()
   METHOD Activate()
   METHOD End() INLINE ::lEnd := .T.   
   METHOD MsgInfo( cText ) 
   METHOD SaveScreen() INLINE ::cBackScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )  
   METHOD OpenFile()
   METHOD GotoLine()   

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New() CLASS HBIde

   SET SCOREBOARD OFF
   
   ::SaveScreen()
   // Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   // Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_GTEVENT )
   SetMode( 40, 120 )

   ::oMenu       = ::BuildMenu()
   ::oWndCode    = HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   ::oEditor     = BuildEditor()
   ::nOldCursor  = SetCursor( SC_NORMAL )

   Hb_GtInfo( HB_GTI_FONTNAME , "Lucida Console" )
   Hb_GtInfo( HB_GTI_FONTWIDTH, 14  )
   Hb_GtInfo( HB_GTI_FONTSIZE , 25 ) 

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )

   hb_IdleAdd( { || ::ShowStatus() } )  

return Self

//-----------------------------------------------------------------------------------------//

METHOD MsgInfo( cText, cTitle ) CLASS HBIde

   local oDlg, GetList := {}, lOk := .F.

   DEFAULT cTitle := "Information"

   oDlg = HBWindow():Dialog( cTitle, 35, 15, "W+/W" )
   oDlg:GetList = GetList
   oDlg:Show()

   oDlg:SayCenter( "Harbour IDE", -4 )
   oDlg:SayCenter( "Version 1.0", -2 )
   oDlg:SayCenter( "Copyright (c) 1999-2020 by" )
   oDlg:SayCenter( "The Harbour Project", 2 )

   @ 23, 56 GET lOk PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || ReadKill( .T. ) }

   READ
   oDlg:Hide()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD GotoLine() CLASS HBIde 

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local nLine := 1, oGetName

   oDlg = HBWindow():Dialog( "Goto line", 30, 7, "W+/W" )
   oDlg:GetList = GetList
   oDlg:Show()

   @ 18, 57 GET nLine CAPTION "number:" COLOR "W/B,W+/B,W+/W,GR+/W"

   @ 21, 50 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., ReadKill( .T. ) }

   @ 21, 60 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || ReadKill( .T. ) }

   READ
   oDlg:Hide()

   if lOk
      ::oEditor:GotoLine( nLine )
      ::oEditor:Display()
      ::oEditor:ShowCursor()
   endif   
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD Show() CLASS HBIde

   ::oMenu:Display()
   ::oWndCode:Show( .T. )
   hb_IdleDel( ::oWndCode:nIdle )
   ::oWndCode:nIdle = nil
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

   local nKey, nKeyStd, lMouseWheel := .F.

   ::lEnd = .F.
   ::oEditor:Goto( 1, 5 )
   ::Show()

   while ! ::lEnd
      nKey = InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )

      if nKey == K_LBUTTONDOWN
         if MRow() == 0 .or. ::oMenu:IsOpen()
            ::nOldCursor = SetCursor( SC_NONE )
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               ::oEditor:ShowCursor()
            endif
         else   
            ::oEditor:Edit( nKey )
            ::ShowStatus()
            ::oEditor:ShowCursor()
         endif
      else
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               ::oEditor:ShowCursor()
            endif
         else
            ::oEditor:ShowCursor()
            ::oEditor:Edit( nKey )
            ::ShowStatus()
         endif
      endif

      if nKey == K_MWFORWARD .or. nKey == K_MWBACKWARD
         if ! lMouseWheel
            lMouseWheel = .T.
            if ::oMenu:IsOpen()
               ::oMenu:ProcessKey( nKey )
            else
               ::oEditor:Edit( nKey )
            endif
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
         MENUITEM "~Open..."          ACTION ::OpenFile()
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
         MENUITEM "~Goto Line..."      ACTION ::GotoLine()
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
         MENUITEM "~About... "      ACTION ::MsgInfo( "HbIde 1.0" )
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

METHOD OpenFile() CLASS HbIde 

   local oDlg := HbWindow():Dialog( "Open a file", 38, 17, "W+/W" )
   local GetList := {}, oGetName, oListBox
   local cFileName := Space( 25 ), cPickFileName := ""
   local lDummy, lOk := .F.
   local aPrgs := Directory( "*.prg" )

   AEval( aPrgs, { | aPrg, n | aPrgs[ n ] := aPrg[ 1 ] } )
   if Len( aPrgs ) == 0
      AAdd( aPrgs, "" )
   endif   
   
   oDlg:GetList = GetList
   oDlg:Show()

   @ 14, 42 GET cFileName COLOR "W/B,W+/B,W+/W,GR+/W"

   with object oGetName := ATail( GetList )  
      :CapRow = 13   
      :CapCol = 42   
      :Caption = "File to ope&n"
      :Display()
   end   

   @ 17, 42, 27, 66 GET cPickFileName LISTBOX aPrgs ;
      COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      STATE { || If( oListBox != nil, ( oGetName:VarPut( Space( 25 ) ), oGetName:Display(),;
                     oGetName:VarPut( oListBox:buffer ), oGetName:Assign(), oGetName:Display() ),) }

   with object oListBox := ATail( GetList ):Control  
      :CapRow = 16   
      :CapCol = 43   
      :Caption = "&Files"   
      :Display()
   end   

   @ 14, 68 GET lDummy PUSHBUTTON CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || ReadKill( .T. ), lOk := .T. }

   @ 16, 68 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || ReadKill( .T. ) }

   READ

   oDlg:Hide()

   if lOk .and. ! Empty( cFileName )
      ::oEditor:LoadFile( cFileName )
      ::oEditor:Display()
      ::oEditor:Goto( 1, 5 )
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
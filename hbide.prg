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
   DATA   nIdleStatus

   METHOD New()
   METHOD About()   
   METHOD BuildMenu()
   METHOD Designer()   
   METHOD Hide() INLINE RestScreen( 0, 0, MaxRow(), MaxCol(), ::cBackScreen )   
   METHOD MsgInfo( cText ) 
   METHOD Show()
   METHOD ShowStatus()
   METHOD Start()
   METHOD Script()
   METHOD Activate()
   METHOD End() INLINE ::lEnd := .T.   
   METHOD SaveScreen() INLINE ::cBackScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )  
   METHOD OpenFile()
   METHOD GotoLine()
   METHOD FindDialog()
   METHOD SaveFile()
   METHOD Repaint()
   METHOD SuspendStatus()
   METHOD ResumeStatus()
   METHOD CompilerFlags()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New() CLASS HBIde

   SET SCOREBOARD OFF
   
   ::SaveScreen()
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   SetMode( 40, 120 )

   ::oMenu       = ::BuildMenu()
   ::oWndCode    = HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   ::oEditor     = BuildEditor()
   ::nOldCursor  = SetCursor( SC_NONE )

   Hb_GtInfo( HB_GTI_FONTNAME , "Lucida Console" )
   Hb_GtInfo( HB_GTI_FONTWIDTH, 14  )
   Hb_GtInfo( HB_GTI_FONTSIZE , 25 ) 

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "DISPLAY", @ChkDisplay() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "DISPLAY", @RadDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "HITTEST", @ChkHitTest() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "HITTEST", @RadHitTest() )

   ::nIdleStatus = hb_IdleAdd( { || ::ShowStatus() } )

   ErrorBlock( { | oError | ::MsgInfo( CallStack( oError ), "Error" ) } )

return Self

//-----------------------------------------------------------------------------------------//

function CallStack( oError, cSep, nLevel )

   local cErrorLog := ErrorMessage( oError )
   local c, n

   DEFAULT cSep := Chr( 10 ), nLevel := 1

   if ValType( oError:Args ) == "A"
      cErrorLog += cSep + "   Args:" + cSep
      for n = 1 to Len( oError:Args )
         cErrorLog += "     [" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                      "   " + hb_ValToStr( oError:Args[ n ] ) + ;
                      If( ValType( oError:Args[ n ] ) == "A", " length: " + ;
                      AllTrim( Str( Len( oError:Args[ n ] ) ) ), "" ) + cSep
      next
   endif

   while ! Empty( c := ProcName( nLevel ) )
      cErrorLog += cSep + c + "( " + hb_ntos( ProcLine( nLevel ) ) + " )"
      nLevel++
   end

return cErrorLog

//-----------------------------------------------------------------------------------------//

#define NTRIM(n)    ( LTrim( Str( n ) ) )
#include "error.ch"

static func ErrorMessage( e )

   // start error message
    local cMessage := if( empty( e:OsCode ), ;
                          if( e:severity > ES_WARNING, "Error ", "Warning " ),;
                          "(DOS Error " + NTRIM(e:osCode) + ") " )

   // add subsystem name if available
    cMessage += if( ValType( e:SubSystem ) == "C",;
                    e:SubSystem()                ,;
                    "???" )

   // add subsystem's error code if available
    cMessage += if( ValType( e:SubCode ) == "N",;
                    "/" + NTRIM( e:SubCode )   ,;
                    "/???" )
   // add error description if available
  if ( ValType( e:Description ) == "C" )
        cMessage += "  " + e:Description
   end

   // add either filename or operation
    cMessage += if( ! Empty( e:FileName ),;
                    ": " + e:FileName   ,;
                    if( !Empty( e:Operation ),;
                        ": " + e:Operation   ,;
                        "" ) )
return cMessage

//-----------------------------------------------------------------------------------------//

METHOD Designer() CLASS HBIde

   local oDlg, GetList := {}, lOk := .F., lDummy

   oDlg = HBWindow():Dialog( "Title", 35, 15, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()
   oDlg:lDesign = .T.

   @ 24, 50 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ 24, 60 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD About() CLASS HBIde

   local oDlg, GetList := {}, lOk := .F.

   oDlg = HBWindow():Dialog( "HbIde 1.0", 35, 15, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   oDlg:SayCenter( "Harbour IDE", -4 )
   oDlg:SayCenter( "Version 1.0", -2 )
   oDlg:SayCenter( "Copyright (c) 1999-2023 by" )
   oDlg:SayCenter( "The Harbour Project", 2 )

   @ 23, 56 GET lOk PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD GotoLine() CLASS HBIde 

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local nLine := 1, oGetName

   oDlg = HBWindow():Dialog( "Goto line", 30, 7, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ 18, 57 GET nLine CAPTION "number:" COLOR "W/B,W+/B,W+/W,GR+/W"

   @ 21, 50 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ 21, 60 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::oEditor:GotoLine( nLine )
      ::oEditor:Display()
      ::oEditor:ShowCursor()
   endif   
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD MsgInfo( cText, cTitle ) CLASS HBIde

   local oDlg, GetList := {}, lOk := .F.
   local aLines := hb_aTokens( cText, Chr( 10 ) ), cLine, nRow := 2

   DEFAULT cTitle := "Information"

   oDlg = HBWindow():Dialog( cTitle, 55, Len( aLines ) + 5, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   for each cLine in aLines
      oDlg:Say( nRow++, 2, cLine )
   next   

   @ oDlg:nBottom - 2, oDlg:nLeft + ( oDlg:nRight - oDlg:nLeft ) / 2 - 2 GET lOk PUSHBUTTON ;
      CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD Show() CLASS HBIde

   local n

   ::oMenu:Display()
   for n = 1 to MaxRow()
      @ n, 0 SAY Replicate( " ", MaxCol() + 1 ) COLOR "BG/B"
   next
   ::oWndCode:Show()
   hb_IdleDel( ::oWndCode:nIdle )
   ::oWndCode:nIdle = nil
   ::oEditor:Display()
   ::ShowStatus()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Repaint() CLASS HBIde

   local n

   DispBegin()
   ::oMenu:Display()
   for n = 1 to MaxRow()
      @ n, 0 SAY Replicate( " ", MaxCol() + 1 ) COLOR "BG/B"
   next
   if ::oWndCode:lVisible
      ::oWndCode:Refresh()
   endif
   ::oEditor:Display()
   ::ShowStatus()
   DispEnd()

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

METHOD SuspendStatus() CLASS HBIde

   if ::nIdleStatus != nil
      hb_IdleDel( ::nIdleStatus )
      ::nIdleStatus = nil
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ResumeStatus() CLASS HBIde

   if ::nIdleStatus == nil
      ::nIdleStatus = hb_IdleAdd( { || ::ShowStatus() } )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HBIde

   local nKey

   ::lEnd = .F.
   ::Show()
   ::oEditor:Goto( 1, 5 )

   while ! ::lEnd
      nKey = InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )

      if nKey == K_ESC .and. ! ::oMenu:IsOpen()
         ::lEnd = .T.
      endif

      if nKey >= K_ALT_Q .and. nKey <= K_ALT_M
         SetCursor( SC_NONE )
         ::oMenu:ProcessKey( nKey )
      endif

      // Handle F5 for Find
      if nKey == K_F5 .and. ! ::oMenu:IsOpen()
         ::FindDialog()
         loop
      endif

      // Handle F2 for Save
      if nKey == K_F2 .and. ! ::oMenu:IsOpen()
         ::SaveFile()
         loop
      endif




      // Handle F3 for Find Next
      if nKey == K_F3 .and. ! ::oMenu:IsOpen()
         ::oEditor:FindNext()
         ::oEditor:ShowCursor()
         ::ShowStatus()
         loop
      endif

      if nKey == K_LBUTTONDOWN
         if MRow() == 0 .or. ::oMenu:IsOpen()
            SetCursor( SC_NONE )
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               if ::oWndCode:lVisible
                  ::oEditor:ShowCursor()
               endif
            endif
         else
            if MRow() == 1 .and. MCol() == 2
               ::oWndCode:Hide()
               SetCursor( SC_NONE )
            else
               if ::oWndCode:lVisible
                  ::oEditor:Edit( nKey )
                  ::ShowStatus()
                  ::oEditor:ShowCursor()
               endif
            endif
         endif
      elseif nKey == K_MWFORWARD .or. nKey == K_MWBACKWARD
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKey )
         else
            if ::oWndCode:lVisible
               ::oEditor:Edit( nKey )
               ::ShowStatus()
               ::oEditor:ShowCursor()
            endif
         endif
      else
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKey )
            if ! ::oMenu:IsOpen()
               if ::oWndCode:lVisible
                  ::oEditor:ShowCursor()
               endif
            endif
         else
            if ::oWndCode:lVisible
               ::oEditor:ShowCursor()
               ::oEditor:Edit( nKey )
               ::ShowStatus()
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
         MENUITEM "~Save           F2 " ACTION ::SaveFile()
         MENUITEM "Save ~As... "      ACTION Alert( "saveas" )
         SEPARATOR
         MENUITEM "E~xit"             ACTION ::End()
      ENDMENU

      MENUITEM " ~Edit "
      MENU
         MENUITEM "~Copy "                  ACTION ::oEditor:CopyLine()
         MENUITEM "~Paste "                 ACTION ( ::oEditor:PasteLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Delete Line  Ctrl+Y"    ACTION ( ::oEditor:DeleteLine(), ::oEditor:ShowCursor() )
         MENUITEM "D~uplicate Line "        ACTION ( ::oEditor:DuplicateLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Find...         F5 "    ACTION ::FindDialog()
         MENUITEM "~Repeat Last Find F3"    ACTION ( ::oEditor:FindNext(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Goto Line..."           ACTION ::GotoLine()
      ENDMENU

      MENUITEM " ~Run "
      MENU
         MENUITEM "~Start "            ACTION ::Start()
         MENUITEM "S~cript "           ACTION ::Script()
         MENUITEM "~Debug "   
      ENDMENU

      MENUITEM " ~Options "
      MENU
         MENUITEM "~Compiler Flags... " ACTION ::CompilerFlags()
         MENUITEM "~Display... "        
         SEPARATOR
         MENUITEM "De~signer..."       ACTION ::Designer() 
      ENDMENU 

      MENUITEM " ~Help "
      MENU
         MENUITEM "~Index "
         MENUITEM "~Contents "
         SEPARATOR
         MENUITEM "A~bout... "      ACTION ::About()
      ENDMENU  
   ENDMENU

return oMenu

//-----------------------------------------------------------------------------------------//

METHOD Start() CLASS HbIde

   ::oEditor:SaveFile()

   do case
      case Left( OS(), 7 ) == "Windows"
         hb_Run( "c:/harbour/bin/win/msvc/hbmk2 noname.prg -comp=bcc > info.txt" )
         Alert( MemoRead( "info.txt" ) )
         hb_Run( "noname.exe" )

      case Left( OS(), 5 ) == "Linux"
         hb_Run( "../harbour/bin/darwin/clang/hbmk2 noname.prg > info.txt" )
         Alert( MemoRead( "./info.txt" ) )
         hb_Run( "./noname" )
   endcase

   SetCursor( SC_NORMAL )

return nil

//-----------------------------------------------------------------------------------------//

METHOD OpenFile() CLASS HbIde 

   local oDlg := HbWindow():Dialog( "Open a file", 38, 17, "W+/W" )
   local GetList := {}, oGetName, oListBox
   local cFileName := Space( 25 ), cPickFileName := ""
   local lDummy, lOk := .F.
   local aPrgs := Directory( "*.prg" )

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   AEval( aPrgs, { | aPrg, n | aPrgs[ n ] := aPrg[ 1 ] } )
   if Len( aPrgs ) == 0
      AAdd( aPrgs, "" )
   endif   
   
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
      STATE { || oDlg:End(), lOk := .T. }

   @ 16, 68 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk .and. ! Empty( cFileName )
      if ! ::oWndCode:lVisible
         ::oWndCode:Show( .F. )
      endif
      ::oEditor:LoadFile( cFileName )
      ::oEditor:Display()
      ::oEditor:Goto( 1, 5 )
   endif 

return nil   

//-----------------------------------------------------------------------------------------//

METHOD SaveFile() CLASS HbIde

   ::oEditor:SaveFile()
   ::oWndCode:cCaption = ::oEditor:cFile
   ::oWndCode:Refresh()
   ::oEditor:Display()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD CompilerFlags() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lWarnings := .T., lDebug := .F., lStrict := .T.
   local lIncremental := .F., lOptimize := .F., lAutoRun := .F.
   local cCompiler := "GCC", aCompilers[ 4 ]
   local cChkStyle := "[X ]", cRadStyle := "(" + Chr( 7 ) + " )"
   local cRadClr := "N/BG,N/BG,N/BG,W+/BG,N/BG,W+/BG,GR+/BG"
   local nT, nL, nR, nB

   // Turbo Vision gray dialog colors
   // Normal:       N/W    (black on gray)
   // Accelerator:  GR+/W  (yellow on gray)
   // Focused:      N/G    (black on green)
   // Button:       N/BG   (black on cyan)
   // Button focus: W+/G   (bright white on green)
   // Btn accel:    GR+/BG (yellow on cyan)
   // Group title:  W+/W   (bright white on gray)

   oDlg = HBWindow():Dialog( "Compiler Options", 56, 16, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   nT = oDlg:nTop
   nL = oDlg:nLeft
   nR = oDlg:nRight
   nB = oDlg:nBottom

   // Group: Compiler
   hb_DispBox( nT + 1, nL + 2, nT + 7, nL + 24, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 6, nL + 23,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 4, " Compiler ", "N/W" )

   aCompilers[ 1 ] = RadioButto( nT + 2, nL + 4, "&GCC" )
   aCompilers[ 2 ] = RadioButto( nT + 3, nL + 4, "&MSVC" )
   aCompilers[ 3 ] = RadioButto( nT + 4, nL + 4, "&Borland C" )
   aCompilers[ 4 ] = RadioButto( nT + 5, nL + 4, "C&lang" )

    AEval( aCompilers, { | o | o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )

    oDlg:cargo := aCompilers

   @ nT + 2, nL + 3, nT + 6, nL + 23 GET cCompiler ;
      RADIOGROUP aCompilers STYLE cRadStyle

   ATail( GetList ):Control:coldBox := ""
   ATail( GetList ):Control:hotBox := ""
   // Redraw group frame (radiogroup Display already drew its own frame)
   hb_DispBox( nT + 1, nL + 2, nT + 7, nL + 24, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 6, nL + 23,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 4, " Compiler ", "N/W" )
   ATail( GetList ):Control:Display()

   // Group: Options
   hb_DispBox( nT + 1, nL + 26, nT + 7, nR - 2, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 27, nT + 6, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 28, " Options ", "N/W" )

   @ nT + 2, nL + 28 GET lWarnings ;
      CHECKBOX CAPTION "&Warnings" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 3, nL + 28 GET lDebug ;
      CHECKBOX CAPTION "&Debug info" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 4, nL + 28 GET lStrict ;
      CHECKBOX CAPTION "S&trict types" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 5, nL + 28 GET lIncremental ;
      CHECKBOX CAPTION "&Incremental" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   // Group: Build
   hb_DispBox( nT + 8, nL + 2, nT + 12, nR - 2, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 9, nL + 3, nT + 11, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 8, nL + 4, " Build ", "N/W" )

   @ nT + 9, nL + 4 GET lOptimize ;
      CHECKBOX CAPTION "O&ptimize code" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 10, nL + 4 GET lAutoRun ;
      CHECKBOX CAPTION "&Run after build" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   // Buttons
   @ nB - 2, nL + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ nB - 2, nL + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   @ nB - 2, nL + 38 GET lDummy PUSHBUTTON ;
      CAPTION "  &Help  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || Alert( "Help not available" ) }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      // Flags selected
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindDialog() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local cText := PadR( ::oEditor:cFindText, 30 ), oGetFind

   oDlg = HBWindow():Dialog( "Find", 40, 7, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 3, oDlg:nLeft + 5 GET cText COLOR "W/B,W+/B,W+/W,GR+/W"

   with object oGetFind := ATail( GetList )
      :CapRow = oDlg:nTop + 2
      :CapCol = oDlg:nLeft + 5
      :Caption = "&Search for:"
      :Display()
   end

   @ oDlg:nTop + 5, oDlg:nLeft + 11 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nTop + 5, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk .and. ! Empty( cText )
      ::oEditor:FindText( AllTrim( cText ) )
      ::oEditor:ShowCursor()
      ::ShowStatus()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Script() CLASS HbIde
   
   local oHrb, bOldError

   oHrb = hb_CompileFromBuf( StrTran( ::oEditor:GetText(), "Main", "__Main" ),;
                              .T., "-n", "-Ic:/harbour/include" ) 
   ::Show()

   if ! Empty( oHrb )
      BEGIN SEQUENCE
         bOldError = ErrorBlock( { | o | DoBreak( o ) } )
         hb_HrbRun( oHrb )
      END SEQUENCE
      ErrorBlock( bOldError )
   endif

return nil      

//-----------------------------------------------------------------------------------------//

function DoBreak( oError )

   Alert( oError:Description )

return nil

//-----------------------------------------------------------------------------------------//
// Custom CheckBox Display: 5 colors
// 0: mark unfocused, 1: mark focused, 2: brackets+caption unfocused,
// 3: caption focused, 4: accelerator (always yellow)

function ChkDisplay()

   local Self := QSelf()
   local cColor, cAccel, cStyle := ::cStyle, cCaption, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   DispBegin()

   hb_DispOutAt( ::row + nDR, ::col + nDC + 1, ;
      iif( ::lBuffer, SubStr( cStyle, 2, 1 ), SubStr( cStyle, 3, 1 ) ), ;
      hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 1, 0 ) ) )

   cColor := hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 3, 2 ) )
   hb_DispOutAt( ::row + nDR, ::col + nDC, Left( cStyle, 1 ), cColor )
   hb_DispOutAt( ::row + nDR, ::col + nDC + 2, Right( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := At( "&", cCaption ) ) == 0
      elseif nPos == Len( cCaption )
         nPos := 0
      else
         cCaption := Stuff( cCaption, nPos, 1, "" )
      endif

      hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC, cCaption, cColor )

      if nPos != 0
         cAccel := iif( HB_IsArray( ::cargo ), ::cargo[ 1 ], hb_ColorIndex( ::cColorSpec, 3 ) )
         hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC + nPos - 1, ;
            SubStr( cCaption, nPos, 1 ), cAccel )
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//
// Patched CheckBox hitTest: applies cargo delta to match visual position

function ChkHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nDR := 0, nDC := 0, nLen, nPos

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   nLen := Len( ::cCaption )
   if ( nPos := At( "&", ::cCaption ) ) > 0 .and. nPos < nLen
      nLen--
   endif

   if nMRow == ::nRow + nDR .and. ;
      nMCol >= ::nCol + nDC .and. ;
      nMCol < ::nCol + nDC + 3
      return 1  // HTCLIENT
   endif

   if ! Empty( ::cCaption ) .and. ;
      nMRow == ::nCapRow + nDR .and. ;
      nMCol >= ::nCapCol + nDC .and. ;
      nMCol < ::nCapCol + nDC + nLen
      return 2  // HTCAPTION
   endif

   return 0  // HTNOWHERE

//-----------------------------------------------------------------------------------------//
// Patched RadioButton hitTest: applies cargo delta to match visual position

function RadHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nLen, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   nLen := Len( ::cCaption )
   if ( nPos := At( "&", ::cCaption ) ) > 0 .and. nPos < nLen
      nLen--
   endif

   if nMRow == ::Row + nDR .and. ;
      nMCol >= ::Col + nDC .and. ;
      nMCol < ::Col + nDC + 3
      return 1  // HTCLIENT
   endif

   if ! Empty( ::cCaption ) .and. ;
      nMRow == ::CapRow + nDR .and. ;
      nMCol >= ::CapCol + nDC .and. ;
      nMCol < ::CapCol + nDC + nLen
      return 1  // HTCLIENT
   endif

   return 0  // HTNOWHERE

//-----------------------------------------------------------------------------------------//
// Custom RadioButton Display: 7 colors
// 0: unused, 1: bullet unselected, 2: unused, 3: bullet selected,
// 4: caption unfocused, 5: caption focused, 6: accelerator (always yellow)

function RadDisplay()

   local Self := QSelf()
   local cColor, cAccel, cStyle := ::cStyle, cCaption, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   DispBegin()

   cColor := iif( ::lBuffer, ;
      hb_ColorIndex( ::cColorSpec, 3 ), ;
      hb_ColorIndex( ::cColorSpec, 1 ) )
   hb_DispOutAt( ::row + nDR, ::col + nDC, Left( cStyle, 1 ) + ;
      iif( ::lBuffer, SubStr( cStyle, 2, 1 ), SubStr( cStyle, 3, 1 ) ) + ;
      Right( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := At( "&", cCaption ) ) == 0
      elseif nPos == Len( cCaption )
         nPos := 0
      else
         cCaption := Stuff( cCaption, nPos, 1, "" )
      endif

      hb_DispOutAt( ::CapRow + nDR, ::CapCol + nDC, cCaption, ;
         hb_ColorIndex( ::cColorSpec, iif( ::lBuffer, 5, 4 ) ) )

      if nPos != 0
         if ::lBuffer .and. HB_IsArray( ::cargo )
            cAccel := ::cargo[ 1 ]
         else
            cAccel := hb_ColorIndex( ::cColorSpec, iif( ::lBuffer, 5, 4 ) )
         endif
         hb_DispOutAt( ::CapRow + nDR, ::CapCol + nDC + nPos - 1, ;
            SubStr( cCaption, nPos, 1 ), cAccel )
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//
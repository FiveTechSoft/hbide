REQUEST __DBGENTRY   // link the Harbour source debugger (libhbdebug)
REQUEST HB_HRBRUN    // Script/Debug invoke it by name; static links need the request
REQUEST __MVPRIVATE  // HRB debuggee PRIVATE declarations need this VM helper

#include "hbclass.ch"
#include "hbhrb.ch"
#include "hbmenu.ch"
#include "inkey.ch"
#include "getexit.ch"
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
   // multi-documento: cada HBSrcEdit conserva texto, dirty, undo/redo,
   // cursor, scroll, seleccion y breakpoints por documento. oEditor sigue
   // siendo el documento activo para todos los call sites existentes.
   DATA   aEditors   INIT {}
   DATA   nCurrent   INIT 1
   DATA   nOldCursor
   DATA   lEnd
   DATA   nIdleStatus
   DATA   nLastDiskCheck
   DATA   cCompiler    INIT HBIDE_DefCompiler()
   DATA   lWarnings    INIT .T.
   DATA   lDebugInfo   INIT .F.
   DATA   lStrict      INIT .T.
   DATA   lIncremental INIT .F.
   DATA   lOptimize    INIT .F.
   DATA   lAutoRun     INIT .T.
   DATA   oProject
   DATA   cProjectHbmk2 INIT "hbmk2"
   DATA   cPendingOpen INIT ""   // file the designer asks hbide to open on exit
   DATA   aMessages    INIT {}   // parsed compiler diagnostics of the last build
   DATA   nMsg         INIT 0    // index of the message last jumped to (0 = none)
   DATA   cRunArgs     INIT ""   // Run > Arguments: used by Start, Script and Debug
   DATA   cMsgBar      INIT ""   // one-line message shown in the status row

   ACCESS oEditor   INLINE ::aEditors[ ::nCurrent ]
   METHOD New()
   METHOD About()   
   METHOD BuildMenu()
   METHOD Designer()   
   METHOD OpenInDoc( cFileName )
   METHOD QueueOpen( cFile )
   METHOD ClearPendingOpen()
   METHOD OpenInEditor( cFileName )
   METHOD Hide() INLINE RestScreen( 0, 0, MaxRow(), MaxCol(), ::cBackScreen )   
   METHOD MsgInfo( cText ) 
   METHOD Show()
   METHOD ShowStatus()
   METHOD Start()
   METHOD Script()
   METHOD Debug()
   METHOD Activate()
   METHOD End()   
   METHOD SaveScreen() INLINE ::cBackScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )  
   METHOD NewFile()
   METHOD CloseFile()
   METHOD SwitchDoc( n )
   METHOD NextDoc()
   METHOD PrevDoc()
   METHOD FindDoc( cFile )
   METHOD CheckUnsavedAll()
   METHOD NewFile()
   METHOD SaveAs()
   METHOD DoSave()
   METHOD BuildFlags()
   METHOD ProjectOpen()
   METHOD ProjectDesktop()
   METHOD OpenFile()
   METHOD GotoLine()
   METHOD ReplaceDialog()
   METHOD FindDialog()
   METHOD CheckUnsaved()
   METHOD RecoveryCheck()
   METHOD RecoverJournal( cKey, cTarget )
   METHOD CheckDiskChange()
   METHOD ReloadFromDisk()
   METHOD ConfirmOverwrite()
   METHOD SaveFile()
   METHOD Repaint()
   METHOD SuspendStatus()
   METHOD ResumeStatus()
   METHOD CompilerFlags()
   METHOD DisplayOpts()
   METHOD ApplyDisplay( nRows, nCols )
   METHOD HelpContext()
   METHOD HelpContents()
   METHOD HelpIndex()
   METHOD HelpView( cTitle, cText, lNested )
   METHOD HelpTopic( cTitle )
   METHOD HelpPick( aTopics, cCaption )
   METHOD SaveAll()
   METHOD WindowList()
   METHOD GotoFunction()
   METHOD RunArguments()
   METHOD SetMessages( aDiag )
   METHOD MessageList()
   METHOD NextMessage( nDir )
   METHOD JumpMessage( n, cWrap )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New() CLASS HBIde

   local cLocale

   SET SCOREBOARD OFF
   Set( _SET_INSERT, .T. )   // editor works in insert mode by default (D4)
   
   ::SaveScreen()
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   SetMode( 40, 120 )

   // Pin CP437 by default: the UI glyphs (button shades, check marks, box
   // chars) are CP437 and dialog widgets paint them as raw bytes; a Latin
   // or UTF-8 display codepage renders those text-path glyphs wrong.
   // Term/box CP stay "EN" so box borders keep the CP437 mapping.
   // Experimental opt-in: HBIDE_UTF8=1 selects the UTF8 host CP, which
   // renders accented/euro file content correctly through the gttrm Unicode
   // buffer (needs a real UTF-8 terminal). Known limits in that mode,
   // documented in docs: CP437 widget shade glyphs and GET echo show "?",
   // and legacy CP437/Latin1 sources display "?" (bytes stay byte-exact).
   cLocale := GetEnv( "HBIDE_UTF8" )
   if ! Empty( cLocale ) .and. !( Upper( cLocale ) == "0" ) .and. !( Upper( cLocale ) == "NO" )
      hb_cdpSelect( "UTF8" )
   else
      hb_cdpSelect( "EN" )
   endif
   hb_SetDispCP( "EN" )

   // xterm defaults to 8-bit meta (eightBitInput): Alt+o arrives as raw byte
   // 0xEF and leaks into the editor instead of opening menus. Ask xterm for
   // ESC-prefix meta (its metaSendsEscape mode) so Alt+letter works without
   // the user having to configure the terminal. Restored on exit.
   if "xterm" $ Lower( GetEnv( "TERM" ) )
      XTermMetaEsc( .T. )
   endif

   ::oMenu       = ::BuildMenu()
   ::oWndCode    = HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   AAdd( ::aEditors, BuildEditor() )
   ::nOldCursor  = SetCursor( SC_NONE )

   Hb_GtInfo( HB_GTI_FONTNAME , "Lucida Console" )
   Hb_GtInfo( HB_GTI_FONTWIDTH, 14  )
   Hb_GtInfo( HB_GTI_FONTSIZE , 25 ) 

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "DISPLAY", @ChkDisplay() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "DISPLAY", @RadDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "HITTEST", @ChkHitTest() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "HITTEST", @RadHitTest() )

   DsnGetUInstall()

   ::nIdleStatus = hb_IdleAdd( { || ::ShowStatus() } )
   ::nLastDiskCheck = 0

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

   local oDesigner := HbDesigner():New( Self )
   local cPending

   oDesigner:Activate()
   // The designer queues a generated .prg with QueueOpen(); opening it while
   // the designer UI is active would mix two window stacks, so it opens here,
   // once the designer session has fully ended.
   if ! Empty( ::cPendingOpen )
      cPending := ::cPendingOpen
      ::cPendingOpen := ""
      ::OpenInEditor( cPending )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Contract for the dialog designer: queue a generated .prg to be opened in
// the source editor when the designer session ends. No UI here.
METHOD QueueOpen( cFile ) CLASS HBIde

   ::cPendingOpen := cFile

return nil

// Cancels a queued open (e.g. the designer queued and its dirty-model exit
// was then refused): clears the slot so no stale file opens on a later
// designer exit. No UI.
METHOD ClearPendingOpen() CLASS HBIde

   ::cPendingOpen := ""

return nil

//-----------------------------------------------------------------------------------------//

// Picker-free open of an existing file in the code editor. Same core steps
// as OpenFile()'s confirmed path. Returns .T. when the file was opened.
METHOD OpenInEditor( cFileName ) CLASS HBIde

   if ! File( cFileName )
      HBIDE_MsgAlert( "File not found: " + cFileName )
      return .F.
   endif
   ::OpenInDoc( cFileName )

return .T.

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

   @ oDlg:nBottom - 2, oDlg:nLeft + Int( ( oDlg:nRight - oDlg:nLeft ) / 2 ) - 3 GET lOk ;
      PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
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

   // Controls positioned relative to the dialog frame (D2)
   @ oDlg:nTop + 2, oDlg:nLeft + 13 GET nLine CAPTION "number:" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   @ oDlg:nBottom - 2, oDlg:nLeft + 5 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 15 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
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

// Turbo Vision-style replacement for the GT default HBIDE_MsgAlert(): white framed
// dialog with green shadowed buttons, same call contract as HBIDE_MsgAlert():
// aOptions is an array of plain captions (the first letter, or the one after
// '&', is the hotkey) and the function returns the 1-based option index,
// 0 on Escape. The GET system only paints '&' accelerators, so plain hotkey
// letters are routed through SetKey handlers restored right after Activate.

function HBIDE_MsgAlert( cMessage, aOptions, cTitle )

   local oDlg, GetList := {}, nChoice := 0, i, cMsg, cCap, nRow, nCol
   local aLines := {}, nW := 0, nBtns := 0, nHot
   local aHotIdx := {}, aOldKeys := {}, bKey, bChoose, bPress
   local lDummy

   DEFAULT cTitle := "Message"
   if Empty( aOptions )
      aOptions := { "OK" }
   endif

   // wrap long messages to a 60-column text area
   for each cMsg in hb_aTokens( cMessage, Chr( 10 ) )
      do while Len( cMsg ) > 60
         i := 61
         do while i > 30 .and. SubStr( cMsg, i, 1 ) != " "
            i--
         end
         if i <= 30
            i := 61   // no space to wrap at: hard cut
         endif
         AAdd( aLines, RTrim( Left( cMsg, i - 1 ) ) )
         cMsg := LTrim( SubStr( cMsg, i ) )
      end
      AAdd( aLines, cMsg )
   next
   for each cMsg in aLines
      nW := Max( nW, hb_ULen( cMsg ) )
   next
   nW := Max( nW + 6, 24 )
   for each cCap in aOptions
      nBtns += Len( cCap ) + 6
   next
   nW := Min( Max( nW, nBtns + 4 ), MaxCol() - 6 )

   oDlg = HBWindow():Dialog( cTitle, nW, Len( aLines ) + 5, "W+/W" )

   nRow := 2
   for each cMsg in aLines
      oDlg:Say( nRow++, 3, cMsg )
   next

   // one shared STATE block: the activated button reports its position
   bChoose := { || nChoice := AScan( GetList, { | g | g == GetActive() } ), oDlg:End() }

   // one shared SetKey block: LastKey() identifies the hotkey pressed
   bKey := { || nChoice := aHotIdx[ AScan( aHotIdx, { | e | e[ 1 ] == LastKey() } ) ][ 2 ], ;
                hb_keyPut( Chr( K_ESC ) ) }

   // Enter and Space press the focused button: the GET read does not activate
   // pushbuttons with these keys on its own, so trap them like the hotkeys
   bPress := { || nChoice := AScan( GetList, { | g | g == GetActive() } ), ;
                  hb_keyPut( Chr( K_ESC ) ) }
   for each nHot in { K_RETURN, K_SPACE }
      AAdd( aOldKeys, { nHot, SetKey( nHot ) } )
      SetKey( nHot, bPress )
   next

   nCol := Int( ( nW - nBtns ) / 2 ) + 1
   for i := 1 to Len( aOptions )
      cCap := aOptions[ i ]
      nHot := iif( ( nRow := At( "&", cCap ) ) > 0, ;
                   Asc( Upper( SubStr( cCap, nRow + 1, 1 ) ) ), ;
                   Asc( Upper( Left( cCap, 1 ) ) ) )
      AAdd( aHotIdx, { nHot, i } )
      AAdd( aHotIdx, { nHot + 32, i } )   // lowercase twin
      AAdd( aOldKeys, { nHot, SetKey( nHot ) } )
      AAdd( aOldKeys, { nHot + 32, SetKey( nHot + 32 ) } )
      SetKey( nHot, bKey )
      SetKey( nHot + 32, bKey )
      @ oDlg:nBottom - 2, oDlg:nLeft + nCol GET lDummy PUSHBUTTON ;
         CAPTION " " + cCap + " " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
         STATE bChoose
      nCol += Len( cCap ) + 6
   next

   oDlg:Activate( GetList )

   for each cCap in aOldKeys
      SetKey( cCap[ 1 ], cCap[ 2 ] )
   next

return nChoice

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
   hb_DispOutAt( MaxRow(), 2, iif( Set( _SET_INSERT ), "INS", "OVR" ), aColors[ 8 ] )
   if ::oEditor:HasMark()
      hb_DispOutAt( MaxRow(), 7, "MARK", aColors[ 9 ] )
   endif
   if ! Empty( ::cMsgBar )
      hb_DispOutAt( MaxRow(), 13, PadR( Left( ::cMsgBar, MaxCol() - 33 ), MaxCol() - 33 ), "R/W" )
   endif
   hb_DispOutAt( MaxRow(), MaxCol() - 17,;
                 "row: " + AllTrim( Str( ::oEditor:RowPos() ) ) + ", " + ;
                 "col: " + AllTrim( Str( Max( ::oEditor:ColPos() - 4, 1 ) ) ) + " ",;
                 aColors[ 8 ] )
   // not while a HBIDE_MsgAlert() modal is open: that dialog does not suspend the
   // idle painter and can cover row 0 (80x25), so ownership is tracked explicitly
   if ! HBIDE_LocaleIsUtf8() .and. HBIDE_Modal() == 0
      // effective locale (LC_ALL > LC_CTYPE > LANG) is not UTF-8: CP437 UI glyphs
      // (button shadows, borders) reach a Linux terminal as raw bytes and show as "?".
      // Drawn on the right of the menu bar so it never covers build/compiler messages.
      hb_DispOutAt( 0, 50, "Locale not UTF-8: ? glyphs", "R/W" )
   endif
   DispEnd()

return nil

// Open-modal depth for dialogs that run without the IDE object (MsgAlert).
function HBIDE_Modal( nDelta )

   static s_nModal := 0

   if HB_ISNUMERIC( nDelta )
      s_nModal := Max( 0, s_nModal + nDelta )
   endif

return s_nModal

// .T. when the effective locale is UTF-8, or when the check does not apply (Windows).
function HBIDE_LocaleIsUtf8()

   local cLoc, cName

   if "WINDOWS" $ Upper( OS() )
      return .T.
   endif
   cLoc := ""
   for each cName in { "LC_ALL", "LC_CTYPE", "LANG" }
      cLoc := GetEnv( cName )
      if ! Empty( cLoc )
         exit
      endif
   next
   cLoc := Upper( cLoc )

return "UTF-8" $ cLoc .or. "UTF8" $ cLoc

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

   local nKey, nKeyStd

   ::lEnd = .F.
   ::Show()
   ::RecoveryCheck()   // P0: offer back buffers left unsaved by a crash/kill
   ::oEditor:Goto( 1, 5 )

   while ! ::lEnd
      // HB_INKEY_EXT: gttrm keeps extended codes for keys that the classic
      // set collapses (Ctrl+Left == K_CTRL_Z, Shift+arrows == plain arrows).
      // nKeyStd feeds every pre-existing path; the editor also gets the raw
      // code so it can bind the newly distinct combinations.
      nKey = InKey( 1, INKEY_ALL + HB_INKEY_GTEVENT + HB_INKEY_EXT )   // 1s: lets the disk-change poll run idle
      nKeyStd = hb_keyStd( nKey )

      if nKeyStd == K_ESC .and. ! ::oMenu:IsOpen()
         if ::CheckUnsavedAll()
            ::lEnd = .T.
         else
            ::Repaint()
         endif
      endif

      if nKeyStd >= K_ALT_Q .and. nKeyStd <= K_ALT_M
         SetCursor( SC_NONE )
         ::oMenu:ProcessKey( nKeyStd )
         if ! ::oMenu:IsOpen()
            if ::oWndCode:lVisible
               ::oEditor:ShowCursor()
            endif
         endif
         loop   // Alt combos are menu-reserved: never fall through to the editor
      endif

      if nKeyStd == K_F1
         ::HelpContext()
         loop
      endif

      // Borland-style navigation keys (not while a menu owns the keyboard)
      if ! ::oMenu:IsOpen()
         do case
         case HBIDE_KeyIs( nKey, nKeyStd, HB_KX_F8, HB_KF_ALT, K_ALT_F8 )
            ::NextMessage( 1 )
            loop
         case HBIDE_KeyIs( nKey, nKeyStd, HB_KX_F7, HB_KF_ALT, K_ALT_F7 )
            ::NextMessage( -1 )
            loop
         case HBIDE_KeyIs( nKey, nKeyStd, HB_KX_F2, HB_KF_CTRL, K_CTRL_F2 )
            ::SaveAll()
            loop
         case nKeyStd == K_ALT_0
            ::WindowList()
            loop
         // GT normalizes Delete to Ctrl+G (7); retain the extended identity.
         case nKeyStd == K_CTRL_G .and. hb_keyExt( nKey ) != HB_KX_DEL
            ::GotoFunction()
            loop
         endcase
         if nKey != 0 .and. ! Empty( ::cMsgBar )
            ::cMsgBar := ""   // the message line lives until the next key
            ::ShowStatus()
         endif
      endif

      // Handle F5 for Find
      if nKeyStd == K_F5 .and. ! ::oMenu:IsOpen()
         ::FindDialog()
         loop
      endif

      // Handle F2 for Save
      if nKeyStd == K_F2 .and. ! ::oMenu:IsOpen()
         ::SaveFile()
         loop
      endif

      // document switching: Ctrl+F6 next, Ctrl+Shift+F6 previous
      if ! ::oMenu:IsOpen() .and. Len( ::aEditors ) > 1
         if nKeyStd == K_CTRL_F6 .or. ;
            ( hb_keyExt( nKey ) == HB_KX_F6 .and. hb_bitAnd( hb_keyMod( nKey ), HB_KF_CTRL ) != 0 )
            if hb_bitAnd( hb_keyMod( nKey ), HB_KF_SHIFT ) != 0
               ::PrevDoc()
            else
               ::NextDoc()
            endif
            loop
         endif
      endif




      // Handle F3 for Find Next
      if nKeyStd == K_F3 .and. ! ::oMenu:IsOpen()
         ::oEditor:FindNext()
         ::oEditor:ShowCursor()
         ::ShowStatus()
         loop
      endif

      if nKeyStd == K_LBUTTONDOWN
         if MRow() == 0 .or. ::oMenu:IsOpen()
            SetCursor( SC_NONE )
            ::oMenu:ProcessKey( nKeyStd )
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
      elseif nKeyStd == K_MWFORWARD .or. nKeyStd == K_MWBACKWARD
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKeyStd )
         else
            if ::oWndCode:lVisible
               ::oEditor:Edit( nKey )
               ::ShowStatus()
               ::oEditor:ShowCursor()
            endif
         endif
      else
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKeyStd )
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

      if Seconds() - ::nLastDiskCheck >= 2 .or. Seconds() < ::nLastDiskCheck
         ::nLastDiskCheck := Seconds()
         ::CheckDiskChange()
         AEval( ::aEditors, { | oEd | iif( oEd:Changed(), oEd:UpdateJournal(), NIL ) } )
      endif
   end

   ::Hide()

   if "xterm" $ Lower( GetEnv( "TERM" ) )
      XTermMetaEsc( .F. )   // restore xterm meta modes
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD BuildMenu() CLASS HBIde

   local oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~New"              ACTION ::NewFile()
         MENUITEM "~Open..."          ACTION ::OpenFile()
         MENUITEM "~Save           F2 " ACTION ::SaveFile()
         MENUITEM "Save ~As... "      ACTION ::SaveAs()
         MENUITEM "Save A~ll   Ctrl+F2 " ACTION ::SaveAll()
         MENUITEM "~Close "           ACTION ::CloseFile()
         SEPARATOR
         MENUITEM "E~xit"             ACTION ::End()
      ENDMENU

      MENUITEM " ~Edit "
      MENU
         MENUITEM "U~ndo           Ctrl+Z"   ACTION ( ::oEditor:Undo(), ::oEditor:ShowCursor() )
         MENUITEM "R~edo           Ctrl+U"   ACTION ( ::oEditor:Redo(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Copy "                  ACTION iif( ::oEditor:HasMark(), ::oEditor:CopySelection(), ::oEditor:CopyLine() )
         MENUITEM "Cu~t "                   ACTION iif( ::oEditor:HasMark(), ::oEditor:CutSelection(), ::oEditor:DeleteLine() )
         MENUITEM "~Paste "                 ACTION ( ::oEditor:PasteLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Delete Line  Ctrl+Y"    ACTION ( ::oEditor:DeleteLine(), ::oEditor:ShowCursor() )
         MENUITEM "Dup~licate Line "        ACTION ( ::oEditor:DuplicateLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Find...         F5 "    ACTION ::FindDialog()
         MENUITEM "~Repeat Last Find F3"    ACTION ( ::oEditor:FindNext(), ::oEditor:ShowCursor() )
         MENUITEM "Repl~ace... "              ACTION ::ReplaceDialog()
         SEPARATOR
         MENUITEM "~Goto Line..."           ACTION ::GotoLine()
         MENUITEM "Go to F~unction... Ctrl+G" ACTION ::GotoFunction()
      ENDMENU

      MENUITEM " ~Project "
      MENU
         MENUITEM "~Open .hbp... "       ACTION ::ProjectOpen()
         MENUITEM "~Sources / Build... " ACTION ::ProjectDesktop()
         MENUITEM "~Close project "      ACTION ( ::oProject := nil )
      ENDMENU

      MENUITEM " ~Window "
      MENU
         MENUITEM "~Next          Ctrl+F6 "   ACTION ::NextDoc()
         MENUITEM "~Previous  Ctrl+Shift+F6 " ACTION ::PrevDoc()
         MENUITEM "~Close "                  ACTION ::CloseFile()
         SEPARATOR
         MENUITEM "~List...           Alt+0 "  ACTION ::WindowList()
         MENUITEM "~Messages... "             ACTION ::MessageList()
         MENUITEM "Next Mess~age     Alt+F8 " ACTION ::NextMessage( 1 )
         MENUITEM "Previous Messa~ge Alt+F7 " ACTION ::NextMessage( -1 )
      ENDMENU
      MENUITEM " ~Run "
      MENU
         MENUITEM "~Start "            ACTION ::Start()
         MENUITEM "S~cript "           ACTION ::Script()
         MENUITEM "~Debug "          ACTION ::Debug()
         SEPARATOR
         MENUITEM "~Arguments... "     ACTION ::RunArguments()
      ENDMENU

      MENUITEM " ~Options "
      MENU
         MENUITEM "~Compiler Flags... " ACTION ::CompilerFlags()
         MENUITEM "~Display... "        ACTION ::DisplayOpts()
         SEPARATOR
         MENUITEM "De~signer..."       ACTION ::Designer() 
      ENDMENU 

      MENUITEM " ~Help "
      MENU
         MENUITEM "~Index "        ACTION ::HelpIndex()
         MENUITEM "~Contents "     ACTION ::HelpContents()
         SEPARATOR
         MENUITEM "A~bout... "      ACTION ::About()
      ENDMENU  
   ENDMENU

return oMenu

//-----------------------------------------------------------------------------------------//

METHOD Start() CLASS HbIde

   local cFile := AllTrim( ::oEditor:cFile ), cExe, cOut, cBase, cExeTmp, cErr := "", nRc, cRecovery := "", cCommand, oError
   local aDiag, nFirstErr

   if HBIDEProjectTokens( ::cRunArgs ) == nil
      HBIDE_MsgAlert( "Run > Arguments has an unbalanced quote; fix it first" )
      return nil
   endif

   if ! ::ConfirmOverwrite()
      return nil
   endif

   if Empty( cFile ) .or. cFile == "noname.prg" .and. ! File( cFile )
      HBIDE_MsgAlert( "Nothing to run: save the file first" )
      return nil
   endif

   // A blocked/failed save must not silently build the stale disk content
   if ! ::oEditor:SaveFile()
      HBIDE_MsgAlert( "Could not save " + cFile + " (original left untouched); build cancelled" )
      return nil
   endif

   // Build next to the SOURCE: hbmk2's default output is the bare name in
   // CWD, which silently collides when two sources share a basename in
   // different dirs.
   cBase = hb_FNameDir( cFile ) + hb_FNameName( cFile )   // dir part may be empty

   // hbmk2 must be on PATH (Windows build not verified here)
   do case
      case Left( OS(), 7 ) == "Windows"
         cExe = cBase + ".exe"
      otherwise
         cExe = iif( Empty( hb_FNameDir( cFile ) ), "./", "" ) + cBase
   endcase

   // Build to a sibling temp target and promote it over the real executable
   // only after a VERIFIED success (exit code 0 and the binary exists).
   // The user's previous binary is never erased up front and never launched
   // when the build failed. The output temp name is picked guaranteed-free, so
   // no preexisting user file (a leftover .buildtmp, an "info.txt" in CWD,
   // anything) is ever erased or overwritten. Build output is captured in memory.
   // On Windows the temp keeps the
   // .exe extension so hbmk2 does not append another one; on unix hbmk2
   // uses the -o name verbatim (probed: dotted names are kept as given).
#ifdef __PLATFORM__WINDOWS
   cExeTmp := HBIDE_UniqueSibling( cBase, ".exe" )
#else
   cExeTmp := HBIDE_UniqueSibling( cExe )
#endif
   if Empty( cExeTmp )
      HBIDE_MsgAlert( "Could not pick a free temp name next to " + cExe + "; build cancelled" )
      return nil
   endif

   // Process argv quoting is not shell quoting. Source/output paths remain
   // single arguments, including spaces and shell metacharacters.
   cOut := ""
   nRc := -1
   BEGIN SEQUENCE WITH { | e | Break( e ) }
      cCommand := "hbmk2" + ::BuildFlags() + " " + HBIDEProjectQuote( "-o" + cExeTmp ) + ;
         " " + HBIDEProjectQuote( cFile )
      nRc := hb_processRun( cCommand,, @cOut, @cErr )
   RECOVER USING oError
      cErr += If( HB_IsObject( oError ), oError:Description, "Invalid build process argument" )
   END SEQUENCE
   cOut += If( Empty( cErr ), "", hb_eol() + cErr )
   // hbmk2 progress uses raw CR as a separator; show it as line breaks
   // instead of CP437 glyphs (chr(13) renders as a music note)
   cOut := StrTran( cOut, Chr( 13 ) + Chr( 10 ), Chr( 10 ) )
   cOut := StrTran( cOut, Chr( 13 ), Chr( 10 ) )
   // keep the parsed diagnostics for Window > Messages / Alt+F7 / Alt+F8
   // (paths stay as hbmk2 printed them: relative to the current directory)
   aDiag := HBIDEProjectDiagnostics( cOut, hb_cwd() + hb_ps() )
   ::SetMessages( aDiag )
   HBIDE_MsgAlert( iif( Empty( cOut ), "Build OK: " + cExe, cOut ) )

   if nRc == 0 .and. File( cExeTmp )
      if ! HBIDE_ReplaceFile( cExeTmp, cExe, @cRecovery )
         HBIDE_MsgAlert( "Build succeeded but could not replace " + cExe + ": " + cRecovery )
      elseif ::lAutoRun
         // Run > Arguments: split like Script/Debug, then each word is quoted for the
         // shell so ; & | $ ` > etc. stay literal argument text, never extra commands
         hb_Run( AllTrim( HBIDE_ShellArgs( '"' + cExe + '"' ) ) + HBIDE_ShellArgs( ::cRunArgs ) )
      else
         HBIDE_MsgAlert( "Built (auto-run off): " + cExe )
      endif
   else
      FErase( cExeTmp )
      // hb_processRun returns the child exit code, not a raw shell wait status.
      HBIDE_MsgAlert( "Build failed (status " + hb_ntos( nRc ) + ") or hbmk2 not on PATH; " + ;
                      "previous executable left untouched: " + cExe )
   endif

   ::Repaint()
   SetCursor( SC_NORMAL )

   // like the Borland IDE: a failed build lands on its first error
   if ! ( nRc == 0 .and. File( cExe ) )
      nFirstErr := AScan( ::aMessages, {| h | h[ "level" ] == "error" } )
      if nFirstErr > 0
         ::JumpMessage( nFirstErr )
      endif
   elseif Len( ::aMessages ) > 0
      ::cMsgBar := hb_ntos( Len( ::aMessages ) ) + " compiler message(s): Alt+F8 next, Window > Messages"
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ProjectOpen() CLASS HbIde 

   local oDlg := HbWindow():Dialog( "Open a project (.hbp)", 46, 18, "W+/W" )
   local GetList := {}, oGetName, oListBox
   local cFileName := Space( 250 ), cPickFileName := ""
   local lDummy, lOk := .F., lTooLong := .F., nTooLong := 0, cTooLong := "", cLastLB := ""
   local aPrgs := Directory( "*.hbp" )
   local nT, nL, nR, nB, oNew

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   AEval( aPrgs, { | aPrg, n | aPrgs[ n ] := aPrg[ 1 ] } )
   if Len( aPrgs ) == 0
      AAdd( aPrgs, "" )
   endif
   // seed the sync marker with the listbox's initial selection so merely
   // tabbing into the list never overwrites a manually typed filename;
   // only an actual selection change (navigation) syncs the GET.
   cLastLB := aPrgs[ 1 ]

   // Controls positioned relative to the dialog frame (D2)
   nT = oDlg:nTop
   nL = oDlg:nLeft
   nR = oDlg:nRight
   nB = oDlg:nBottom

   @ nT + 3, nL + 3 GET cFileName PICTURE "@S37" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. }

   with object oGetName := ATail( GetList )  
      :CapRow = nT + 2   
      :CapCol = nL + 3   
      :Caption = "File to ope&n"
      :Display()
   end   

   @ nT + 5, nL + 3, nB - 3, nR - 3 GET cPickFileName LISTBOX aPrgs ;
      COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. } ;
      STATE { || If( oListBox != nil .and. oListBox:buffer != cLastLB, ;
               ( cLastLB := oListBox:buffer, ;
                 If( Len( cLastLB ) > 250, ;
                     ( oGetName:VarPut( Space( 250 ) ), oGetName:Display() ), ;
                     ( oGetName:VarPut( cLastLB ), oGetName:Assign(), oGetName:Display() ) ) ), ) }

   with object oListBox := ATail( GetList ):Control  
      :CapRow = nT + 4   
      :CapCol = nL + 4   
      :Caption = "&Files"   
      :Display()
   end   

   // names over the GET's 250-char buffer are never truncated into it:
   // the listbox leaves the GET empty instead, and OK rejects explicitly.
   // The alert fires after the dialog closes: in-dialog alerts get
   // overdrawn by the dialog's own repaint cycle.
   @ nB - 2, nR - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || If( Empty( AllTrim( oGetName:VarGet() ) ) .and. ;
                     oListBox != nil .and. Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), oDlg:End() ), ;
                  ( oDlg:End(), lOk := .T. ) ) }

   @ nB - 2, nR - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lTooLong
      HBIDE_MsgAlert( "Path too long (" + hb_ntos( nTooLong ) + ;
             " chars, max 250): " + cTooLong + "..." )
      return nil
   endif

   cFileName = AllTrim( cFileName )   // the GET is Space( 250 ): trim padding (D6)

   if lOk .and. ! Empty( cFileName )
      oNew := HBIDEProject():New()
      if oNew:Open( cFileName )
         ::oProject := oNew
         ::ProjectDesktop()
      else
         HBIDE_MsgAlert( oNew:cError )
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ProjectDesktop() CLASS HbIde

   local hNavigate, nAnswer, aDirty := {}, oEd, cMsg := ""

   if ::oProject == nil
      HBIDE_MsgAlert( "Open a .hbp with Project > Open first" )
      return nil
   endif
   // A build always reads disk. Never silently compile an outdated buffer:
   // with multidoc, ANY dirty document with a real name counts, not only the
   // current one. Dirty noname buffers are not on disk, so they cannot make
   // the build stale and are not listed.
   for each oEd in ::aEditors
      if oEd:Changed() .and. oEd:cFile != "noname.prg"
         AAdd( aDirty, oEd:cFile )
      endif
   next
   if ! Empty( aDirty )
      cMsg := iif( Len( aDirty ) == 1, "The buffer of ", hb_ntos( Len( aDirty ) ) + " buffers have unsaved changes: " ) + ;
              aDirty[ 1 ] + iif( Len( aDirty ) > 1, " (+" + hb_ntos( Len( aDirty ) - 1 ) + " more)", "" ) + ;
              ". Project builds read disk files."
      nAnswer := HBIDE_MsgAlert( cMsg, { "Save", "Use disk", "Cancel" } )
      if nAnswer == 1
         for each oEd in ::aEditors
            if oEd:Changed() .and. oEd:cFile != "noname.prg"
               ::SwitchDoc( oEd:__enumIndex() )
               ::SaveFile()
               if oEd:Changed()
                  return nil   // a failed save keeps the buffer dirty
               endif
            endif
         next
      elseif nAnswer != 2
         return nil
      endif
   endif
   ::SuspendStatus()
   hNavigate := HBIDEProjectDesktop( ::oProject, ::cProjectHbmk2 )
   ::ResumeStatus()
   ::Repaint()
   // a project build feeds the same message list as Run > Start
   if ! Empty( ::oProject:hBuild ) .and. hb_HHasKey( ::oProject:hBuild, "diagnostics" )
      ::SetMessages( ::oProject:hBuild[ "diagnostics" ] )
   endif
   if hNavigate != nil
      if ::OpenInEditor( hNavigate[ "path" ] )
         ::oEditor:Goto( hNavigate[ "line" ], hNavigate[ "column" ] + 4 )
         ::oEditor:Display()
         ::nMsg := AScan( ::aMessages, {| h | h[ "path" ] == hNavigate[ "path" ] .and. ;
                          h[ "line" ] == hNavigate[ "line" ] } )
      endif
   endif
   ::oEditor:ShowCursor()

return nil

// multi-doc open: an already-open route switches to its document instead
// of diverging two copies; a fresh untouched "noname" buffer is reused;
// anything else gets a new document. Never prompts: nothing is dropped.
METHOD OpenInDoc( cFileName ) CLASS HbIde

   local n := ::FindDoc( cFileName )

   if n > 0
      ::SwitchDoc( n )
      return nil
   endif

   if !( ::oEditor:cFile == "noname.prg" .and. ! ::oEditor:Changed() )
      AAdd( ::aEditors, BuildEditor() )
      ::nCurrent := Len( ::aEditors )
   endif

   if ! ::oWndCode:lVisible
      ::oWndCode:Show( .F. )
   endif
   ::oEditor:LoadFile( cFileName )
   ::oEditor:Display()
   ::oEditor:Goto( 1, 5 )
   ::oWndCode:cCaption := cFileName
   ::oWndCode:Refresh()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD OpenFile() CLASS HbIde 

   local oDlg := HbWindow():Dialog( "Open a file", 46, 18, "W+/W" )
   local GetList := {}, oGetName, oListBox
   local cFileName := Space( 250 ), cPickFileName := ""
   local lDummy, lOk := .F., lTooLong := .F., nTooLong := 0, cTooLong := "", cLastLB := ""
   local aPrgs := Directory( "*.prg" )
   local nT, nL, nR, nB

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   AEval( aPrgs, { | aPrg, n | aPrgs[ n ] := aPrg[ 1 ] } )
   if Len( aPrgs ) == 0
      AAdd( aPrgs, "" )
   endif
   // seed the sync marker with the listbox's initial selection so merely
   // tabbing into the list never overwrites a manually typed filename;
   // only an actual selection change (navigation) syncs the GET.
   cLastLB := aPrgs[ 1 ]

   // Controls positioned relative to the dialog frame (D2)
   nT = oDlg:nTop
   nL = oDlg:nLeft
   nR = oDlg:nRight
   nB = oDlg:nBottom

   @ nT + 3, nL + 3 GET cFileName PICTURE "@S37" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. }

   with object oGetName := ATail( GetList )  
      :CapRow = nT + 2   
      :CapCol = nL + 3   
      :Caption = "File to ope&n"
      :Display()
   end   

   @ nT + 5, nL + 3, nB - 3, nR - 3 GET cPickFileName LISTBOX aPrgs ;
      COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. } ;
      STATE { || If( oListBox != nil .and. oListBox:buffer != cLastLB, ;
               ( cLastLB := oListBox:buffer, ;
                 If( Len( cLastLB ) > 250, ;
                     ( oGetName:VarPut( Space( 250 ) ), oGetName:Display() ), ;
                     ( oGetName:VarPut( cLastLB ), oGetName:Assign(), oGetName:Display() ) ) ), ) }

   with object oListBox := ATail( GetList ):Control  
      :CapRow = nT + 4   
      :CapCol = nL + 4   
      :Caption = "&Files"   
      :Display()
   end   

   // names over the GET's 250-char buffer are never truncated into it:
   // the listbox leaves the GET empty instead, and OK rejects explicitly.
   // The alert fires after the dialog closes: in-dialog alerts get
   // overdrawn by the dialog's own repaint cycle.
   @ nB - 2, nR - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || If( Empty( AllTrim( oGetName:VarGet() ) ) .and. ;
                     oListBox != nil .and. Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), oDlg:End() ), ;
                  ( oDlg:End(), lOk := .T. ) ) }

   @ nB - 2, nR - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lTooLong
      HBIDE_MsgAlert( "Path too long (" + hb_ntos( nTooLong ) + ;
             " chars, max 250): " + cTooLong + "..." )
      return nil
   endif

   cFileName = AllTrim( cFileName )   // the GET is Space( 250 ): trim padding (D6)

   if lOk .and. ! Empty( cFileName )
      if ! File( cFileName )
         HBIDE_MsgAlert( "File not found: " + cFileName )
      else
         ::OpenInDoc( cFileName )
      endif
   endif 

return nil   

//-----------------------------------------------------------------------------------------//

METHOD End() CLASS HbIde

   if ::CheckUnsavedAll()
      ::lEnd := .T.
   else
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

// P0: at start, offer back every buffer left unsaved by a session that ended
// without a clean save/discard (crash, kill, power). "Later" keeps the
// journal and asks again next start; it is the safe default for doubts.
METHOD RecoveryCheck() CLASS HbIde

   local aItem, nPick

   for each aItem in HBIDE_RecoveryScan()
      nPick := HBIDE_MsgAlert( "Unsaved changes from an interrupted session:" + Chr( 10 ) + ;
              iif( Empty( aItem[ 2 ] ), "noname.prg", aItem[ 2 ] ) + ;
              " (" + aItem[ 4 ] + ", " + hb_ntos( aItem[ 3 ] ) + " bytes)", ;
              { "Recover", "Discard", "Later" }, "Recovery" )
      do case
         case nPick == 1
            // no pre-CheckUnsaved here: RecoverJournal never clobbers - it
            // reuses the current doc only when it is a clean noname, switches
            // +asks when the route is already open, and appends otherwise.
            // Asking here would force-resolve the buffer recovered one
            // iteration earlier (batch recovery of several journals).
            ::RecoverJournal( aItem[ 1 ], aItem[ 2 ] )
         case nPick == 2
            HBIDE_RecoveryDeleteBase( aItem[ 1 ] )
         otherwise
            // Later: keep the journal untouched
      endcase
   next

return nil

//-----------------------------------------------------------------------------------------//

// Load a journaled buffer back as dirty content: the disk file stays
// untouched until the user explicitly saves the recovered work.
METHOD RecoverJournal( cKey, cTarget ) CLASS HbIde

   local n := ::FindDoc( cTarget ), hEncoding, cText, cConverted

   if n > 0
      ::SwitchDoc( n )
      if ! ::CheckUnsaved()
         return nil   // keep the journal; user chose not to drop that buffer
      endif
   elseif ::oEditor:cFile != "noname.prg" .or. ::oEditor:Changed()
      // current doc holds real content: the recovered buffer gets its own doc
      AAdd( ::aEditors, BuildEditor() )
      ::nCurrent := Len( ::aEditors )
   endif

   cText := HBIDE_RecoveryReadBase( cKey, @hEncoding )
   if hEncoding != NIL .and. ! hEncoding[ "raw" ] .and. ;
      hEncoding[ "cp" ] != hb_cdpSelect()
      cConverted := hb_Translate( cText, hEncoding[ "cp" ], hb_cdpSelect() )
      if hb_Translate( cConverted, hb_cdpSelect(), hEncoding[ "cp" ] ) != cText
         HBIDE_MsgAlert( "Recovery needs the original editor codepage (" + hEncoding[ "cp" ] + ;
             "). Journal kept unchanged; reopen with that codepage to avoid data loss." )
         return nil
      endif
      cText := cConverted
   endif
   ::oEditor:LoadText( cText )
   ::oEditor:lUtf8 := hEncoding != NIL .and. hEncoding[ "utf8" ]
   ::oEditor:lUtf8Bom := hEncoding != NIL .and. hEncoding[ "bom" ]
   ::oEditor:lUtf8Raw := hEncoding != NIL .and. hEncoding[ "raw" ]
   ::oEditor:cFile := iif( Empty( cTarget ), "noname.prg", cTarget )
   ::oEditor:SetDirty( .T. )
   // the stamp of the disk version, so the external-change watch does not
   // fire on the very file this recovery refers to
   ::oEditor:cLoadStamp := ::oEditor:DiskStamp( ::oEditor:cFile )
   ::oEditor:cSeenStamp := ::oEditor:cLoadStamp
   ::oWndCode:cCaption := ::oEditor:cFile
   ::oEditor:cRecoveredBase := cKey
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// Returns .T. when it is safe to drop the current buffer:
// no changes, or user saved (and the save persisted), or user discarded.
METHOD CheckUnsaved() CLASS HbIde

   local lGo := .T.

   if ::oEditor:Changed()
      switch HBIDE_MsgAlert( "Unsaved changes", { "Save", "Discard", "Cancel" } )
      case 1
         ::SaveFile()
         lGo := ! ::oEditor:Changed()   // a failed save keeps the buffer dirty
         exit
      case 2
         ::oEditor:JournalDiscard()   // explicit discard: nothing to recover
         lGo := .T.
         exit
      otherwise
         lGo := .F.
      end
   endif

return lGo

//-----------------------------------------------------------------------------------------//

// External-change watch (tvedit DiskStamp/CheckDiskChanges model, adapted to
// the single-buffer HBIde). The stamp is date+time+size+MD5 of the bytes
// (<= 8 MB), so a same-size edit inside the filesystem timestamp resolution
// is detected too; larger files keep the plain stamp.
METHOD CheckDiskChange() CLASS HbIde

   local cStamp

   if ::oMenu:IsOpen() .or. Empty( ::oEditor:cFile )
      return nil
   endif

   cStamp := ::oEditor:DiskStamp( ::oEditor:cFile )
   if Empty( cStamp )
      // external deletion: there is nothing to reload, so never touch the
      // buffer. Notify once and keep it; the save guard asks before recreating
      if ! Empty( ::oEditor:cSeenStamp )
         ::oEditor:cSeenStamp := ""
         HBIDE_MsgAlert( "File deleted on disk; buffer kept: " + ::oEditor:cFile )
         ::Repaint()
         ::oEditor:ShowCursor()
      endif
      return nil
   endif

   if cStamp == ::oEditor:cSeenStamp
      return nil
   endif

   // mark as seen first: "Keep mine" must not re-ask for this same change;
   // the next own save warns before overwriting the external version
   ::oEditor:cSeenStamp := cStamp

   if ! ::oEditor:Changed()
      HBIDE_MsgAlert( "File changed on disk; reloaded: " + ::oEditor:cFile )
      ::ReloadFromDisk()
   else
      if HBIDE_MsgAlert( "File changed on disk and you have unsaved changes", ;
                { "Reload", "Keep mine" } ) == 1
         ::ReloadFromDisk()
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ReloadFromDisk() CLASS HbIde

   // keep the cursor where the user was: reload used to jump to the top.
   // Clamp to the new text: the file may have shrunk on disk.
   local nRow := ::oEditor:RowPos()
   local nCol := ::oEditor:ColPos()

   ::oEditor:LoadFile( ::oEditor:cFile )
   nRow := Min( nRow, ::oEditor:LineCount() )
   nCol := Min( nCol, ::oEditor:LineLen( nRow ) + 5 )   // gutter-based coords (K_END lands on len+5)
   ::oEditor:Goto( nRow, nCol )
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ConfirmOverwrite() CLASS HbIde

   if ::oEditor:FileVanished()
      if HBIDE_MsgAlert( "File was deleted on disk. Recreate it?", ;
                { "Recreate", "Cancel" } ) != 1
         return .F.
      endif
   elseif ::oEditor:DiskChangedSinceLoad()
      if HBIDE_MsgAlert( "File changed on disk since it was loaded/saved. Overwrite it?", ;
                { "Overwrite", "Cancel" } ) != 1
         return .F.
      endif
   endif

return .T.

//-----------------------------------------------------------------------------------------//

METHOD SaveFile() CLASS HbIde

   // untitled buffer: Save behaves as Save As (standard IDE contract)
   if Empty( ::oEditor:cFile ) .or. ::oEditor:cFile == "noname.prg"
      ::SaveAs()
      return nil
   endif

   ::DoSave()

return nil

//-----------------------------------------------------------------------------------------//

// Multi-documento: New nunca cierra ni pregunta; añade un buffer nuevo y
// conmuta. El documento anterior conserva todo su estado en su HBSrcEdit.
METHOD NewFile() CLASS HbIde

   AAdd( ::aEditors, BuildEditor() )
   ::SwitchDoc( Len( ::aEditors ) )

return nil

//-----------------------------------------------------------------------------------------//

METHOD SwitchDoc( n ) CLASS HbIde

   if n < 1 .or. n > Len( ::aEditors ) .or. n == ::nCurrent
      return nil
   endif

   ::nCurrent := n
   if ! ::oWndCode:lVisible
      ::oWndCode:Show( .F. )
   endif
   ::oWndCode:cCaption := ::oEditor:cFile
   ::Repaint()
   ::oEditor:Display()
   ::oEditor:ShowCursor()
   // el nuevo activo puede haber cambiado en disco mientras estaba atras
   ::CheckDiskChange()

return nil

//-----------------------------------------------------------------------------------------//

METHOD NextDoc() CLASS HbIde

   ::SwitchDoc( ::nCurrent % Len( ::aEditors ) + 1 )

return nil

//-----------------------------------------------------------------------------------------//

METHOD PrevDoc() CLASS HbIde

   ::SwitchDoc( iif( ::nCurrent == 1, Len( ::aEditors ), ::nCurrent - 1 ) )

return nil

//-----------------------------------------------------------------------------------------//

// indice del documento que ya tiene abierta esta ruta (canonica), 0 si no.
// Los sin-nombre no casan nunca: cada uno es un buffer distinto.
METHOD FindDoc( cFile ) CLASS HbIde

   local cAbs, oEd

   if Empty( cFile ) .or. cFile == "noname.prg"
      return 0
   endif

   cAbs := HBIDE_RecoveryAbs( cFile )
   for each oEd in ::aEditors
      if ! Empty( oEd:cFile ) .and. oEd:cFile != "noname.prg" .and. ;
         HBIDE_RecoveryAbs( oEd:cFile ) == cAbs
         return oEd:__enumIndex()
      endif
   next

return 0

//-----------------------------------------------------------------------------------------//

// cierre de un documento: pregunta SOLO por ese documento
METHOD CloseFile() CLASS HbIde

   if ! ::CheckUnsaved()
      ::Repaint()
      return nil
   endif

   ADel( ::aEditors, ::nCurrent )
   ASize( ::aEditors, Len( ::aEditors ) - 1 )
   if Len( ::aEditors ) == 0
      AAdd( ::aEditors, BuildEditor() )
   endif
   ::nCurrent := Min( ::nCurrent, Len( ::aEditors ) )
   ::oWndCode:cCaption := ::oEditor:cFile
   ::Repaint()
   ::oEditor:Display()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// salida: revisa TODOS los documentos, no solo el activo; cancelar en
// cualquiera aborta la salida
METHOD CheckUnsavedAll() CLASS HbIde

   local i

   for i := 1 to Len( ::aEditors )
      if ::aEditors[ i ]:Changed()
         ::SwitchDoc( i )
         if ! ::CheckUnsaved()
            return .F.
         endif
      endif
   next

return .T.

//-----------------------------------------------------------------------------------------//

METHOD SaveAs() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Save as", 50, 9, "W+/W" )
   local GetList := {}, oGetName, lDummy, lOk := .F.
   local cFileName := Space( 250 )
   local cName
   local cOldFile := ::oEditor:cFile
   local cOldKey  := ::oEditor:JournalKey()
   local nOther

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cFileName PICTURE "@S30" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   with object oGetName := ATail( GetList )
      :CapRow = oDlg:nTop + 2
      :CapCol = oDlg:nLeft + 3
      :Caption = "File &name"
      :Display()
   end

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   cName := AllTrim( cFileName )
   if ! lOk .or. Empty( cName )
      return nil
   endif

   if cName != ::oEditor:cFile
      nOther := ::FindDoc( cName )
      if nOther > 0 .and. nOther != ::nCurrent
         HBIDE_MsgAlert( "Already open in another document: " + cName )
         ::Repaint()
         return nil
      endif
      if File( cName )
         if HBIDE_MsgAlert( "File exists: " + cName, { "Overwrite", "Cancel" } ) != 1
            ::Repaint()
            return nil
         endif
      endif
      ::oEditor:cFile := cName
      // seed the stamps with the current disk state of the target so the
      // save guard below does not re-ask for the change we just confirmed;
      // the .bak flow in DoSave still preserves the previous disk version
      ::oEditor:cSeenStamp := ::oEditor:cLoadStamp := ::oEditor:DiskStamp( cName )
   endif

   ::DoSave()
   // rename-save succeeded: the old name's journal is stale now
   if ! ::oEditor:Changed() .and. !( cOldFile == ::oEditor:cFile )
      HBIDE_RecoveryDelete( cOldKey )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DoSave() CLASS HbIde

   local cTmp

   if ! ::ConfirmOverwrite()
      return nil
   endif

   // tvedit-style safety net: keep the previous disk version as .bak.
   // The copy runs BEFORE writing, so a failed write leaves both intact.
   if ! Empty( ::oEditor:cFile ) .and. File( ::oEditor:cFile )
      // unique temp name: never delete preexisting content assuming it is ours
      cTmp := ::oEditor:cFile + ".bak." + StrZero( hb_randomInt( 999999 ), 6 ) + ".tmp"
      if File( cTmp )
         HBIDE_MsgAlert( "Could not create the .bak copy (temp name in use); the previous .bak is preserved. Saving anyway" )
      elseif hb_FCopy( ::oEditor:cFile, cTmp ) != 0
         FErase( cTmp )   // drop the partial copy we just made
         HBIDE_MsgAlert( "Could not create the .bak copy; the previous .bak is preserved. Saving anyway" )
      elseif FRename( cTmp, ::oEditor:cFile + ".bak" ) != 0
         // rename over an existing file fails on some platforms; erase and retry once
         FErase( ::oEditor:cFile + ".bak" )
         if FRename( cTmp, ::oEditor:cFile + ".bak" ) != 0
            HBIDE_MsgAlert( "Could not update the .bak copy; the new backup is kept as " + cTmp + ". Saving anyway" )
         endif
      endif
   endif

   ::oEditor:SaveFile()
   ::oWndCode:cCaption = ::oEditor:cFile
   ::oWndCode:Refresh()
   ::oEditor:Display()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// Default compiler for the Compiler Options dialog. hbmk2 on Windows does
// not accept -comp=gcc (that id is for unix hosts); "mingw64" matches the
// standard mingw-w64 toolchain of a 64-bit Windows Harbour install.
static function HBIDE_DefCompiler()

#ifdef __PLATFORM__WINDOWS
return "MinGW64"
#else
return "GCC"
#endif

//-----------------------------------------------------------------------------------------//

METHOD CompilerFlags() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lWarnings := ::lWarnings, lDebug := ::lDebugInfo, lStrict := ::lStrict
   local lIncremental := ::lIncremental, lOptimize := ::lOptimize, lAutoRun := ::lAutoRun
   local cCompiler := ::cCompiler, aCompilers[ 5 ], bPaint
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
   bPaint := { || HBIDE_PaintFlagsGroups( oDlg ) }

   // Groups: Compiler, Options, Build
   Eval( bPaint )

   aCompilers[ 1 ] = RadioButto( nT + 2, nL + 4, "&GCC" )
   aCompilers[ 2 ] = RadioButto( nT + 3, nL + 4, "&MSVC" )
   aCompilers[ 3 ] = RadioButto( nT + 4, nL + 4, "&Borland C" )
   aCompilers[ 4 ] = RadioButto( nT + 5, nL + 4, "C&lang" )
   aCompilers[ 5 ] = RadioButto( nT + 6, nL + 4, "M&inGW64" )

    AEval( aCompilers, { | o | o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )

    oDlg:cargo := aCompilers

   @ nT + 2, nL + 3, nT + 6, nL + 23 GET cCompiler ;
      RADIOGROUP aCompilers STYLE cRadStyle

   ATail( GetList ):Control:coldBox := ""
   ATail( GetList ):Control:hotBox := ""
   // Redraw group frames (radiogroup Display already drew its own frame)
   Eval( bPaint )
   ATail( GetList ):Control:Display()

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
      STATE { || HBIDE_DialogHelp( oDlg, GetList, { || ::HelpTopic( "Compiler flags" ) }, bPaint ) }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::cCompiler    := cCompiler
      ::lWarnings    := lWarnings
      ::lDebugInfo   := lDebug
      ::lStrict      := lStrict
      ::lIncremental := lIncremental
      ::lOptimize    := lOptimize
      ::lAutoRun     := lAutoRun
   endif

return nil

//-----------------------------------------------------------------------------------------//

// hbmk2 flag string from the Compiler Options dialog selections.
// Mappings: compiler -> -comp= (long form "-compiler=" is legacy and crashes hbmk2 3.2.1dev r2026-10-24 in LegacyWarning/ParamToString), Warnings -> -w3 (off: -w0),
// Debug info -> -b, Strict types -> -es2 (warnings are fatal),
// Incremental -> -inc, Optimize code -> -O2.
METHOD BuildFlags() CLASS HbIde

   local cFlags := ""
   local aIds := { "GCC" => "gcc", "MSVC" => "msvc", "Borland C" => "bcc", "Clang" => "clang", "MinGW64" => "mingw64" }

   if hb_HHasKey( aIds, ::cCompiler )
      cFlags += " -comp=" + aIds[ ::cCompiler ]
   endif
   cFlags += iif( ::lWarnings, " -w3", " -w0" )
   if ::lDebugInfo
      cFlags += " -b"
   endif
   if ::lStrict
      cFlags += " -es2"
   endif
   if ::lIncremental
      cFlags += " -inc"
   endif
   if ::lOptimize
      cFlags += " -O2"
   endif

return cFlags

//-----------------------------------------------------------------------------------------//

// Single-line free-form input used by Find/Replace: unlike a fixed-width
// GET (Space(N) buffer), the string grows/shrinks with the keys typed, so
// trailing blanks are real data, not field padding. Enter confirms the
// dialog, Tab/Down advances to the next control, Esc cancels. Returns
// { cText, lConfirm, lNext }.
static function HBIDE_DlgInput( nRow, nCol, nWidth, cInit, cColor )

   local cText := hb_defaultValue( cInit, "" )
   local nPos := Len( cText ) + 1, nOfs := 1, nKey, cKey, cVis, nPrev
   local lInsert := .T., nOldCursor := SetCursor( SC_NORMAL )
   hb_default( @cColor, "W/B" )

   // positions are byte offsets, always kept on character boundaries
   do while .T.
      if nPos < nOfs
         nOfs := nPos
      endif
      // scroll right until the cursor cell is visible
      do while hb_ULen( SubStr( cText, nOfs, nPos - nOfs ) ) >= nWidth .and. nOfs < nPos
         nOfs := GetUNext( cText, nOfs )
      enddo
      cVis := GetUCellSlice( cText, nOfs, nWidth )
      cVis += Space( Max( 0, nWidth - hb_ULen( cVis ) ) )
      hb_DispOutAt( nRow, nCol, cVis, cColor )
      SetPos( nRow, nCol + hb_ULen( SubStr( cText, nOfs, nPos - nOfs ) ) )

      nKey := Inkey( 0, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
      do case
      case nKey == K_ESC
         SetCursor( nOldCursor )
         return { "", .F., .F. }
      case nKey == K_ENTER
         SetCursor( nOldCursor )
         return { cText, .T., .F. }
      case nKey == K_TAB .or. nKey == K_DOWN
         SetCursor( nOldCursor )
         return { cText, .F., .T. }
      case nKey == K_LEFT
         nPos := GetUPrev( cText, nPos )
      case nKey == K_RIGHT
         nPos := GetUNext( cText, nPos )
      case nKey == K_HOME
         nPos := 1
      case nKey == K_END
         nPos := Len( cText ) + 1
      case nKey == K_INS
         lInsert := ! lInsert
      case nKey == K_BS
         if nPos > 1
            nPrev := GetUPrev( cText, nPos )
            cText := Stuff( cText, nPrev, nPos - nPrev, "" )
            nPos := nPrev
         endif
      case nKey == K_DEL
         if nPos <= Len( cText )
            cText := Stuff( cText, nPos, GetUCharLen( cText, nPos ), "" )
         endif
      otherwise
         cKey := hb_keyChar( nKey )
         if Len( cKey ) > 0   // not Empty(): a typed SPACE is real data here
            cText := Stuff( cText, nPos, If( lInsert, 0, GetUCharLen( cText, nPos ) ), cKey )
            nPos += Len( cKey )
         endif
      endcase
   enddo

return { "", .F., .F. }

//-----------------------------------------------------------------------------------------//

METHOD ReplaceDialog() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F., nCount
   local cFind := "", cReplace := "", aIn   // free-form fields: trailing blanks are real data

   // prefill from the marked block when it fits on one line; this only
   // seeds the search text, it does NOT scope the replace to the selection
   cFind := ::oEditor:SelectionText()
   if hb_eol() $ cFind
      cFind := ""
   endif

   oDlg = HBWindow():Dialog( "Replace", 40, 9, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 5 SAY "Search for:" COLOR "N/W"
   @ oDlg:nTop + 4, oDlg:nLeft + 5 SAY "Replace with:" COLOR "N/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 11 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   aIn := HBIDE_DlgInput( oDlg:nTop + 3, oDlg:nLeft + 5, 28, cFind )
   if aIn[ 2 ]   // Enter: confirm with both fields as typed so far
      cFind := aIn[ 1 ]
      lOk := .T.
      oDlg:Hide()
   elseif aIn[ 3 ]   // Tab: next field
      cFind := aIn[ 1 ]
      aIn := HBIDE_DlgInput( oDlg:nTop + 5, oDlg:nLeft + 5, 28, cReplace )
      if aIn[ 2 ]
         cReplace := aIn[ 1 ]
         lOk := .T.
         oDlg:Hide()
      elseif aIn[ 3 ]
         cReplace := aIn[ 1 ]
         oDlg:Activate( GetList )   // OK/Cancel buttons
      else
         oDlg:Hide()
      endif
   else
      oDlg:Hide()
   endif
   ::ResumeStatus()

   if lOk .and. Len( cFind ) > 0
      nCount := ::oEditor:ReplaceAll( cFind, cReplace )
      ::oEditor:ShowCursor()
      HBIDE_MsgAlert( hb_ntos( nCount ) + " replacement(s)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindDialog() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local cText := "", aIn   // free-form field: trailing blanks are real data

   // prefill from the marked block when it fits on one line; this only
   // seeds the search text, it does NOT scope the search to the selection
   cText := ::oEditor:SelectionText()
   if hb_eol() $ cText
      cText := ""
   endif

   oDlg = HBWindow():Dialog( "Find", 40, 7, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 5 SAY "Search for:" COLOR "N/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 11 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   aIn := HBIDE_DlgInput( oDlg:nTop + 3, oDlg:nLeft + 5, 28, cText )
   if aIn[ 2 ]   // Enter: confirm
      cText := aIn[ 1 ]
      lOk := .T.
      oDlg:Hide()
   elseif aIn[ 3 ]   // Tab: OK/Cancel buttons
      cText := aIn[ 1 ]
      oDlg:Activate( GetList )
   else
      oDlg:Hide()
   endif
   ::ResumeStatus()

   if lOk .and. Len( cText ) > 0
      ::oEditor:FindText( cText )
      ::oEditor:ShowCursor()
      ::ShowStatus()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Script() CLASS HbIde
   
   local oHrb, bOldError, aArgs, oCompileError

   aArgs := HBIDEProjectTokens( ::cRunArgs )
   if aArgs == nil
      HBIDE_MsgAlert( "Run > Arguments has an unbalanced quote; fix it first" )
      return nil
   endif

   // FORCELOCAL isolates HRB symbols; never rewrite identifiers or string literals.
   bOldError := ErrorBlock( { | e | Break( e ) } )
   BEGIN SEQUENCE
      oHrb = hb_CompileFromBuf( ::oEditor:GetText(), ;
         .T., "-n", "-q2", "-I" + If( Empty( hb_FNameDir( ::oEditor:cFile ) ), ".", hb_FNameDir( ::oEditor:cFile ) ), "-Ic:/harbour/include" )
   RECOVER USING oCompileError
   END SEQUENCE
   ErrorBlock( bOldError )
   if oCompileError != nil
      HBIDE_MsgAlert( "Script compile error: " + oCompileError:Description + ;
         " (" + oCompileError:Operation + ")" )
      ::Repaint()
      return nil
   endif
   ::Show()

   if ! Empty( oHrb )
      BEGIN SEQUENCE
         bOldError = ErrorBlock( { | o | DoBreak( o ) } )
         // the arguments arrive as the parameters of Main()
         hb_ExecFromArray( "hb_HrbRun", AMerge( { HB_HRB_BIND_FORCELOCAL, oHrb }, aArgs ) )
      END SEQUENCE
      ErrorBlock( bOldError )
   else
      HBIDE_MsgAlert( "Script build produced no code: check the source" )
   endif

return nil      

//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//

METHOD Debug() CLASS HbIde

   local oHrb, bOldError, cTmpPrg, cTmpHrb, cOldClr := SetColor(), aArgs
   static nDbgSeq := 0

   aArgs := HBIDEProjectTokens( ::cRunArgs )
   if aArgs == nil
      HBIDE_MsgAlert( "Run > Arguments has an unbalanced quote; fix it first" )
      return nil
   endif

   // compile the buffer with debug info (-b). The VM debug-request flag
   // is per stack and hb_HrbRun() runs on the HRB stack, so an init
   // procedure inside the compiled buffer asks for the break: the Harbour
   // source debugger (libhbdebug, linked via REQUEST __DBGENTRY) stops at
   // the first line with debug info and takes over until the run ends.
   // The buffer goes to a real temp file and is compiled with
   // hb_compilebuf() so the module has a real name and the debugger
   // finds the source in the current dir.
   // unique module/file names per session: after an Alt+X abort the HRB
   // module stays registered (the unwind skips hb_hrbUnLoad()) and the
   // next hb_hrbLoad() would recycle its symbol table with static
   // initialization deactivated - init procedures (and so the debug
   // break request) would never run again.
   // Both temp names get the same unique suffix: a FIXED .prg name in the
   // user's CWD would silently overwrite (and later erase) a preexisting
   // user file with that name. The debugger resolves the source by module
   // name in the CWD, and the unique file exists there for the session.
   // Collision-free even for restarts within the same millisecond.
   // Modulo: on Windows hb_MilliSeconds() is uptime-based (GetTickCount),
   // not midnight-based, so the raw value overflows the Str() width on
   // long-lived machines and renders asterisks - an invalid filename
   // there (CreateFile STATUS_OBJECT_NAME_INVALID, seen under Wine)
   nDbgSeq++
   cTmpPrg := "__hbide_dbg__" + LTrim( Str( nDbgSeq ) ) + "_" + ;
              StrTran( Str( hb_MilliSeconds() % 1000000, 10, 3 ), " ", "0" )
   cTmpHrb := cTmpPrg + ".hrb"
   cTmpPrg += ".prg"
   hb_MemoWrit( cTmpPrg, ::oEditor:GetText() + hb_eol() + ;
                         "init procedure __hbide_debug__()" + hb_eol() + ;
                         "   __dbgInvokeDebug( .T. )" + hb_eol() + ;
                         "return" + hb_eol() )
   // hb_compilebuf() collects every parameter into argv, so the first one
   // is consumed as the program name; without -q2 the compiler prints its
   // banner to stdout raw, outside the gttrm screen buffer (this was the
   // "menubar garbage" after Script/Debug runs)
   oHrb = hb_compilebuf( "hbide", cTmpPrg, "-n", "-b", "-q2", "-I" + If( Empty( hb_FNameDir( ::oEditor:cFile ) ), ".", hb_FNameDir( ::oEditor:cFile ) ) )
   ::Show()

   if ! Empty( oHrb )
      // clear stale debugger state from a previous aborted session
      // (Break() unwinds past dbgentry.c's bInside restore)
      __hbide_dbgReset()
      // HB_HRB_BIND_FORCELOCAL: a Break() out of the debugger (Alt+X)
      // unwinds past hb_HrbRun()'s internal hb_hrbUnLoad() and leaks the
      // module. With default binding the leaked public symbols poison the
      // next session (init procedures skipped -> no debug request, and
      // stale pCode could run). FORCELOCAL keeps the module's functions
      // static to itself, so every session binds cleanly.
      // run from a uniquely named .hrb file: symbol table recycling is
      // keyed by the load filename ("pcode.hrb" for in-memory bodies)
      hb_MemoWrit( cTmpHrb, oHrb )
      ::SuspendStatus()   // IDE idle status painter must not draw over the debuggee screen
      cOldClr := SetColor( "W/N" ); CLS   // debuggee starts on a blank screen, not the IDE image
      // editor breakpoints (F9 marks) become the session's initial BPs
      __hbide_dbgPresetBPs( ::oEditor:aBPs )
      BEGIN SEQUENCE
         bOldError = ErrorBlock( { | o | DoBreak( o ) } )
         // the arguments arrive as the parameters of Main()
         hb_ExecFromArray( "hb_HrbRun", AMerge( { HB_HRB_BIND_FORCELOCAL, cTmpHrb }, aArgs ) )
      RECOVER
         // Every exit lands here or after END: normal end, Alt+X abort
         // (Quit() Break()s expecting this RECOVER) and debuggee runtime
         // errors (DoBreak already showed the alert). Without it an error
         // unwound to an outer RECOVER, skipping the cleanup below and
         // leaking this session's temp files.
      END SEQUENCE
      ErrorBlock( bOldError )
      FErase( cTmpPrg )
      FErase( cTmpHrb )
      SetColor( cOldClr )
      ::ResumeStatus()
      ::Repaint()
      SetCursor( SC_NORMAL )
   else
      // loud failure: -n rejects top-level statements (E0001), and a silent
      // return both confuses the user and leaks the temp source file
      FErase( cTmpPrg )
      HBIDE_MsgAlert( "Debug build produced no code: the compiler rejected the buffer " + ;
                      "(top-level statements need 'procedure Main()')" )
   endif

return nil

// True when nKey is the extended key nExt with modifier nMod, or the classic
// code nStd (terminals that only deliver the collapsed code).
static function HBIDE_KeyIs( nKey, nKeyStd, nExt, nMod, nStd )

return nKeyStd == nStd .or. ;
   ( hb_keyExt( nKey ) == nExt .and. hb_bitAnd( hb_keyMod( nKey ), nMod ) != 0 .and. ;
     hb_bitAnd( hb_keyMod( nKey ), hb_bitNot( nMod ) ) == 0 )

static function HBIDE_ShellArgs( cArgs )

   local aTok := HBIDEProjectTokens( cArgs ), cOut := "", c

   if aTok == nil
      return ""
   endif
   for each c in aTok
#ifdef __PLATFORM__WINDOWS
      cOut += ' "' + StrTran( c, '"', '\"' ) + '"'
#else
      cOut += " '" + StrTran( c, "'", "'\''" ) + "'"
#endif
   next

return cOut

static function AMerge( a, b )

   local x

   for each x in b
      AAdd( a, x )
   next

return a

//-----------------------------------------------------------------------------------------//

// Save every modified document that has a file name. Untitled buffers are
// never saved silently (they need a name): they are counted and left dirty.
METHOD SaveAll() CLASS HbIde

   local nOrig := ::nCurrent, nSaved := 0, nFailed := 0, nUntitled := 0, i, cMsg, oEd

   for i := 1 to Len( ::aEditors )
      oEd := ::aEditors[ i ]
      if ! oEd:Changed()
         loop
      endif
      if Empty( oEd:cFile ) .or. oEd:cFile == "noname.prg"
         nUntitled++
         loop
      endif
      ::SwitchDoc( i )
      ::DoSave()
      if ::aEditors[ i ]:Changed()
         nFailed++
      else
         nSaved++
      endif
   next
   if ::nCurrent != nOrig .and. nOrig <= Len( ::aEditors )
      ::SwitchDoc( nOrig )
   endif

   if nFailed > 0 .or. nUntitled > 0
      cMsg := hb_ntos( nSaved ) + " saved"
      if nFailed > 0
         cMsg += ", " + hb_ntos( nFailed ) + " could not be saved (still modified)"
      endif
      if nUntitled > 0
         cMsg += ", " + hb_ntos( nUntitled ) + " untitled skipped (use Save As)"
      endif
      HBIDE_MsgAlert( cMsg, nil, "Save All" )
   elseif nSaved == 0
      ::cMsgBar := "Save All: nothing modified"
   else
      ::cMsgBar := "Save All: " + hb_ntos( nSaved ) + " file(s) saved"
   endif
   ::ShowStatus()

return nil

//-----------------------------------------------------------------------------------------//

// Alt+0: list of open documents with their modified state
METHOD WindowList() CLASS HbIde

   local aLabels := {}, oEd, n

   for each oEd in ::aEditors
      AAdd( aLabels, hb_ntos( oEd:__enumIndex() ) + iif( oEd:__enumIndex() == ::nCurrent, ">", " " ) + ;
            iif( oEd:Changed(), " * ", "   " ) + oEd:cFile )
   next
   ::SuspendStatus()
   n := HBIDE_ListPick( "Window list (" + hb_ntos( Len( aLabels ) ) + ")  * = modified", aLabels, ::nCurrent, ;
                        "Enter switch   Esc cancel" )
   ::ResumeStatus()
   ::Repaint()
   if n > 0
      ::SwitchDoc( n )
   endif
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// Ctrl+G: pick a function/procedure/method of the current document
METHOD GotoFunction() CLASS HbIde

   local aProcs := HBIDE_ScanProcs( ::oEditor:GetText() ), aLabels := {}, a, n, nInit := 1, nRow := ::oEditor:RowPos()

   if Empty( aProcs )
      HBIDE_MsgAlert( "No function, procedure or method found in this document" )
      return nil
   endif
   for each a in aProcs
      AAdd( aLabels, PadR( a[ 2 ], 17 ) + PadR( a[ 1 ], 36 ) + " line " + hb_ntos( a[ 3 ] ) )
      if a[ 3 ] <= nRow
         nInit := a:__enumIndex()   // the one that contains the cursor
      endif
   next
   ::SuspendStatus()
   n := HBIDE_ListPick( "Go to function - " + hb_FNameNameExt( ::oEditor:cFile ), aLabels, nInit )
   ::ResumeStatus()
   ::Repaint()
   if n > 0
      ::oEditor:GotoLine( aProcs[ n ][ 3 ] )
      ::oEditor:Display()
   endif
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD RunArguments() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F., aIn, cText := ::cRunArgs

   oDlg = HBWindow():Dialog( "Run arguments", 56, 9, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 3 SAY "Command line arguments for Start, Script and Debug:" COLOR "N/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 17 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 28 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   aIn := HBIDE_DlgInput( oDlg:nTop + 4, oDlg:nLeft + 3, 48, cText, "N/BG" )
   if aIn[ 2 ]
      cText := aIn[ 1 ]
      lOk := .T.
      oDlg:Hide()
   elseif aIn[ 3 ]
      cText := aIn[ 1 ]
      oDlg:Activate( GetList )
   else
      oDlg:Hide()
   endif
   ::ResumeStatus()
   ::Repaint()

   if lOk
      if HBIDEProjectTokens( cText ) == nil
         HBIDE_MsgAlert( "Unbalanced quote in the arguments; they were not changed" )
      else
         ::cRunArgs := AllTrim( cText )
         ::cMsgBar := iif( Empty( ::cRunArgs ), "Run arguments cleared", "Run arguments: " + ::cRunArgs )
      endif
   endif
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD SetMessages( aDiag ) CLASS HbIde

   ::aMessages := iif( HB_ISARRAY( aDiag ), aDiag, {} )
   ::nMsg := 0

return nil

METHOD MessageList() CLASS HbIde

   local aLabels := {}, h, n

   if Empty( ::aMessages )
      HBIDE_MsgAlert( "No compiler messages. Build with Run > Start (or the project desktop) first" )
      return nil
   endif
   for each h in ::aMessages
      AAdd( aLabels, PadR( Upper( h[ "level" ] ), 8 ) + hb_FNameNameExt( h[ "path" ] ) + ":" + ;
            hb_ntos( h[ "line" ] ) + "  " + h[ "text" ] )
   next
   ::SuspendStatus()
   n := HBIDE_ListPick( "Compiler messages", aLabels, Max( 1, ::nMsg ), "Enter jump to source   Esc cancel" )
   ::ResumeStatus()
   ::Repaint()
   if n > 0
      ::JumpMessage( n )
   else
      ::oEditor:ShowCursor()
   endif

return nil

// Alt+F8 / Alt+F7 (and the Window menu): next/previous message, wrapping
METHOD NextMessage( nDir ) CLASS HbIde

   local n, cWrap := ""

   if Empty( ::aMessages )
      ::cMsgBar := "No compiler messages (build with Run > Start first)"
      ::ShowStatus()
      return nil
   endif
   n := ::nMsg + nDir
   if n > Len( ::aMessages )
      n := 1; cWrap := " (wrapped)"
   elseif n < 1
      n := Len( ::aMessages ); cWrap := " (wrapped)"
   endif
   ::JumpMessage( n, cWrap )

return nil

METHOD JumpMessage( n, cWrap ) CLASS HbIde

   local h := ::aMessages[ n ]

   hb_default( @cWrap, "" )
   if ! ::OpenInEditor( h[ "path" ] )
      return nil
   endif
   ::nMsg := n
   ::oEditor:Goto( h[ "line" ], h[ "column" ] + 4 )
   ::oEditor:Display()
   ::oEditor:ShowCursor()
   ::cMsgBar := hb_ntos( n ) + "/" + hb_ntos( Len( ::aMessages ) ) + cWrap + " " + Upper( h[ "level" ] ) + ": " + h[ "text" ]
   ::ShowStatus()

return nil

//-----------------------------------------------------------------------------------------//

function DoBreak( oError )


   HBIDE_MsgAlert( oError:Description )

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
      iif( ::lBuffer, hb_USubStr( cStyle, 2, 1 ), hb_USubStr( cStyle, 3, 1 ) ), ;
      hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 1, 0 ) ) )

   cColor := hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 3, 2 ) )
   hb_DispOutAt( ::row + nDR, ::col + nDC, hb_ULeft( cStyle, 1 ), cColor )
   hb_DispOutAt( ::row + nDR, ::col + nDC + 2, hb_URight( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := hb_UAt( "&", cCaption ) ) == 0
      elseif nPos == hb_ULen( cCaption )
         nPos := 0
      else
         cCaption := hb_ULeft( cCaption, nPos - 1 ) + hb_USubStr( cCaption, nPos + 1 )
      endif

      hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC, cCaption, cColor )

      if nPos != 0
         cAccel := iif( HB_IsArray( ::cargo ), ::cargo[ 1 ], hb_ColorIndex( ::cColorSpec, 3 ) )
         hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC + nPos - 1, ;
            hb_USubStr( cCaption, nPos, 1 ), cAccel )
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

   nLen := hb_ULen( ::cCaption )
   if ( nPos := hb_UAt( "&", ::cCaption ) ) > 0 .and. nPos < nLen
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

   nLen := hb_ULen( ::cCaption )
   if ( nPos := hb_UAt( "&", ::cCaption ) ) > 0 .and. nPos < nLen
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
   hb_DispOutAt( ::row + nDR, ::col + nDC, hb_ULeft( cStyle, 1 ) + ;
      iif( ::lBuffer, hb_USubStr( cStyle, 2, 1 ), hb_USubStr( cStyle, 3, 1 ) ) + ;
      hb_URight( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := hb_UAt( "&", cCaption ) ) == 0
      elseif nPos == hb_ULen( cCaption )
         nPos := 0
      else
         cCaption := hb_ULeft( cCaption, nPos - 1 ) + hb_USubStr( cCaption, nPos + 1 )
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
            hb_USubStr( cCaption, nPos, 1 ), cAccel )
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//

// Topic picker shared by Help>Contents (all topics) and Help>Index (filtered).
// Returns the 1-based topic index within aTopics, 0 when cancelled.
METHOD HelpPick( aTopics, cCaption ) CLASS HbIde

   local oDlg := HbWindow():Dialog( cCaption, 50, 14, "W+/W" )
   local GetList := {}, lDummy, lOk := .F., cPick := ""
   local aTitles := {}, oListBox

   AEval( aTopics, { | t | AAdd( aTitles, t[ 2 ] ) } )

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 3, oDlg:nBottom - 4, oDlg:nRight - 3 GET cPick ;
      LISTBOX aTitles COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   oListBox := ATail( GetList ):Control

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if ! lOk
      return 0
   endif

return AScan( aTopics, { | t | t[ 2 ] == oListBox:buffer } )

//-----------------------------------------------------------------------------------------//

METHOD HelpContents() CLASS HbIde

   HBIDEHelpBrowser( HBIDEHelpTopics(), 0 )

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpIndex() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Help - Index", 50, 8, "W+/W" )
   local GetList := {}, lDummy, lOk := .F., oGetName
   local cFilter := Space( 30 ), cKey, aTopics, aMatch := {}, nPick

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cFilter COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   with object oGetName := ATail( GetList )
      :CapRow = oDlg:nTop + 2
      :CapCol = oDlg:nLeft + 3
      :Caption = "&Keyword"
      :Display()
   end

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if ! lOk
      return nil
   endif

   cKey := Lower( AllTrim( cFilter ) )
   aTopics := HBIDEHelpTopics()
   if Empty( cKey )
      aMatch := aTopics
   else
      AEval( aTopics, { | t | iif( cKey $ Lower( t[ 1 ] + " " + t[ 2 ] ), ;
         AAdd( aMatch, t ), ) } )
   endif

   if Len( aMatch ) == 0
      HBIDE_MsgAlert( "No help topic matches: " + cKey )
   elseif Len( aMatch ) == 1
      ::HelpView( aMatch[ 1, 2 ], aMatch[ 1, 3 ] )
   else
      while ( nPick := ::HelpPick( aMatch, "Help - Index" ) ) > 0
         ::HelpView( aMatch[ nPick, 2 ], aMatch[ nPick, 3 ] )
      end
   endif

return nil

//-----------------------------------------------------------------------------------------//



// Paints the three labeled group frames of the Compiler Flags dialog.
// Used for the initial paint and to restore them after a nested dialog.
static function HBIDE_PaintFlagsGroups( oDlg )

   local nT := oDlg:nTop, nL := oDlg:nLeft
   local nR := oDlg:nRight

   hb_DispBox( nT + 1, nL + 2, nT + 7, nL + 24, ;
               hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 6, nL + 23,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 4, " Compiler ", "N/W" )

   hb_DispBox( nT + 1, nL + 26, nT + 7, nR - 2, ;
               hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 27, nT + 6, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 28, " Options ", "N/W" )

   hb_DispBox( nT + 8, nL + 2, nT + 12, nR - 2, ;
               hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 9, nL + 3, nT + 11, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 8, nL + 4, " Build ", "N/W" )

return nil

// Runs a help action over a modal GET dialog without visual overlap:
// Hide() drops the dialog idle repaint task and clears its area, the help
// draws on the clean IDE background, then the dialog and its GETs redraw.
static function HBIDE_DialogHelp( oDlg, GetList, bHelp, bPaint )

   local oCtrl

   oDlg:Hide()
   Eval( bHelp )
   oDlg:Show( .T. )
   if bPaint != nil
      Eval( bPaint )
   endif
   for each oCtrl in GetList
      if oCtrl:Control != nil
         oCtrl:Control:Display()
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpTopic( cTitle ) CLASS HbIde

   local aTopics := HBIDEHelpTopics()
   local n := AScan( aTopics, { | t | t[ 2 ] == cTitle } )

   if n > 0
      ::HelpView( aTopics[ n, 2 ], aTopics[ n, 3 ], .T. )
   else
      HBIDE_MsgAlert( "Help not available" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpView( cTitle, cText, lNested ) CLASS HbIde

   local aTopics := HBIDEHelpTopics()

   if AScan( aTopics, { | t | t[ 2 ] == cTitle } ) == 0
      AAdd( aTopics, { "", cTitle, cText } )
   endif
   ::SuspendStatus()
   HBIDEHelpOpen( cTitle, aTopics )
   ::ResumeStatus()
   if ! hb_defaultValue( lNested, .F. )
      ::Repaint()
      ::oEditor:ShowCursor()
   endif

return nil

// Open help about the highlighted menu command, never execute that command.
METHOD HelpContext() CLASS HbIde

   local cMenu := "", cItem := "", oPopup, n
   local lMenu := ::oMenu:IsOpen(), cTitle

   if lMenu
      n := ::oMenu:nOpenPopup
      if n > 0 .and. n <= Len( ::oMenu:aItems )
         cMenu := ::oMenu:aItems[ n ]:cPrompt
         oPopup := ::oMenu:aItems[ n ]:bAction
         if HB_ISOBJECT( oPopup ) .and. oPopup:nOpenPopup > 0 .and. ;
               oPopup:nOpenPopup <= Len( oPopup:aItems )
            cItem := oPopup:aItems[ oPopup:nOpenPopup ]:cPrompt
         endif
      endif
      ::oMenu:Close()
   endif
   cTitle := HBIDEHelpContext( cMenu, cItem )
   ::HelpTopic( cTitle )
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayOpts() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Display", 30, 9, "W+/W" )
   local GetList := {}, lDummy, lOk := .F.
   local aSizes := { "40 x 120", "30 x 100", "25 x 80" }
   local cRadStyle := "(" + Chr( 7 ) + " )"
   local aRadios := {}, n, cSize := aSizes[ 1 ]
   local nT, nL, nB, nR

   // preselect the current mode when it is one of the presets
   for n = 1 to Len( aSizes )
      if Val( Left( aSizes[ n ], 2 ) ) == MaxRow() + 1
         cSize := aSizes[ n ]
      endif
   next

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   nT := oDlg:nTop
   nL := oDlg:nLeft
   nB := oDlg:nBottom
   nR := oDlg:nRight

   for n = 1 to Len( aSizes )
      AAdd( aRadios, RadioButto( nT + 1 + n, nL + 4, aSizes[ n ] ) )
      ATail( aRadios ):colorSpec := "N/W,N/W,N/W,W+/W,N/W,W+/W,GR+/W"
   next

   @ nT + 2, nL + 3, nT + 4, nR - 3 GET cSize ;
      RADIOGROUP aRadios STYLE cRadStyle

   ATail( GetList ):Control:coldBox := ""
   ATail( GetList ):Control:hotBox := ""
   hb_Scroll( nT + 1, nL + 2, nB - 3, nR - 2,,, "N/W" )
   ATail( GetList ):Control:Display()

   @ nB - 2, nR - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ nB - 2, nR - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::ApplyDisplay( Val( Left( cSize, 2 ) ), Val( SubStr( cSize, 6 ) ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ApplyDisplay( nRows, nCols ) CLASS HbIde

   local nOldRows := MaxRow() + 1, nOldCols := MaxCol() + 1

   if nRows == nOldRows .and. nCols == nOldCols
      return nil
   endif

   ::oWndCode:Hide()
   if ! SetMode( nRows, nCols ) .or. MaxRow() + 1 != nRows .or. MaxCol() + 1 != nCols
      SetMode( nOldRows, nOldCols )
      HBIDE_MsgAlert( "Terminal does not support " + hb_ntos( nRows ) + "x" + hb_ntos( nCols ) )
      ::oWndCode:Show( .F. )
      ::Repaint()
      ::oEditor:ShowCursor()
      return nil
   endif

   ::SaveScreen()
   ::oWndCode := HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), ;
                                 ::oWndCode:cCaption, "W/B" )
   ::oWndCode:Show( .F. )
   ::oEditor:Resize( 2, 1, MaxRow() - 2, MaxCol() - 1 )
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// Ask xterm for ESC-prefix meta (eightBitInput off + metaSendsEscape on) or
// restore its defaults. QQOut cannot be used: gttrm draws OutStd into the
// screen buffer instead of forwarding it to the terminal, so the escape
// never reaches xterm. Writing to /dev/tty bypasses the GT.
function XTermMetaEsc( lOn )

   local nH := FOpen( "/dev/tty", 1 )   // FO_WRITE

   if nH != -1
      if lOn
         FWrite( nH, Chr( 27 ) + "[?1034l" + Chr( 27 ) + "[?1036h" )
      else
         FWrite( nH, Chr( 27 ) + "[?1036l" + Chr( 27 ) + "[?1034h" )
      endif
      FClose( nH )
   endif

return nil

//-----------------------------------------------------------------------------------------//

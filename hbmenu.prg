#include "hbclass.ch"
#include "box.ch"
#include "inkey.ch"

#xcommand DEFAULT <uVar1> := <uVal1> ;
   [, <uVarN> := <uValN> ] => ;
      If( <uVar1> == nil, <uVar1> := <uVal1>, ) ;;
    [ If( <uVarN> == nil, <uVarN> := <uValN>, ); ]

//-----------------------------------------------------------------------------------------//

CLASS HbMenu FROM HBDbMenu

   DATA lStandalone INIT .F.   // .T. when built via MENU ... POPUP (HbMenu:New(.T.))

   METHOD New( lPopup )

   METHOD Activate()   

   METHOD AddItem( oMenuItem )

   METHOD Build()

   METHOD ClosePopup( nOpenPopup )
      
   METHOD EvalAction()   

   METHOD LoadColors()

   METHOD Display()

   METHOD ProcessKey( nKey )   

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( lPopup ) CLASS HbMenu 

   DEFAULT lPopup := .F.

   if lPopup
      ::aMenus = { Self }      // non-empty stack flags lPopup in super:New()
   endif

   ::super:New()               // sets ::lPopup and pushes Self onto the stack

   if lPopup
      ::lStandalone := .T.
      ::aMenus = { Self }      // drop the duplicate push: a doubled entry makes the
                               // base Build() run its nested-submenu branch on the
                               // popup and overwrite its last item's bAction with Self
      ::nTop    = 25
      ::nLeft   = 30
      ::nBottom = 27
      ::nRight  = 70
   endif   

return Self   

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HbMenu

   local oMenuItem

   ::nRight += 8
   for each oMenuItem in ::aItems
      if oMenuItem:cPrompt != "-" 
         oMenuItem:cPrompt += Space( ::nRight - ::nLeft - Len( oMenuItem:cPrompt ) )
      endif   
   next   
   ::Display()
   ::aItems[ 1 ]:Display( ::cClrHilite, ::cClrHotFocus )
   ::nOpenPopup = 1

   while ::nOpenPopup != 0
      ::ProcessKey( Inkey( 0 ) )
   end   

return nil   

//-----------------------------------------------------------------------------------------//

METHOD AddItem( oMenuItem ) CLASS HbMenu
   
   local oLastMenu := ATail( ::aMenus )
   local oLastMenuItem

   if oLastMenu:lPopup
      oMenuItem:nRow := oLastMenu:nTop + 1 + Len( oLastMenu:aItems )
      oMenuItem:nCol := oLastMenu:nLeft + 3
   else
      oMenuItem:nRow := 0
      if Len( oLastMenu:aItems ) > 0
         oLastMenuItem := ATail( oLastMenu:aItems )
         oMenuItem:nCol := oLastMenuItem:nCol + ;
            Len( StrTran( oLastMenuItem:cPrompt, "~" ) )
      else
         oMenuItem:nCol := 0
      endif
   endif

   AAdd( ATail( ::aMenus ):aItems, oMenuItem )

return oMenuItem

//-----------------------------------------------------------------------------------------//
// A standalone popup positions its items in AddItem() and has no parent item.
// The base Build() nested branch would rewrite the last item's bAction with
// the popup object itself (the F2 "Generate-and-open" crash) and re-layout
// the items as a bar; the pulldown branch would re-position them as a row-0
// menubar. Skip both and leave the shared construction stack clean so the
// next MENU...ENDMENU (the IDE menubar) is not poisoned by the popup entry.
//
METHOD Build() CLASS HbMenu

   if ::lStandalone
      // A standalone popup positions its items in AddItem() and has no parent item.
      // The base Build() would either relayout it as a row-0 menubar (Len==1) or
      // overwrite its last item's bAction with the popup object itself (the F2
      // "Generate-and-open" crash). Just pop Self off the shared construction
      // stack so the next MENU...ENDMENU starts clean.
      if Len( ::aMenus ) > 0 .and. ATail( ::aMenus ) == Self
         ::aMenus = ASize( ::aMenus, Len( ::aMenus ) - 1 )
      endif
   else
      ::Super:Build()
   endif

return nil
   
//-----------------------------------------------------------------------------------------//

METHOD ClosePopup( nOpenPopup ) CLASS HbMenu

   if ::lPopup
      if ::cBackImage != nil
         __dbgRestScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2, ::cBackImage )
         ::cBackImage = nil
      endif
      ::nOpenPopup = 0
   else
      ::Super:ClosePopup( nOpenPopup )
   endif      

return nil

//-----------------------------------------------------------------------------------------//

METHOD EvalAction() CLASS HbMenu

   local oMenuItem

   if ::lPopup
      oMenuItem = ::aItems[ ::nOpenPopup ]
      if oMenuItem:bAction != nil
         Eval( oMenuItem:bAction, oMenuItem )
      endif
      ::ClosePopup( ::nOpenPopup )
   else
      ::Super:EvalAction()   
   endif
   
return nil   

//-----------------------------------------------------------------------------------------//

METHOD LoadColors() CLASS HbMenu

   local aColors := { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" } 
   local oMenuItem

   ::cClrPopup    := aColors[  8 ]
   ::cClrHotKey   := aColors[  9 ]
   ::cClrHilite   := aColors[ 10 ]
   ::cClrHotFocus := aColors[ 11 ]

   for each oMenuItem in ::aItems
      if HB_ISOBJECT( oMenuItem:bAction )
         oMenuItem:bAction:LoadColors()
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD Display() CLASS HbMenu
   
   local oMenuItem

   if ::lPopup
      ::cBackImage := __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2 )
      hb_DispBox( ::nTop, ::nLeft, ::nBottom, ::nRight, HB_B_SINGLE_UNI, ::cClrPopup )
      hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
   else
      hb_DispOutAt( 0, 0, Space( MaxCol() + 1 ), ::cClrPopup )
   endif

   FOR EACH oMenuItem IN ::aItems
      IF oMenuItem:cPrompt == "-"  // Separator
         hb_DispOutAtBox( oMenuItem:nRow, ::nLeft, ;
            hb_UTF8ToStrBox( "├" + Replicate( "─", ::nRight - ::nLeft - 1 ) + "┤" ), ::cClrPopup )
      ELSE
         oMenuItem:Display( ::cClrPopup, ::cClrHotKey )
      ENDIF
   NEXT

return nil

//-----------------------------------------------------------------------------------------//

METHOD ProcessKey( nKey ) CLASS HbMenu

   local n, oPopup, nItem, oItem

   do case
      case nKey == K_LBUTTONDOWN
         if ::lPopup
            if ( nItem := ::GetItemOrdByCoors( MRow(), MCol() ) ) == 0
               ::Close()
            else
               ::DeHilite()
               ::nOpenPopup := nItem
               ::aItems[ nItem ]:Display( ::cClrHilite, ::cClrHotFocus )
               ::Close()
               ::nOpenPopup = nItem
               ::EvalAction()
               ::nOpenPopup = 0
            endif
         else 
            ::Super:ProcessKey( nKey )
         endif

      case nKey == K_ESC 
         if ::lPopup 
            ::Close()
         else
            ::Super:ProcessKey( nKey )
         endif      

      case nKey == K_UP 
         if ::lPopup
            ::DeHilite()
            if ::nOpenPopup > 1
               ::nOpenPopup--
               while ::nOpenPopup < Len( ::aItems ) .and. ;
                  hb_LeftEq( ::aItems[ ::nOpenPopup ]:cPrompt, "-" )
                  --::nOpenPopup
               end
            else   
               ::nOpenPopup = Len( ::aItems )
            endif      
            ::aItems[ ::nOpenPopup ]:Display( ::cClrHilite, ::cClrHotFocus )
         else
            ::Super:ProcessKey( nKey )   
         endif   

      case nKey == K_DOWN
         if ::lPopup
            ::DeHilite()
            if ::nOpenPopup < Len( ::aItems )
               ::nOpenPopup++
               while ::nOpenPopup < Len( ::aItems ) .and. ;
                  hb_LeftEq( ::aItems[ ::nOpenPopup ]:cPrompt, "-" )
                  ++::nOpenPopup
               end
            else   
               ::nOpenPopup = 1
            endif      
            ::aItems[ ::nOpenPopup ]:Display( ::cClrHilite, ::cClrHotFocus )
         else
            ::Super:ProcessKey( nKey )   
         endif   

      case nKey == K_MWBACKWARD
         ::GoDown() 
         
      case nKey == K_MWFORWARD   
         ::GoUp()

      case nKey == K_HOME
         if ::lPopup
            // the base GoTop()/GoBottom() assume a menubar whose items hold
            // popup objects in bAction; a standalone popup holds codeblocks,
            // so Home/End must move the highlight directly
            ::DeHilite()
            ::nOpenPopup = 1
            while ::nOpenPopup < Len( ::aItems ) .and. ;
               hb_LeftEq( ::aItems[ ::nOpenPopup ]:cPrompt, "-" )
               ++::nOpenPopup
            end
            ::aItems[ ::nOpenPopup ]:Display( ::cClrHilite, ::cClrHotFocus )
         else
            ::Super:ProcessKey( nKey )
         endif

      case nKey == K_END
         if ::lPopup
            ::DeHilite()
            ::nOpenPopup = Len( ::aItems )
            while ::nOpenPopup > 1 .and. ;
               hb_LeftEq( ::aItems[ ::nOpenPopup ]:cPrompt, "-" )
               --::nOpenPopup
            end
            ::aItems[ ::nOpenPopup ]:Display( ::cClrHilite, ::cClrHotFocus )
         else
            ::Super:ProcessKey( nKey )
         endif

      case ::lPopup .and. IsAlpha( hb_keyChar( nKey ) )
         // standalone popup: plain letters pick the item with that hotkey;
         // deferring them to the top-bar handler treats an action block as a
         // submenu and crashes (error 9001)
         if ( nItem := ::GetHotKeyPos( Upper( hb_keyChar( nKey ) ) ) ) != 0
            ::DeHilite()
            ::nOpenPopup = nItem
            ::aItems[ nItem ]:Display( ::cClrHilite, ::cClrHotFocus )
            ::EvalAction()
         endif

      case nKey >= K_ALT_Q .and. nKey <= K_ALT_M
         if ( n := ::GetHotKeyPos( __dbgAltToKey( nKey ) ) ) != 0
            IF n != ::nOpenPopup
               ::ClosePopup( ::nOpenPopup )
               ::ShowPopup( n )
            ENDIF            
         else   
            for n = 1 to Len( ::aItems )
               oPopup = ::aItems[ n ]:bAction
               if ( nItem := oPopup:GetHotKeyPos( __dbgAltToKey( nKey ) ) ) != 0
                  oMenuItem := oPopup:aItems[ nItem ]
                  IF oMenuItem:bAction != NIL
                     Eval( oMenuItem:bAction, oMenuItem )
                  ENDIF
               endif   
            next   
         endif   

      otherwise
         ::Super:ProcessKey( nKey )
   endcase
   
return nil   

//-----------------------------------------------------------------------------------------//

// getu.prg - UTF8-aware GET editing for hbide (char-aware, byte-model preserving)
//
// Instalación vía __ClsModMsg desde hbide Init. El árbol Harbour NO se toca.
//
// Contrato medido (probe en xterm UTF8/EN, 2026-10-24):
//   Inkey(0, Set(_SET_EVENTMASK)+HB_INKEY_EXT) entrega el texto como evento
//   EXT|UNICODE (bits altos 0x43, valor = codepoint). hb_keyChar() del evento
//   CRUDO devuelve la cadena correcta en el CP anfitrión (UTF8: C3 A9 = é;
//   EN: 82 = é CP437). hb_keyStd() del evento devuelve el código clásico
//   (EN: 130). La máscara se mantiene en clase teclado: los eventos de ratón
//   siguen fuera del READ para el sondeo ReadMouse de hbwindow (sin interferir).
//   El READ core usa Inkey(0) clásico: el evento Unicode degrada al valor
//   pelado (233) y hb_keyChar(233) lo reinterpreta como byte CP -> U+FFFD.
//   (hb_keyChar NO está roto: el evento Unicode codifica bien; el código
//   clásico no lo transporta.)
//   Ratón: el READ de hoy solo extrae clase teclado (Set(_SET_EVENTMASK)
//   por defecto = INKEY_KEYBOARD); los clics los sirve el sondeo ReadMouse
//   de hbwindow. Este parche NO cambia las clases extraídas (máscara
//   intacta + solo formato EXT), así que el puente de sondeo queda igual
//   que hoy. OJO (traza del diseñador): hb_gt_def_InkeyFilter/
//   InkeyNextCheck pueden DESCARTAR de la cola los eventos de clases
//   excluidas; no afirmamos que "queden en cola". Cuando el fix de clic
//   rápido requiera eventos de ratón en el reader, el punto de extensión
//   es: ampliar la máscara con las clases de ratón y despachar
//   hb_keyStd(nKey) normalizado por el routing ya existente aquí (los
//   eventos de ratón llegan normalizados a K_M* clásicos).
//
// Invariante: ::nPos siempre en inicio de carácter (offset de bytes).
// Almacenamiento interno en bytes (máscaras/métodos core intactos).
// Edición char-aware SOLO para texto libre: cType=="C" y sin picture.
// Pictured/numéricos/fechas: comportamiento byte original verbatim.

#include 'inkey.ch'
#include 'getexit.ch'
#include 'setcurs.ch'
#include 'set.ch'
#include "button.ch"

static s_lInstalled := .F.
static s_bMouseRoute := NIL
static s_aMouseStash := {}   // FIFO { nKey, nRow, nCol, nSession }: ratón capturado en ventanas de animación
static s_nGuiSession := 0    // id de sesión modal (anidados); anti-entrega en modal equivocado

// índices de color del GET (copia de los #define locales de tget.prg)
#define GET_CLR_UNSELECTED      0
#define GET_CLR_ENHANCED        1
#define GET_CLR_CAPTION         2
#define GET_CLR_ACCEL           3

#define GETU_TEXT_MASK  0x7F000000
#define GETU_TEXT_BITS  0x43000000

// ---------------- helpers ----------------

function GetUIsText( oGet )
return oGet:cType == "C" .AND. Empty( oGet:cPicture )

// nº de carácter (1-based) que contiene el byte nB
function GetUCharIx( c, nB )
return hb_ULen( Left( c, nB - 1 ) ) + 1

// inicio (byte) del carácter que contiene el byte nB (walk acotado)
function GetUSnap( c, nB )
   local nS := 1, nNext
   if nB <= 1
      return 1
   endif
   do while nS < nB
      nNext := nS + Len( hb_USubStr( c, GetUCharIx( c, nS ), 1 ) )
      if nNext > nB .or. nNext > Len( c )
         exit
      endif
      nS := nNext
   enddo
return nS

// longitud en bytes del char que empieza en nB (nB ya en inicio)
function GetUCharLen( c, nB )
return Len( hb_USubStr( c, GetUCharIx( c, nB ), 1 ) )

// siguiente inicio de char tras nB (nB en inicio)
function GetUNext( c, nB )
return Min( nB + GetUCharLen( c, nB ), Len( c ) + 1 )

// inicio del char anterior a nB (nB en inicio)
function GetUPrev( c, nB )
   local nIx := GetUCharIx( c, nB )
   if nIx <= 1
      return 1
   endif
return nB - Len( hb_USubStr( c, nIx - 1, 1 ) )

// recorte por CELDAS desde el byte nDispPos (ya en inicio), máx nCells
function GetUCellSlice( c, nDispPos, nCells )
return hb_USubStr( c, GetUCharIx( c, nDispPos ), nCells )

// clamp a nMaxBytes sin partir el último char
function GetUClamp( c, nMaxBytes )
   do while Len( c ) > nMaxBytes
      c := hb_ULeft( c, hb_ULen( c ) - 1 )
   enddo
return c

// ---------------- TGet: insert ----------------

function GetUInsert( cChar )

   local Self := QSelf()
   local nFor
   local nMaxEdit
   local nCharLen

   if ::hasFocus .AND. HB_ISSTRING( cChar )

      if GetUIsText( Self )

         nMaxEdit := ::nMaxEdit
         cChar := hb_ULeft( cChar, 1 )           // primer CARÁCTER (no byte)
         nCharLen := Len( cChar )

         if cChar == ""
            ::rejected := .T.
         else
            ::rejected := .F.

            if ::lClear .AND. ::nPos == ::FirstEditable()
               ::DeleteAll()
               ::lClear := .F.
            endif

            ::lEdit := .T.

            if ::nPos == 0
               ::pos := 1
            else
               ::pos := GetUSnap( ::cBuffer, ::nPos )   // autocuración del invariante
            endif

            if Len( ::cBuffer ) + nCharLen > nMaxEdit
               // Solo cabe si lo expulsado por la cola es padding (espacios);
               // si hay contenido real, rechazo del char ENTERO (nunca parcial,
               // nunca pérdida silenciosa). Empty() sobre espacios ES lo buscado aquí.
               if Empty( Right( ::cBuffer, Len( ::cBuffer ) + nCharLen - nMaxEdit ) )
                  ::cBuffer := Left( Stuff( ::cBuffer, ::nPos, 0, cChar ), ::nMaxEdit )
                  ::lChanged := .T.
                  ::pos := ::nPos + nCharLen
                  if ::nPos > nMaxEdit
                     ::pos := nMaxEdit
                     ::typeOut := .T.
                  endif
               else
                  ::rejected := .T.
               endif
            else
               ::cBuffer := Stuff( ::cBuffer, ::nPos, 0, cChar )
               ::lChanged := .T.
               ::pos := ::nPos + nCharLen
               if ::nPos > nMaxEdit
                  ::pos := nMaxEdit
                  ::typeOut := .T.
               endif
            endif
         endif

      else
         // ---- cuerpo core verbatim (bytes; máscaras/numéricos) ----
         nMaxEdit := ::nMaxEdit

         if ::cType == "N" .AND. ! ::lEdit .AND. ::lClear
            ::pos := ::FirstEditable()
         endif

         if ::nPos <= ::nMaxEdit

            cChar := ::Input( Left( cChar, 1 ) )

            if cChar == ""
               ::rejected := .T.
            else
               ::rejected := .F.

               if ::lClear .AND. ::nPos == ::FirstEditable()
                  ::DeleteAll()
                  ::lClear := .F.
               endif

               ::lEdit := .T.

               if ::nPos == 0
                  ::pos := 1
               endif

               do while ! ::IsEditable( ::nPos ) .AND. ::nPos <= ::nMaxEdit .AND. ! ::typeOut
                  ::pos++
               enddo

               if ::nPos > ::nMaxEdit
                  ::pos := ::FirstEditable()
               endif

               if ::lPicComplex
                  for nFor := ::nPos to nMaxEdit
                     if ! ::IsEditable( nFor )
                        exit
                     endif
                  next
                  nMaxEdit := nFor
                  ::cBuffer := Left( Stuff( Left( ::cBuffer, nMaxEdit - 2 ), ::nPos, 0, cChar ) + ;
                                     SubStr( ::cBuffer, nMaxEdit ), ::nMaxLen )
               else
                  ::cBuffer := Left( Stuff( ::cBuffer, ::nPos, 0, cChar ), ::nMaxEdit )
               endif

               ::lChanged := .T.

               ::rightLow()
            endif
         endif
      endif

      ::display()
   endif

return Self

// ---------------- TGet: overStrike ----------------

function GetUOverStrike( cChar )

   local Self := QSelf()
   local nCharLen
   local nOldLen

   if ::hasFocus .AND. HB_ISSTRING( cChar )

      if GetUIsText( Self )

         cChar := hb_ULeft( cChar, 1 )
         nCharLen := Len( cChar )

         if cChar == ""
            ::rejected := .T.
         else
            ::rejected := .F.

            if ::lClear .AND. ::nPos == ::FirstEditable()
               ::DeleteAll()
               ::lClear := .F.
            endif

            ::lEdit := .T.

            if ::nPos == 0
               ::pos := 1
            else
               ::pos := GetUSnap( ::cBuffer, ::nPos )
            endif

            nOldLen := GetUCharLen( ::cBuffer, ::nPos )

            if ::nPos + nCharLen - 1 > ::nMaxEdit
               ::rejected := .T.                        // no cabe entero: rechazar
            else
               ::cBuffer := Stuff( ::cBuffer, ::nPos, nOldLen, cChar )
               ::lChanged := .T.
               ::pos := Min( ::nPos + nCharLen, ::nMaxEdit + 1 )
               if ::nPos > ::nMaxEdit
                  ::typeOut := .T.
               endif
            endif
         endif

      else
         // ---- cuerpo core verbatim ----
         if ::cType == "N" .AND. ! ::lEdit .AND. ::lClear
            ::pos := ::FirstEditable()
         endif

         if ::pos <= ::nMaxEdit

            cChar := ::Input( Left( cChar, 1 ) )

            if cChar == ""
               ::rejected := .T.
            else
               ::rejected := .F.

               if ::lClear .AND. ::nPos == ::FirstEditable()
                  ::DeleteAll()
                  ::lClear := .F.
               endif

               ::lEdit := .T.

               if ::nPos == 0
                  ::pos := 1
               endif

               do while ! ::IsEditable( ::nPos ) .AND. ::nPos <= ::nMaxEdit .AND. ! ::typeOut
                  ::pos++
               enddo

               if ::nPos > ::nMaxEdit
                  ::pos := ::FirstEditable()
               endif
               ::cBuffer := Stuff( ::cBuffer, ::nPos, 1, cChar )

               ::lChanged := .T.

               ::rightLow()
            endif
         endif
      endif

      ::display()
   endif

return Self

// ---------------- TGet: rightLow / leftLow ----------------

function GetURightLow()

   local Self := QSelf()
   local nPos

   ::typeOut := .F.
   ::lClear  := .F.

   if ::nPos == ::nMaxEdit
      ::typeOut := .T.
      return .F.
   endif

   if GetUIsText( Self )
      ::pos := GetUSnap( ::cBuffer, ::nPos )      // autocuración
      nPos := GetUNext( ::cBuffer, ::nPos )
   else
      nPos := ::nPos + 1
   endif

   do while ! ::IsEditable( nPos ) .AND. nPos <= ::nMaxEdit
      nPos++
   enddo

   if nPos <= ::nMaxEdit
      ::pos := nPos
   else
      ::typeOut := .T.
   endif

return .T.

function GetULeftLow()

   local Self := QSelf()
   local nPos

   ::typeOut := .F.
   ::lClear  := .F.

   if ::nPos == ::FirstEditable()
      ::typeOut := .T.
      return .F.
   endif

   if GetUIsText( Self )
      ::pos := GetUSnap( ::cBuffer, ::nPos )
      nPos := GetUPrev( ::cBuffer, ::nPos )
   else
      nPos := ::nPos - 1
   endif

   do while ! ::IsEditable( nPos ) .AND. nPos > 0
      nPos--
   enddo

   if nPos > 0
      ::pos := nPos
   else
      ::typeOut := .T.
   endif

return .T.

// ---------------- TGet: deleteLow ----------------

function GetUDeleteLow()

   local Self := QSelf()
   local nMaxLen := ::nMaxLen
   local n
   local nCharLen

   if GetUIsText( Self )
      ::lClear := .F.
      ::lEdit  := .T.

      ::pos := GetUSnap( ::cBuffer, ::nPos )
      nCharLen := GetUCharLen( ::cBuffer, ::nPos )

      // misma forma que el core: quitar el char y rellenar al final con
      // tantos espacios como bytes tenía (longitud de buffer estable)
      ::cBuffer := PadR( Stuff( ::cBuffer, ::nPos, nCharLen, "" ), ;
                         ::nMaxLen - nCharLen ) + Space( nCharLen )

      ::lChanged := .T.
      return nil
   endif

   // ---- cuerpo core verbatim ----
   ::lClear := .F.
   ::lEdit := .T.

   if ::lPicComplex
      for n := ::nPos to nMaxLen
         if ! ::IsEditable( n )
            exit
         endif
      next
      nMaxLen := n - 1
   endif

   if ::cType == "N" .AND. SubStr( ::cBuffer, ::nPos, 1 ) $ "(-"
      ::lMinus2 := .F.
   endif

   ::cBuffer := PadR( Stuff( Stuff( ::cBuffer, ::nPos, 1, "" ), nMaxLen, 0, " " ), ;
                      ::nMaxLen )

   ::lChanged := .T.

return nil

// ---------------- TGet: display ----------------

function GetUDisplay()

   local Self := QSelf()
   local nOldCursor := SetCursor( SC_NONE )
   local cBuffer
   local nDispPos
   local nRowPos
   local nColPos
   local nPos
   local cCaption
   local cVisible
   local nCellsBefore

   if ::hasFocus
      cBuffer := ::cBuffer
   else
      ::cType   := ValType( ::xVarGet := ::varGet() )
      ::picture := ::cPicture
      cBuffer   := ::PutMask( ::xVarGet )
   endif

   ::nMaxLen := Len( cBuffer )
   ::nDispLen := iif( ::nPicLen == NIL, ::nMaxLen, ::nPicLen )

   if ::cType == "N" .AND. ::hasFocus .AND. ! ::lMinusPrinted .AND. ;
      ::decPos != 0 .AND. ::lMinus2 .AND. ;
      ::nPos > ::decPos .AND. Val( Left( cBuffer, ::decPos - 1 ) ) == 0
      cBuffer := Stuff( cBuffer, ::decPos - 1, 2, "-." )
   endif

   if ::nDispLen != ::nMaxLen .AND. ::nPos != 0 /* has scroll? */
      if ::nDispLen > 8
         nDispPos := Max( 1, Min( ::nPos - ::nDispLen + 4       , ::nMaxLen - ::nDispLen + 1 ) )
      else
         nDispPos := Max( 1, Min( ::nPos - Int( ::nDispLen / 2 ), ::nMaxLen - ::nDispLen + 1 ) )
      endif
   else
      nDispPos := 1
   endif

   // caption C5.3 (byte-ops: captions con acentos + '&' quedan como en core;
   // es comportamiento existente, no lo empeora este parche)
   if ! Empty( ::cCaption )
      cCaption := ::cCaption
      if ( nPos := At( "&", cCaption ) ) > 0
         if nPos == Len( cCaption )
            nPos := 0
         else
            cCaption := Stuff( cCaption, nPos, 1, "" )
         endif
      endif

      hb_DispOutAt( ::nCapRow, ::nCapCol, cCaption, hb_ColorIndex( ::cColorSpec, GET_CLR_CAPTION ) )
      if nPos > 0
         hb_DispOutAt( ::nCapRow, ::nCapCol + nPos - 1, SubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, GET_CLR_ACCEL ) )
      endif
   endif

   // Display del GET
   if GetUIsText( Self ) .AND. ::hasFocus
      // snap a inicio de char + recorte por CELDAS (nunca secuencia partida)
      nDispPos := GetUSnap( cBuffer, Max( nDispPos, 1 ) )
      cVisible := GetUCellSlice( cBuffer, nDispPos, ::nDispLen )

      if ! ::lSuppDisplay .OR. nDispPos != ::nOldPos
         hb_DispOutAt( ::nRow, ::nCol, ;
                       iif( ::lHideInput, PadR( Replicate( Left( ::cStyle, 1 ), hb_ULen( RTrim( cBuffer ) ) ), ::nDispLen ), cVisible ), ;
                       hb_ColorIndex( ::cColorSpec, GET_CLR_ENHANCED ) )

         nRowPos := ::nRow
         nColPos := ::nCol + Min( ::nDispLen, hb_ULen( cBuffer ) )

         if Set( _SET_DELIMITERS )
            hb_DispOutAt( nRowPos, ::nCol - 1, SubStr( Set( _SET_DELIMCHARS ), 1, 1 ), hb_ColorIndex( ::cColorSpec, GET_CLR_UNSELECTED ) )
            hb_DispOutAt( nRowPos, nColPos   , SubStr( Set( _SET_DELIMCHARS ), 2, 1 ), hb_ColorIndex( ::cColorSpec, GET_CLR_UNSELECTED ) )
            ++nColPos
         endif
      endif

      if ::nPos != 0
         nCellsBefore := GetUCharIx( cBuffer, GetUSnap( cBuffer, ::nPos ) ) - GetUCharIx( cBuffer, nDispPos )
         SetPos( ::nRow, ::nCol + nCellsBefore )
      elseif nRowPos != NIL
         SetPos( nRowPos, nColPos )
      endif
   else
      // ---- path core verbatim (no-texto o sin foco) ----
      if ! ::lSuppDisplay .OR. nDispPos != ::nOldPos
         hb_DispOutAt( ::nRow, ::nCol, ;
                       iif( ::lHideInput, PadR( Replicate( Left( ::cStyle, 1 ), Len( RTrim( cBuffer ) ) ), ::nDispLen ), SubStr( cBuffer, nDispPos, ::nDispLen ) ), ;
                       hb_ColorIndex( ::cColorSpec, iif( ::hasFocus, GET_CLR_ENHANCED, GET_CLR_UNSELECTED ) ) )

         nRowPos := ::nRow
         nColPos := ::nCol + Min( ::nDispLen, Len( cBuffer ) )

         if Set( _SET_DELIMITERS ) .AND. ! ::hasFocus
            hb_DispOutAt( nRowPos, ::nCol - 1, SubStr( Set( _SET_DELIMCHARS ), 1, 1 ), hb_ColorIndex( ::cColorSpec, GET_CLR_UNSELECTED ) )
            hb_DispOutAt( nRowPos, nColPos   , SubStr( Set( _SET_DELIMCHARS ), 2, 1 ), hb_ColorIndex( ::cColorSpec, GET_CLR_UNSELECTED ) )
            ++nColPos
         endif
      endif

      if ::nPos != 0
         SetPos( ::nRow, ::nCol + ::nPos - nDispPos )
      elseif nRowPos != NIL
         SetPos( nRowPos, nColPos )
      endif
   endif

   ::nOldPos := nDispPos
   ::lSuppDisplay := .F.

   SetCursor( nOldCursor )

return Self

// ---------------- HBGetList: Reader ----------------
// Copia del Reader core (rama HB_COMPAT_C53, la compilada en este Harbour)
// con dos cambios marcados (1)(2). Todo lo demás, verbatim.

function GetUReader( oMenu, aMsg )

   local Self := QSelf()
   local oGet := ::oGet
   local nRow
   local nCol
   local nOldCursor
   local nKey
   local cKey
   local bKeyBlock

   if ::nLastExitState == GE_SHORTCUT .OR. ;
      ::nLastExitState == GE_MOUSEHIT .OR. ;
      ::GetPreValidate( oGet, aMsg )

      ::ShowGetMsg( oGet, aMsg )

      ::nHitCode := 0
      ::nLastExitState := 0
      oGet:setFocus()

      do while oGet:exitState == GE_NOEXIT .AND. ! ::lKillRead
         if oGet:typeOut
            oGet:exitState := GE_ENTER
         endif

         do while oGet:exitState == GE_NOEXIT .AND. ! ::lKillRead
            SetCursor( iif( ::nSaveCursor == SC_NONE, SC_NORMAL, ::nSaveCursor ) )
            // (1) misma CLASE de eventos (Set(_SET_EVENTMASK)) + formato EXT;
            //     + clases de ratón SOLO si hay ruta instalada (contrato diseñador:
            //     128 + LDOWN(2) + LUP(4) + EXT(2048); SIN MOVE(1) anti-flood).
            //     OJO: la suma real es 2182; su "2178" excluiría LUP (sin release
            //     no hay clic completo) - confirmado por main como 2182 salvo corrección.
            if s_bMouseRoute != NIL
               nKey := Inkey( 0, hb_bitOr( Set( _SET_EVENTMASK ), HB_INKEY_EXT, 2 + 4 ) )
            else
               nKey := Inkey( 0, hb_bitOr( Set( _SET_EVENTMASK ), HB_INKEY_EXT ) )
            endif
            SetCursor( SC_NONE )

            // (1b) clase ratón (0x44/0x45): SIEMPRE consumida, NUNCA texto.
            //      Con ruta: se despacha con coordenadas legibles vía MRow()/MCol().
            if hb_bitand( nKey, 0x7F000000 ) == 0x44000000 .OR. ;
               hb_bitand( nKey, 0x7F000000 ) == 0x45000000
               if s_bMouseRoute != NIL
                  Eval( s_bMouseRoute, nKey, oGet, MRow(), MCol() )
               endif
               loop
            endif

            // (2) texto Unicode: hb_keyChar del evento crudo; resto: hb_keyStd
            if hb_bitand( nKey, GETU_TEXT_MASK ) == GETU_TEXT_BITS
               if ( bKeyBlock := SetKey( hb_keyStd( nKey ) ) ) != NIL
                  ::GetApplyKey( hb_keyStd( nKey ), oGet, oMenu, aMsg )
               else
                  cKey := hb_keyChar( nKey )
                  if ! ( cKey == "" )   // OJO: Empty(" ")==.T. se tragaria el espacio
                     if oGet:type == "N" .AND. ( cKey == "." .OR. cKey == "," )
                        oGet:toDecPos()
                     else
                        if Set( _SET_INSERT )
                           oGet:insert( cKey )
                        else
                           oGet:overStrike( cKey )
                        endif

                        if oGet:typeOut
                           if Set( _SET_BELL )
                              QQOut( Chr( 7 ) )
                           endif
                           if ! Set( _SET_CONFIRM )
                              oGet:exitState := GE_ENTER
                           endif
                        endif
                     endif
                  endif
               endif
            else
               ::GetApplyKey( hb_keyStd( nKey ), oGet, oMenu, aMsg )
            endif

            nRow := Row()
            nCol := Col()
            ::ShowGetMsg( oGet, aMsg )
            SetPos( nRow, nCol )
         enddo

         if ! ::nLastExitState == GE_SHORTCUT .AND. ;
            ! ::nLastExitState == GE_MOUSEHIT .AND. ;
            ! ::GetPostValidate( oGet, aMsg )
            oGet:exitState := GE_NOEXIT
         endif
      enddo

      nRow := Row()
      nCol := Col()
      nOldCursor := SetCursor()
      oGet:killFocus()
      SetCursor( nOldCursor )
      SetPos( nRow, nCol )

      ::EraseGetMsg( aMsg )
   endif

return Self




// ---------------------------------------------------------------------------
// GetUGUIReader - reemplazo de HBGetList:GUIReader (controles GUI C53:
// checkbox/radiogroup/listbox/pushbtn). MISMO contrato que GetUReader:
// máscara Set(_SET_EVENTMASK)+HB_INKEY_EXT (+LDOWN 2 +LUP 4 solo con ruta),
// clases de ratón 0x44/0x45 SIEMPRE consumidas y despachadas a la ruta ANTES
// de GUIApplyKey, y normalización hb_keyStd del resto (códigos clásicos
// idénticos a los de hoy para flechas/ENTER/ESPACIO/aceleradores).
//
// OJO de scope: la vía C53 invoca GUIReader desde un BLOQUE oGet:reader
// (capturado en código de aplicación) -> proc plano GUIREADER de getsys53 ->
// envío de método. En esa cadena el emisor no es un método de HBGetList y el
// chequeo de PROTECTED contra el frame emisor FALLA (BASE/1003) aunque Self
// sea correcto (probado en vivo: QSelf():ClassName()="HBGETLIST" y
// ::nHitCode BASE/1003). Por eso el método instalado es un shell fino que
// pasa Self como PARÁMETRO a GetUGUIReaderImpl, función FRIEND registrada:
// el acceso oGL:<ivar protegido> desde friend sí pasa (mismo patrón que los
// helpers GetU* sobre la clase Get).
// Alcance auditado: cubre SOLO el bucle GUIReader; DateMsg (:810) y
// TBReader (:1365/1369) NO cambian (ver informe a main).
// ---------------------------------------------------------------------------

function GetUGUIReader( oGet, oMenu, aMsg )
return GetUGUIReaderImpl( QSelf(), oGet, oMenu, aMsg )

function GetUGUIReaderImpl( oGL, oGet, oMenu, aMsg )

   local oGUI
   local nKey

   s_nGuiSession++
   // Política segura anti doble-submit: los gestos conservados pertenecen a la
   // ACTIVACIÓN que los capturó. Al activarse otro control o abrirse un modal
   // hijo, cualquier gesto pendiente de la activación anterior se DESCARTA:
   // solo se despacha lo capturado dentro de esta misma activación.
   s_aMouseStash := {}

   if HB_ISOBJECT( oGet:control ) .AND. ;
      oGL:nLastExitState == GE_SHORTCUT .OR. ;
      oGL:nLastExitState == GE_MOUSEHIT .OR. ;
      oGL:GetPreValidate( oGet, aMsg )

      oGL:ShowGetMsg( oGet, aMsg )

      oGL:nLastExitState := 0

      // Activate the GET for reading
      oGUI := oGet:control
      oGUI:Select( oGet:varGet() )
      oGUI:setFocus()

      if oGet:exitState == GE_NOEXIT  // Added.
         do case
         case oGL:nHitCode > 0
            oGUI:Select( oGL:nHitCode )
         case oGL:nHitCode == HTCAPTION
            oGUI:Select()
         case oGL:nHitCode == HTCLIENT
            oGUI:Select( K_LBUTTONDOWN )
         case oGL:nHitCode == HTDROPBUTTON
            oGUI:Open()
         case oGL:nHitCode >= HTSCROLLFIRST .AND. ;
              oGL:nHitCode <= HTSCROLLLAST
            oGUI:Scroll( oGL:nHitCode )
         endcase
      endif

      oGL:nHitCode := 0

      do while oGet:exitState == GE_NOEXIT .AND. ! oGL:lKillRead

         // Check for initial typeout (no editable positions)
         if oGUI:typeOut
            oGet:exitState := GE_ENTER
         endif

         // Apply keystrokes until exit
         do while oGet:exitState == GE_NOEXIT .AND. ! oGL:lKillRead
            // ratón conservado por animaciones de Select: FIFO, solo ESTA sesión
            do while len( s_aMouseStash ) > 0 .AND. s_aMouseStash[ 1 ][ 4 ] == s_nGuiSession
               if s_bMouseRoute != NIL
                  Eval( s_bMouseRoute, hb_bitOr( 0x44000000, s_aMouseStash[ 1 ][ 1 ] ), oGet, s_aMouseStash[ 1 ][ 2 ], s_aMouseStash[ 1 ][ 3 ] )
               endif
               hb_ADel( s_aMouseStash, 1, .T. )
            enddo
            // mismo contrato de máscara que GetUReader
            if s_bMouseRoute != NIL
               nKey := Inkey( 0, hb_bitOr( Set( _SET_EVENTMASK ), HB_INKEY_EXT, 2 + 4 ) )
            else
               nKey := Inkey( 0, hb_bitOr( Set( _SET_EVENTMASK ), HB_INKEY_EXT ) )
            endif

            // clase ratón (0x44/0x45): SIEMPRE consumida, NUNCA tecla
            if hb_bitand( nKey, 0x7F000000 ) == 0x44000000 .OR. ;
               hb_bitand( nKey, 0x7F000000 ) == 0x45000000
               if s_bMouseRoute != NIL
                  Eval( s_bMouseRoute, nKey, oGet, MRow(), MCol() )
               endif
               loop
            endif

            // hb_keyStd: flechas/ENTER/ESPACIO/aceleradores llegan a
            // GUIApplyKey con los mismos códigos clásicos que hoy
            oGL:GUIApplyKey( oGet, oGUI, hb_keyStd( nKey ), oMenu, aMsg )

            oGL:ShowGetMsg( oGet, aMsg )
         enddo

         if oGL:nLastExitState != GE_SHORTCUT .AND. ;
            oGL:nLastExitState != GE_MOUSEHIT .AND. ;
            ! oGL:GetPostValidate( oGet, aMsg )
            oGet:exitState := GE_NOEXIT
         endif
      enddo

      // De-activate the GET
      switch oGUI:ClassName()
      case "LISTBOX"
      case "RADIOGROUP"
         if HB_ISNUMERIC( oGet:varGet() )
            oGet:varPut( oGUI:value )
            exit
         endif
         /* fallthrough */
      otherwise
         oGet:varPut( oGUI:buffer )
      endswitch
      oGUI:killFocus()

      oGL:EraseGetMsg( aMsg )

      if oGUI:ClassName() == "LISTBOX" .AND. ;
         oGUI:dropDown .AND. ;
         oGUI:isOpen

         oGUI:Close()
      endif

   endif

   s_nGuiSession--
   GetUPurgeStash()

return oGL

// ---------------------------------------------------------------------------
// INTERFAZ PÚBLICA (acordada con el diseñador vía main)
// ---------------------------------------------------------------------------

// SetGetUMouseRoute( bNew ) -> bPrev
// Instala la ruta de ratón para READs y devuelve la previa (para diálogos
// anidados: guardar al abrir, restaurar al cerrar - NUNCA borrar a ciegas).
// bNew: {| nKey, oGet | ... } debe devolver .T. si consumió; NIL = sin ruta
// (máscara 128+EXT = comportamiento de hoy, puente ReadMouse intacto).
function SetGetUMouseRoute( bNew )
   local bPrev := s_bMouseRoute
   s_bMouseRoute := bNew
return bPrev

// DsnGetUInstall() - instalador COMPLETO e IDEMPOTENTE.
// OJO: no basta con instalar READER; los 6 reemplazos de la clase Get
// (RightLow/LeftLow/Insert/OverStrike/DeleteLow/Display) y los friends son
// los que hacen posible la edición UTF8 char-wise (cursor, borrado entero,
// display por celdas). Instalar solo el Reader perdería las mejoras UTF8.

// ---------------------------------------------------------------------------
// PushButton:Select shadow (animacion que NO drena eventos ajenos).
// Replica exacta del Select del core (pushbtn.prg:126-160) salvo los bucles
// de espera: el stock DESCARTA el primer evento distinto que cierra el bucle;
// esta version lo REINYECTA con hb_keyIns (cabeza de cola: orden preservado,
// una sola reinyeccion por evento, sin duplicar; 0=timeout sale sin tocar).
// Todo lo que toca (hasFocus/buffer/sBlock/setFocus/display) es EXPORTED.
// ---------------------------------------------------------------------------

// Ratón dentro de ventana de animación: hb_keyIns NO reencola ratón (probado),
// así que se conserva en cola propia con coordenadas AL CAPTURAR y sesión modal.
function GetUStashMouse( nKey )

   if nKey >= K_MOUSEMOVE .AND. nKey <= K_MWBACKWARD
      aadd( s_aMouseStash, { nKey, MRow(), MCol(), s_nGuiSession } )
      return .T.
   endif

   return .F.

function GetUPurgeStash()

   local i := len( s_aMouseStash )

   do while i >= 1
      if s_aMouseStash[ i ][ 4 ] > s_nGuiSession
         hb_ADel( s_aMouseStash, i, .T. )
      endif
      i--
   enddo

   return nil

function GetUPBSelect( nPos )

   return GetUPBSelectImpl( QSelf(), nPos )

function GetUPBSelectImpl( oPB, nPos )

   local nNext, nFirst

   if oPB:lHasFocus
      oPB:lBuffer := .T.
      oPB:display()

      if HB_ISNUMERIC( nPos )
         if nPos == K_SPACE
            nFirst := Inkey( 0.4, hb_bitOr( Set( _SET_EVENTMASK ), INKEY_MOVE + INKEY_LDOWN + INKEY_LUP + INKEY_RDOWN + INKEY_RUP + INKEY_MMIDDLE + INKEY_MWHEEL ) )
            if nFirst != 0 .AND. nFirst != K_SPACE
               if ! GetUStashMouse( nFirst )
                  hb_keyIns( nFirst )
               endif
            endif
            do while .T.
               nNext := Inkey( 0.1, hb_bitOr( Set( _SET_EVENTMASK ), INKEY_MOVE + INKEY_LDOWN + INKEY_LUP + INKEY_RDOWN + INKEY_RUP + INKEY_MMIDDLE + INKEY_MWHEEL ) )
               if nNext == K_SPACE
                  loop
               endif
               if nNext != 0
                  if ! GetUStashMouse( nNext )
                     hb_keyIns( nNext )
                  endif
               endif
               exit
            enddo
         else
            do while .T.
               nNext := Inkey( 0, hb_bitOr( Set( _SET_EVENTMASK ), INKEY_MOVE + INKEY_LDOWN + INKEY_LUP + INKEY_RDOWN + INKEY_RUP + INKEY_MMIDDLE + INKEY_MWHEEL ) )
               if nNext == nPos
                  loop
               endif
               if nNext != 0
                  if ! GetUStashMouse( nNext )
                     hb_keyIns( nNext )
                  endif
               endif
               exit
            enddo
         endif
      endif

      if HB_ISEVALITEM( oPB:bSBlock )
         Eval( oPB:bSBlock )
      endif

      oPB:lBuffer := .F.
      oPB:display()
   endif

   return oPB

procedure DsnGetUInstall()
   if s_lInstalled
      return
   endif
   s_lInstalled := .T.
   __ClsModMsg( GetNew():ClassH, "RIGHTLOW", @GetURightLow() )
   __ClsModMsg( GetNew():ClassH, "LEFTLOW", @GetULeftLow() )
   __ClsModMsg( GetNew():ClassH, "INSERT", @GetUInsert() )
   __ClsModMsg( GetNew():ClassH, "OVERSTRIKE", @GetUOverStrike() )
   __ClsModMsg( GetNew():ClassH, "DELETELOW", @GetUDeleteLow() )
   __ClsModMsg( GetNew():ClassH, "DISPLAY", @GetUDisplay() )
   __ClsModMsg( HBGetList():New( {} ):ClassH, "READER", @GetUReader() )
   __ClsModMsg( HBGetList():New( {} ):ClassH, "GUIREADER", @GetUGUIReader() )
   __ClsModMsg( PushButton():New( 0, 0, "" ):ClassH, "SELECT", @GetUPBSelect() )
   __ClsAddFriend( PushButton():New( 0, 0, "" ):ClassH, __dynsN2Sym( "GETUPBSELECTIMPL" ) )
   __ClsAddFriend( HBGetList():New( {} ):ClassH, __dynsN2Sym( "GETUGUIREADERIMPL" ) )
   GetUFriends( GetNew():ClassH )
   return

// Los helpers se llaman como funciones planas (sin Self en pila), así que el
// chequeo de ámbito PROTECTED de la VM exige registrarlos como "friends" de la
// clase Get (__ClsAddFriend -> hb_clsAddFriendSymbol; ver hb_clsValidScope en
// classes.c). Sin esto: Error BASE/42 Scope violation (protected) GET:CTYPE.
procedure GetUFriends( hClass )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUISTEXT" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUCHARIX" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUSNAP" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUCHARLEN" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUNEXT" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUPREV" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUCELLSLICE" ) )
   __ClsAddFriend( hClass, __dynsN2Sym( "GETUCLAMP" ) )
   return

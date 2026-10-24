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

static s_lInstalled := .F.
static s_bMouseRoute := NIL

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
                  Eval( s_bMouseRoute, nKey, oGet )
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

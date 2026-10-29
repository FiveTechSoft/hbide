// Unicode scalar-value validation, independent of the display codepage.
#include "hbclass.ch"
PROCEDURE Main()
   LOCAL aCases := { ;
      { 'ASCII', 'abc' + Chr( 0 ) + 'xyz', .T. }, ;
      { 'empty', '', .T. }, ;
      { 'U+0080', Bytes( { 0xC2, 0x80 } ), .T. }, ;
      { 'U+07FF', Bytes( { 0xDF, 0xBF } ), .T. }, ;
      { 'U+0800', Bytes( { 0xE0, 0xA0, 0x80 } ), .T. }, ;
      { 'U+D7FF', Bytes( { 0xED, 0x9F, 0xBF } ), .T. }, ;
      { 'U+E000', Bytes( { 0xEE, 0x80, 0x80 } ), .T. }, ;
      { 'U+FFFF noncharacter still scalar', Bytes( { 0xEF, 0xBF, 0xBF } ), .T. }, ;
      { 'U+10000', Bytes( { 0xF0, 0x90, 0x80, 0x80 } ), .T. }, ;
      { 'U+10FFFF', Bytes( { 0xF4, 0x8F, 0xBF, 0xBF } ), .T. }, ;
      { 'lone continuation', Bytes( { 0x80 } ), .F. }, ;
      { 'two-byte overlong NUL', Bytes( { 0xC0, 0x80 } ), .F. }, ;
      { 'two-byte overlong ASCII', Bytes( { 0xC1, 0xBF } ), .F. }, ;
      { 'three-byte overlong NUL', Bytes( { 0xE0, 0x80, 0x80 } ), .F. }, ;
      { 'three-byte overlong U+07FF', Bytes( { 0xE0, 0x9F, 0xBF } ), .F. }, ;
      { 'surrogate start', Bytes( { 0xED, 0xA0, 0x80 } ), .F. }, ;
      { 'surrogate end', Bytes( { 0xED, 0xBF, 0xBF } ), .F. }, ;
      { 'four-byte overlong', Bytes( { 0xF0, 0x8F, 0xBF, 0xBF } ), .F. }, ;
      { 'above Unicode maximum', Bytes( { 0xF4, 0x90, 0x80, 0x80 } ), .F. }, ;
      { 'invalid lead', Bytes( { 0xF5, 0x80, 0x80, 0x80 } ), .F. }, ;
      { 'truncated', Bytes( { 0xF0, 0x90, 0x80 } ), .F. }, ;
      { 'noncontinuation tail', Bytes( { 0xE2, 0x82, 0x41 } ), .F. } }
   LOCAL aCase, nFail := 0, oEdit, cFile, lOk, cCP, nChecks := Len( aCases )
   FOR EACH aCase IN aCases
      IF HBIDE_Utf8Valid( aCase[ 2 ] ) == aCase[ 3 ]
         ? 'PASS:', aCase[ 1 ]
      ELSE
         ? 'FAIL:', aCase[ 1 ]
         nFail++
      ENDIF
   NEXT
   FOR EACH cCP IN { "EN", "UTF8" }
      hb_cdpSelect( cCP )
      FOR EACH aCase IN aCases
         lOk := HBIDE_IsUtf8( aCase[ 2 ] ) == ( aCase[ 3 ] .and. ;
            aCase[ 1 ] != 'ASCII' .and. aCase[ 1 ] != 'empty' )
         nChecks++
         nFail += iif( lOk, 0, 1 )
         ? iif( lOk, 'PASS:', 'FAIL:' ), 'detection under', cCP, aCase[ 1 ]
      NEXT
   NEXT
   hb_cdpSelect( "EN" )
   cFile := hb_DirTemp() + 'hbide-utf8-' + hb_ntos( hb_RandomInt( 999999999 ) ) + '.prg'
   oEdit := HBSrcEdit():New( '', 2, 1, 20, 79, .T. )
   oEdit:cFile := cFile
   oEdit:lUtf8Raw := .T.
   FOR EACH aCase IN aCases
      IF ! aCase[ 3 ]
         hb_MemoWrit( cFile, 'ORIGINAL' )
         oEdit:LoadText( aCase[ 2 ] )
         oEdit:SetDirty( .T. )
         lOk := ! oEdit:SaveFile() .and. hb_MemoRead( cFile ) == 'ORIGINAL' .and. oEdit:Changed()
         nChecks++
         IF lOk
            ? 'PASS: raw save refused, original and dirty state retained:', aCase[ 1 ]
         ELSE
            ? 'FAIL: raw save guard:', aCase[ 1 ]
            nFail++
         ENDIF
      ENDIF
   NEXT
   FErase( cFile )
   ? 'TOTAL', nChecks - nFail, 'PASS', nFail, 'FAIL' 
   ErrorLevel( iif( nFail == 0, 0, 1 ) )
   RETURN
STATIC FUNCTION Bytes( aBytes )
   LOCAL c := '', n
   FOR EACH n IN aBytes
      c += hb_BChar( n )
   NEXT
   RETURN c
FUNCTION HBIDE_MsgAlert( cText )
   HB_SYMBOL_UNUSED( cText )
   RETURN 1

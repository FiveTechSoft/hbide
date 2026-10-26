#include "directry.ch"

// P0: visible recovery of unsaved buffers (ROADMAP "Recuperacion visible").
//
// While a buffer is dirty, the IDE keeps a journal of its full text in a
// central recovery dir (never next to the file, so repos stay clean and
// nothing journal-like can be committed by accident). The journal is
// deleted on a successful save and on an explicit discard. A journal that
// survives means the previous session ended with neither (crash, kill,
// power), so on start the IDE lists every survivor and offers Recover /
// Discard / Later for each one.
//
// Layout per buffer: <key>.journal (raw editor text, byte-exact round trip
// through GetText()/LoadText()) and <key>.target (the buffer's file name,
// or "noname.prg" for the untitled buffer). <key> is an escaped form of the
// absolute target path, stable across sessions and unique per file.

//-----------------------------------------------------------------------------------------//

// Recovery dir: HBIDE_RECOVERY_DIR wins (tests), else ~/.hbide/recovery
// (USERPROFILE on Windows). Created on demand.
function HBIDE_RecoveryDir()

   local cDir := GetEnv( "HBIDE_RECOVERY_DIR" )

   if Empty( cDir )
      cDir := GetEnv( "HOME" )
      if Empty( cDir )
         cDir := GetEnv( "USERPROFILE" )
      endif
      cDir := hb_FNameMerge( cDir, ".hbide", "recovery" )
   endif
   if ! hb_DirExists( cDir )
      hb_DirBuild( cDir )
   endif

return cDir

//-----------------------------------------------------------------------------------------//

// Absolute normalized form of the buffer's file name, so the same file maps
// to the same journal whether it was opened as "foo.prg" or "/full/foo.prg".
function HBIDE_RecoveryAbs( cFile )

   local lAbs := Left( cFile, 1 ) $ "/\" .or. ;
                 ( Len( cFile ) >= 2 .and. SubStr( cFile, 2, 1 ) == ":" .and. ;
                   IsAlpha( Left( cFile, 1 ) ) )

   if lAbs
      return hb_PathNormalize( cFile )
   endif

return hb_PathNormalize( hb_FNameMerge( hb_cwd(), cFile ) )

//-----------------------------------------------------------------------------------------//

// Stable, collision-free journal key for a buffer. The untitled buffer gets
// the fixed key "noname". Every char outside [A-Za-z0-9-.] escapes as "_" +
// hex, including "_" itself, so distinct paths can never collide.
function HBIDE_RecoveryKey( cFile )

   local cAbs, cKey := "", n, c

   hb_defaultValue( cFile, "" )
   cAbs := iif( Empty( cFile ) .or. cFile == "noname.prg", "noname", ;
                HBIDE_RecoveryAbs( cFile ) )

   for n := 1 to Len( cAbs )
      c := SubStr( cAbs, n, 1 )
      if IsAlpha( c ) .or. IsDigit( c ) .or. c $ "-."
         cKey += c
      else
         cKey += "_" + hb_StrToHex( c )
      endif
   next

return cKey

//-----------------------------------------------------------------------------------------//

// The write is failure-tolerant by contract: a journal that cannot be
// written (disk full, permissions, crash mid-write) must never interrupt
// editing. Both files go through <name>.tmp + rename, so a crash can leave
// at worst an inert .tmp, never a torn .journal that would be offered back.
// Order matters: the .target sidecar lands first, so a crash between the two
// renames leaves an orphan sidecar (inert) rather than a journal without a
// known target.
function HBIDE_RecoveryWrite( cKey, cTarget, cContent )

   local cDir := HBIDE_RecoveryDir()
   local lOk := .F.

   hb_defaultValue( cTarget, "noname.prg" )

   begin sequence
      lOk := HBIDE_AtomicPair( hb_FNameMerge( cDir, cKey, ".target" ), cTarget ) .and. ;
             HBIDE_AtomicPair( hb_FNameMerge( cDir, cKey, ".journal" ), cContent )
   recover
      lOk := .F.
   end sequence

return lOk

// One tmp+rename file write. Returns .T. only when the final name holds the
// full content. Never raises.
static function HBIDE_AtomicPair( cName, cContent )

   local cTmp := cName + ".tmp"
   local lOk

   begin sequence
      lOk := hb_MemoWrit( cTmp, cContent )
      if lOk
         lOk := FRename( cTmp, cName ) == 0
         if ! lOk
            FErase( cTmp )
         endif
      else
         FErase( cTmp )
      endif
   recover
      lOk := .F.
   end sequence

return lOk

//-----------------------------------------------------------------------------------------//

function HBIDE_RecoveryRead( cKey )

   local cOut := ""

   begin sequence
      cOut := hb_MemoRead( hb_FNameMerge( HBIDE_RecoveryDir(), cKey, ".journal" ) )
   recover
      cOut := ""
   end sequence

return cOut

//-----------------------------------------------------------------------------------------//

function HBIDE_RecoveryDelete( cKey )

   local cDir := HBIDE_RecoveryDir()

   begin sequence
      FErase( hb_FNameMerge( cDir, cKey, ".journal" ) )
      FErase( hb_FNameMerge( cDir, cKey, ".target" ) )
      FErase( hb_FNameMerge( cDir, cKey, ".journal" ) + ".tmp" )
      FErase( hb_FNameMerge( cDir, cKey, ".target" ) + ".tmp" )
   end sequence

return nil

//-----------------------------------------------------------------------------------------//

// Surviving journals: { { cKey, cTarget, nSize, cStamp }, ... }.
// cStamp is the journal's mtime, for the prompt.
function HBIDE_RecoveryScan()

   local cDir := HBIDE_RecoveryDir()
   local aOut := {}, aFile, cKey, cTarget, aList

   begin sequence
      aList := Directory( hb_FNameMerge( cDir, "*.journal" ) )
   recover
      aList := {}
   end sequence

   for each aFile in aList
      if "D" $ aFile[ F_ATTR ]
         loop
      endif
      cKey := Left( aFile[ F_NAME ], Len( aFile[ F_NAME ] ) - Len( ".journal" ) )
      cTarget := hb_MemoRead( hb_FNameMerge( cDir, cKey, ".target" ) )
      do while ! Empty( cTarget ) .and. Right( cTarget, 1 ) $ " " + Chr( 13 ) + Chr( 10 )
         cTarget := Left( cTarget, Len( cTarget ) - 1 )
      enddo
      AAdd( aOut, { cKey, cTarget, aFile[ F_SIZE ], ;
                    DToC( aFile[ F_DATE ] ) + " " + aFile[ F_TIME ] } )
   next

return aOut

//-----------------------------------------------------------------------------------------//

#include "directry.ch"
#include "fileio.ch"

static s_cSession := ""
static s_nRecoveryLock := -1

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
// Layout per buffer: <key>--<session>.journal (legacy raw editor text, or
// versioned encoding flags/codepage + editor bytes in one atomic generation) and <key>--<session>.target (the buffer's file name,
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
      cDir := hb_DirSepAdd( cDir ) + ".hbide" + hb_ps() + "recovery"
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

// Session id: unique per IDE process start. It scopes every journal name so
// that two instances editing the same file keep separate journals and a save
// or discard in one instance can never delete another instance's unsaved
// work. HBIDE_RECOVERY_SESSION overrides it (tests).
function HBIDE_RecoverySession()

   local cEnv := GetEnv( "HBIDE_RECOVERY_SESSION" )

   if ! Empty( cEnv )
      return cEnv
   endif
   if Empty( s_cSession )
      s_cSession := hb_TToS( hb_DateTime() ) + "_" + StrZero( hb_randomInt( 999999 ), 6 )
   endif

return s_cSession

//-----------------------------------------------------------------------------------------//

// Keep an OS file lock for the lifetime of the process. The OS releases
// it on crash/kill, so startup can distinguish live sessions from survivors.
function HBIDE_RecoveryOwnSession()
   local cLock
   if s_nRecoveryLock < 0
      cLock := hb_FNameMerge( HBIDE_RecoveryDir(), HBIDE_RecoverySession(), ".lock" )
      s_nRecoveryLock := FCreate( cLock )
      if s_nRecoveryLock >= 0 .and. ! hb_FLock( s_nRecoveryLock, 0, 1, HB_FLX_EXCLUSIVE + HB_FLX_NO_WAIT )
         FClose( s_nRecoveryLock )
         s_nRecoveryLock := -1
      endif
   endif
return s_nRecoveryLock >= 0

function HBIDE_RecoveryLive( cBase )
   local nSplit := RAt( "--", cBase ), cLock, nHandle, lLive := .F.
   if nSplit > 0
      if SubStr( cBase, nSplit + 2 ) == HBIDE_RecoverySession()
         return .T.
      endif
      cLock := hb_FNameMerge( HBIDE_RecoveryDir(), SubStr( cBase, nSplit + 2 ), ".lock" )
      if File( cLock )
         nHandle := FOpen( cLock, FO_READWRITE + FO_SHARED )
         if nHandle < 0
            return .T. // cannot establish dead ownership: keep untouched
         endif
         lLive := ! hb_FLock( nHandle, 0, 1, HB_FLX_EXCLUSIVE + HB_FLX_NO_WAIT )
         FClose( nHandle )
      endif
   endif
return lLive

//-----------------------------------------------------------------------------------------//

// Stable journal key for a buffer. The untitled buffer gets the fixed key
// "noname". Every char outside [A-Za-z0-9-.] escapes as "_" + hex, including
// "_" itself, so distinct paths can never collide. The journal FILE is
// <key>--<session>.journal: the key identifies the buffer, the session
// identifies the owning instance. Long absolute paths would escape into keys
// that overflow the filename budget of the write pair (the atomic .tmp write
// hits Harbour's ~263-char internal path limit well before NAME_MAX), so a
// key longer than 120 chars is bounded to a readable 100-char prefix plus a
// dual 32-bit hash (FNV-1a + djb2, 16 hex chars) of the FULL absolute path.
// Short keys keep the exact collision-free form. Distinct long paths share
// a key only if BOTH hashes collide: two different 32-bit hashes of the same
// input are not independent, so no 2^-64 guarantee is claimed, but an
// accidental double collision is far less likely than with one hash. Long
// journals could never exist before (their writes always failed), so no
// stored key can change meaning. The bound covers the KEY only: an
// HBIDE_RECOVERY_DIR so long that even a bounded key overflows the path
// limit still cannot hold journals; writes then fail and the editor warns
// once per failing streak (support limit, not silent).
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

   if Len( cKey ) > 120
      cKey := Left( cKey, 100 ) + "_h" + HBIDE_KeyHash( cAbs )
   endif

return cKey

//-----------------------------------------------------------------------------------------//

// Dual 32-bit hash (FNV-1a + djb2) of a full path, 16 hex chars. Both stay
// exact: every intermediate fits Harbour's 64-bit integer arithmetic before
// the low-word mask.
static function HBIDE_KeyHash( cText )

   local nHash1 := 2166136261  // FNV-1a 32 offset basis
   local nHash2 := 5381        // djb2 seed
   local n, nB

   for n := 1 to Len( cText )
      nB := Asc( SubStr( cText, n, 1 ) )
      nHash1 := hb_BitAnd( hb_BitXor( nHash1, nB ) * 16777619, 0xFFFFFFFF )
      nHash2 := hb_BitAnd( nHash2 * 33 + nB, 0xFFFFFFFF )
   next

return hb_NumToHex( nHash1, 8 ) + hb_NumToHex( nHash2, 8 )

//-----------------------------------------------------------------------------------------//

// The write is failure-tolerant by contract: a journal that cannot be
// written (disk full, permissions, crash mid-write) must never interrupt
// editing. Both files go through <name>.tmp + rename, so a crash can leave
// at worst an inert .tmp, never a torn .journal that would be offered back.
// Order matters: the .target sidecar lands first, so a crash between the two
// renames leaves an orphan sidecar (inert) rather than a journal without a
// known target.
function HBIDE_RecoveryWrite( cKey, cTarget, cContent, hEncoding )

   local cDir := HBIDE_RecoveryDir()
   local lOk := .F.

   cTarget := hb_defaultValue( cTarget, "noname.prg" )
   if cTarget != "noname.prg"
      cTarget := HBIDE_RecoveryAbs( cTarget )
   endif

   if ! HBIDE_RecoveryOwnSession()
      return .F.
   endif

   if HB_ISHASH( hEncoding )
      cContent := Chr( 0 ) + "HBIDE-J1" + Chr( 10 ) + ;
         iif( hEncoding[ "utf8" ], "1", "0" ) + ;
         iif( hEncoding[ "bom" ], "1", "0" ) + ;
         iif( hEncoding[ "raw" ], "1", "0" ) + ;
         hb_ntos( Len( hEncoding[ "cp" ] ) ) + ":" + hEncoding[ "cp" ] + cContent
   endif

   begin sequence
      lOk := HBIDE_AtomicPair( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".target" ), cTarget ) .and. ;
             HBIDE_AtomicPair( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".journal" ), cContent )
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
         lOk := hb_FSize( cTmp ) == Len( cContent ) .and. ;
                hb_MemoRead( cTmp ) == cContent
      endif
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

// Exact-name access for journals found by the scan, which may belong to a
// previous (dead) session: no session suffix is appended here.
function HBIDE_RecoveryReadBase( cBase, hEncoding, lReadOk )

   local cOut := HBIDE_ReadFileChecked( hb_FNameMerge( HBIDE_RecoveryDir(), cBase, ".journal" ), @lReadOk )
   local cDecoded

   hEncoding := NIL
   if ! lReadOk
      return ""
   endif
   cDecoded := HBIDE_RecoveryDecode( cOut, @hEncoding, @lReadOk )
return iif( lReadOk, cDecoded, "" )

// Checked whole-file read shared by editor loads and recovery. Empty is valid;
// a failed open/read returns an explicit false status before callers mutate.
function HBIDE_ReadFileChecked( cFile, lReadOk )
   local cOut := "", nHandle := -1, nSize, nRead
   lReadOk := .F.
   begin sequence
      nHandle := FOpen( cFile, FO_READ + FO_SHARED )
      if nHandle >= 0
         nSize := FSeek( nHandle, 0, FS_END )
         if nSize >= 0 .and. FSeek( nHandle, 0, FS_SET ) == 0
            cOut := Space( nSize )
            nRead := FRead( nHandle, @cOut, nSize )
            lReadOk := nRead == nSize .and. FError() == 0
         endif
      endif
   recover
      lReadOk := .F.
   end sequence
   if nHandle >= 0
      FClose( nHandle )
   endif
   if ! lReadOk
      return ""
   endif

return cOut

//-----------------------------------------------------------------------------------------//

function HBIDE_RecoveryDeleteBase( cBase )

   local cDir := HBIDE_RecoveryDir()

   begin sequence
      FErase( hb_FNameMerge( cDir, cBase, ".journal" ) )
      FErase( hb_FNameMerge( cDir, cBase, ".target" ) )
      FErase( hb_FNameMerge( cDir, cBase, ".journal" ) + ".tmp" )
      FErase( hb_FNameMerge( cDir, cBase, ".target" ) + ".tmp" )
   end sequence

return nil

//-----------------------------------------------------------------------------------------//

function HBIDE_RecoveryRead( cKey )

   local cOut := ""

   begin sequence
      cOut := hb_MemoRead( hb_FNameMerge( HBIDE_RecoveryDir(), cKey + "--" + HBIDE_RecoverySession(), ".journal" ) )
   recover
      cOut := ""
   end sequence

return HBIDE_RecoveryDecode( cOut )

//-----------------------------------------------------------------------------------------//

function HBIDE_RecoveryDelete( cKey )

   local cDir := HBIDE_RecoveryDir()

   begin sequence
      FErase( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".journal" ) )
      FErase( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".target" ) )
      FErase( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".journal" ) + ".tmp" )
      FErase( hb_FNameMerge( cDir, cKey + "--" + HBIDE_RecoverySession(), ".target" ) + ".tmp" )
   end sequence

return nil

//-----------------------------------------------------------------------------------------//

// Surviving journals: { { cKey, cTarget, nSize, cStamp }, ... }.
// cStamp is the journal's mtime, for the prompt.
function HBIDE_RecoveryScan( lIncludeLive )

   local cDir := HBIDE_RecoveryDir()
   local aOut := {}, aFile, cKey, cTarget, aList

   begin sequence
      aList := Directory( hb_FNameMerge( cDir, "*.journal" ) )
   recover
      aList := {}
   end sequence
   // Directory() order is filesystem dependent: offer journals by name so
   // the prompts (and batch recovery) are deterministic across platforms
   ASort( aList,,, {| x, y | x[ F_NAME ] < y[ F_NAME ] } )

   hb_default( @lIncludeLive, .F. )

   for each aFile in aList
      if "D" $ aFile[ F_ATTR ]
         loop
      endif
      cKey := Left( aFile[ F_NAME ], Len( aFile[ F_NAME ] ) - Len( ".journal" ) )
      if ! lIncludeLive .and. HBIDE_RecoveryLive( cKey )
         loop
      endif
      cTarget := hb_MemoRead( hb_FNameMerge( cDir, cKey, ".target" ) )
      // The sidecar is written as exact bytes, not a newline-delimited
      // record. Trimming a legal POSIX filename can select another file.
      AAdd( aOut, { cKey, cTarget, aFile[ F_SIZE ], ;
                    DToC( aFile[ F_DATE ] ) + " " + aFile[ F_TIME ] } )
   next

return aOut

//-----------------------------------------------------------------------------------------//

// Encoding flags and editor bytes share ONE atomic journal generation. Never
// infer them from the target file, which may have changed after the crash.
static function HBIDE_RecoveryDecode( cBytes, hEncoding, lDecodeOk )
   local cPrefix := Chr( 0 ) + "HBIDE-J1" + Chr( 10 )
   local cRest, nColon, nCP, cLength
   hEncoding := NIL
   lDecodeOk := .T.
   if Left( cBytes, Len( cPrefix ) ) == cPrefix
      // An exact version marker reserves this format. A broken header must
      // not enter an editor as if its metadata were legacy source bytes.
      lDecodeOk := .F.
      cRest := SubStr( cBytes, Len( cPrefix ) + 1 )
      nColon := At( ":", cRest )
      if nColon >= 5 .and. nColon <= 7 .and. ;
         Left( cRest, 1 ) $ "01" .and. SubStr( cRest, 2, 1 ) $ "01" .and. SubStr( cRest, 3, 1 ) $ "01"
         cLength := SubStr( cRest, 4, nColon - 4 )
         nCP := Val( cLength )
         if nCP >= 1 .and. nCP <= 64 .and. hb_ntos( nCP ) == cLength .and. Len( cRest ) >= nColon + nCP
            lDecodeOk := .T.
            hEncoding := { "utf8" => Left( cRest, 1 ) == "1", ;
                           "bom" => SubStr( cRest, 2, 1 ) == "1", ;
                           "raw" => SubStr( cRest, 3, 1 ) == "1", ;
                           "cp" => SubStr( cRest, nColon + 1, nCP ) }
            return SubStr( cRest, nColon + nCP + 1 )
         endif
      endif
   endif
return cBytes

// Read-only comparison summary. Journal bytes are editor bytes; without a
// proven conversion they must not be compared to encoded disk bytes as text.
function HBIDE_RecoveryCompare( cBase, cTarget )
   local hEncoding, lJournalOk, lDiskOk, cJournal, cDisk, cSummary
   cJournal := HBIDE_RecoveryReadBase( cBase, @hEncoding, @lJournalOk )
   cSummary := "Read-only comparison. No document or file changed." + Chr( 10 )
   if ! lJournalOk
      return cSummary + "Journal cannot be read or decoded. Kept unchanged."
   endif
   cSummary += "Journal editor payload: " + hb_ntos( Len( cJournal ) ) + " bytes." + Chr( 10 )
   if Empty( cTarget ) .or. cTarget == "noname.prg"
      return cSummary + "No named disk target to compare."
   endif
   cDisk := HBIDE_ReadFileChecked( cTarget, @lDiskOk )
   if ! lDiskOk
      return cSummary + "Disk target missing or unreadable."
   endif
   cSummary += "Disk: " + hb_ntos( Len( cDisk ) ) + " bytes." + Chr( 10 )
   if hEncoding != NIL .and. ( hEncoding[ "utf8" ] .or. hEncoding[ "bom" ] )
      return cSummary + "Encoded journal: editor and disk bytes are not directly comparable. No text equality claimed."
   endif
   if cJournal == cDisk
      return cSummary + "Payload and disk bytes are identical."
   endif
return cSummary + "Payload and disk bytes differ. This is not a line diff."

// A fixed-width byte view avoids interpreting control bytes as terminal
// commands or pretending that editor-codepage bytes are decoded disk text.
function HBIDE_RecoveryByteLine( cBytes, nRow )
   local nStart := ( nRow - 1 ) * 16 + 1, cHex := "", cChars := "", n, nByte
   for n := nStart to Min( Len( cBytes ), nStart + 15 )
      nByte := Asc( SubStr( cBytes, n, 1 ) )
      cHex += hb_NumToHex( nByte, 2 ) + " "
      cChars += iif( nByte >= 32 .and. nByte <= 126, Chr( nByte ), "." )
   next
return hb_NumToHex( nStart - 1, 8 ) + "  " + PadR( cHex, 48 ) + " " + cChars

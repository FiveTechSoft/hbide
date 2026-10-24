#include "fileio.ch"

/*
 * mcjobs.prg - background copy queue for the Commander demo
 *
 * Cooperative, chunked copy engine: the main loop and the Background jobs
 * dialog call MCJobsStep() on idle, advancing the current job one chunk at a
 * time. Only local-to-local copies are queued; VFS transfers stay in the
 * foreground. Mirrors GNU mc's copy-dialog "Background" button and the
 * Command menu's "Background jobs" list. Move (F6) has no background mode.
 *
 * Each entry in a job's file list is:
 *    { "file",    cSrc, cDst, nSize }
 *    { "mkdir",   cSrc, cDst, 0 }     create destination dir (pre-order)
 *    { "dirmeta", cSrc, cDst, 0 }     apply dir perms/mtime (post-order)
 */

static s_aJobs := {}
static s_lJustDone := .F.
static s_nChunk := 262144   // 256 KiB per cooperative step

//-----------------------------------------------------------------------------------------//

function MCJobsActive()

return AScan( s_aJobs, { | j | j[ "state" ] == "queued" .or. j[ "state" ] == "running" } ) > 0

//-----------------------------------------------------------------------------------------//

function MCJobsList()

return s_aJobs

//-----------------------------------------------------------------------------------------//

// One-shot flag: .T. once after a job reached its final state.
function MCJobsTakeFinished()

   local l := s_lJustDone

   s_lJustDone := .F.

return l

//-----------------------------------------------------------------------------------------//

function MCJobsAdd( aFiles, cDesc, lMove )

   local nTotal := 0

   lMove := hb_defaultValue( lMove, .F. )
   AEval( aFiles, { | f | If( f[ 1 ] == "file", nTotal += f[ 4 ], nil ) } )
   AAdd( s_aJobs, { ;
      "desc"  => cDesc, ;
      "move"  => lMove, ;
      "files" => aFiles, ;
      "total" => nTotal, ;
      "done"  => 0, ;
      "idx"   => 1, ;
      "cur"   => nil, ;
      "hSrc"  => -1, ;
      "hDst"  => -1, ;
      "tmp"   => "", ;
      "state" => "queued", ;
      "err"   => "", ;
      "errlog" => "", ;
      "moved" => 0, ;
      "nolink" => .F., ;
      "skipdirs" => {} } )

return Len( s_aJobs )

//-----------------------------------------------------------------------------------------//

// Abort one queued/running job. A running job's partial temp file is
// removed; the destination keeps whatever complete files were already copied.
function MCJobsCancel( nIdx )

   local j

   if nIdx < 1 .or. nIdx > Len( s_aJobs )
      return .F.
   endif
   j := s_aJobs[ nIdx ]
   if j[ "state" ] == "done" .or. j[ "state" ] == "cancelled" .or. j[ "state" ] == "error"
      return .F.
   endif
   MCCloseJob( j )
   j[ "state" ] := "cancelled"
   if j[ "move" ] .and. j[ "moved" ] > 0
      JobErr( j, j[ "desc" ], "PARTIAL MOVE: " + hb_ntos( j[ "moved" ] ) + " item(s) stay at destination; no rollback" )
   endif

return .T.

//-----------------------------------------------------------------------------------------//

function MCJobsCancelAll()

   local n

   for n := 1 to Len( s_aJobs )
      MCJobsCancel( n )
   next

return nil

//-----------------------------------------------------------------------------------------//

static function MCCloseJob( j )

   if j[ "hSrc" ] >= 0
      FClose( j[ "hSrc" ] )
      j[ "hSrc" ] := -1
   endif
   if j[ "hDst" ] >= 0
      FClose( j[ "hDst" ] )
      j[ "hDst" ] := -1
      if ! Empty( j[ "tmp" ] )
         FErase( j[ "tmp" ] )   // partial temp: never rename into place
      endif
   endif
   j[ "tmp" ] := ""
   j[ "cur" ] := nil

return nil

//-----------------------------------------------------------------------------------------//

// Atomic no-clobber publish via hard link (ln): EEXIST can never replace a
// raced-in destination. Returns 0 published, 1 destination exists,
// 2 cross-device, 3 filesystem cannot hard-link, 4 other failure.
static function MCLinkNoClobber( cSrc, cDst, /*@*/ cOut )

   local nRet

   cOut := ""
   nRet := hb_ProcessRun( MCShWrap( "ln -- " + ShellQuote( cSrc ) + " " + ShellQuote( cDst ) + " 2>&1" ),, @cOut )
   if nRet == 0
      return 0
   endif
   if "File exists" $ cOut
      return 1
   endif
   if "cross-device" $ cOut
      return 2
   endif
   if "Operation not permitted" $ cOut .or. "ot supported" $ cOut .or. "Function not implemented" $ cOut
      return 3
   endif

return 4

//-----------------------------------------------------------------------------------------//

// True when cDst sits inside a destination dir a move refused to touch.
static function JobSkipped( j, cDst )

   local d

   for each d in j[ "skipdirs" ]
      if Left( hb_DirSepAdd( cDst ), Len( d ) ) == d
         return .T.
      endif
   next

return .F.

//-----------------------------------------------------------------------------------------//

// Every problem is appended to the job's full log file (no cap, nothing is
// lost silently: Enter in the Background jobs dialog shows it whole).
// j[ "err" ] is only the inline display summary, capped with an explicit
// " ..." tail when the log grows past it.
static function JobErr( j, cPath, cWhy )

   local cLine := hb_FNameNameExt( cPath ) + ": " + cWhy
   local hLog

   if Empty( j[ "errlog" ] )
      hLog := hb_FTempCreate( hb_DirTemp(), "hbmclog",, @j[ "errlog" ] )
      if hLog == F_ERROR
         j[ "errlog" ] := ""
      else
         FClose( hLog )
      endif
   endif
   if ! Empty( j[ "errlog" ] )
      hLog := FOpen( j[ "errlog" ], FO_WRITE )
      if hLog != F_ERROR
         FSeek( hLog, 0, FS_END )
         FWrite( hLog, cLine + hb_eol() )
         FClose( hLog )
      endif
   endif
   if Len( j[ "err" ] ) < 4000
      j[ "err" ] += cLine + "; "
      if Len( j[ "err" ] ) > 4000
         j[ "err" ] := Left( j[ "err" ], 4000 ) + " ..."
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Full problem list of a job for the viewer: the uncapped log file when it
// exists, the inline summary otherwise.
function MCJobsErrText( j )

   if ! Empty( j[ "errlog" ] ) .and. hb_FileExists( j[ "errlog" ] )
      return MemoRead( j[ "errlog" ] )
   endif

return StrTran( j[ "err" ], "; ", ";" + Chr( 10 ) )

//-----------------------------------------------------------------------------------------//

// Remove this session's job logs (called on clean quit).
function MCJobsCleanup()

   local j

   for each j in s_aJobs
      if ! Empty( j[ "errlog" ] )
         FErase( j[ "errlog" ] )
         j[ "errlog" ] := ""
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

// Advance the queue by one chunk. Called on idle from the main loop and from
// the Background jobs dialog.
function MCJobsStep()

   local i, j, f, cTmp := ""
   local cBuf, nRead, nLink, cLinkOut

   for i := 1 to Len( s_aJobs )
      j := s_aJobs[ i ]
      if j[ "state" ] == "queued"
         j[ "state" ] := "running"
         exit
      elseif j[ "state" ] == "running"
         exit
      endif
   next
   if i > Len( s_aJobs )
      return .F.
   endif

   if j[ "hSrc" ] < 0
      // No file open: run the next instant step (mkdir / dirmeta / open).
      if j[ "idx" ] > Len( j[ "files" ] )
         j[ "state" ] := If( Empty( j[ "err" ] ), "done", "error" )
         s_lJustDone := .T.
         return .T.
      endif
      f := j[ "files" ][ j[ "idx" ] ]
      j[ "idx" ]++
      do case
         case f[ 1 ] == "mkdir"
            // mkdir(2) is atomic: EEXIST means the dir was already there or
            // raced in - no check-then-create window.
            if hb_DirCreate( f[ 3 ] ) != 0
               if hb_DirExists( f[ 3 ] )
                  if j[ "move" ]
                     // A move never merges into an existing destination dir.
                     JobErr( j, f[ 3 ], "destination exists; move does not overwrite" )
                     AAdd( j[ "skipdirs" ], hb_DirSepAdd( f[ 3 ] ) )
                  endif
                  // copy: merging into an existing dir is the intended semantics
               else
                  JobErr( j, f[ 3 ], "cannot create directory" )
               endif
            endif
         case f[ 1 ] == "dirmeta"
            if JobSkipped( j, f[ 3 ] )
               // Parent dir was not moved: leave the source tree untouched.
            elseif Len( f ) >= 6 .and. f[ 5 ] > 0
               // Snapshot taken at enqueue: immune to source mutation by moves.
               hb_ProcessRun( MCShWrap( "chmod " + f[ 6 ] + " -- " + ShellQuote( f[ 3 ] ) + " 2>/dev/null" ),, )
               hb_ProcessRun( MCShWrap( "touch -d '@" + hb_ntos( f[ 5 ] ) + "' " + ShellQuote( f[ 3 ] ) + " 2>/dev/null" ),, )
            else
               hb_ProcessRun( MCShWrap( "chmod --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( f[ 3 ] ) + " 2>/dev/null" ),, )
               hb_ProcessRun( MCShWrap( "touch --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( f[ 3 ] ) + " 2>/dev/null" ),, )
            endif
            if j[ "move" ]
               DirRemove( f[ 2 ] )   // fails harmlessly if members stayed behind
            endif
         otherwise
            // "file": a move never overwrites (foreground MoveItem semantics);
            // an existing destination raced in after enqueue is skipped.
            if JobSkipped( j, f[ 3 ] )
               JobErr( j, f[ 3 ], "parent directory not moved" )
               return .T.
            elseif j[ "move" ]
               if j[ "nolink" ]
                  return .T.   // fs cannot publish safely; already reported
               endif
               nLink := MCLinkNoClobber( f[ 2 ], f[ 3 ], @cLinkOut )
               if nLink == 0
                  j[ "done" ] += f[ 4 ]
                  j[ "moved" ]++
                  if FErase( f[ 2 ] ) != 0
                     JobErr( j, f[ 2 ], "linked to destination but source not removed" )
                  endif
                  return .T.
               endif
               if nLink == 1
                  JobErr( j, f[ 3 ], "destination exists; move does not overwrite" )
                  return .T.
               endif
               if nLink == 3
                  j[ "nolink" ] := .T.
                  JobErr( j, f[ 3 ], "destination filesystem cannot hard-link; background move refused (no overwrite-capable fallback)" )
                  return .T.
               endif
               if nLink == 4
                  JobErr( j, f[ 3 ], "link failed; source kept" )
                  return .T.
               endif
               // nLink == 2: cross-device; chunked copy+delete below.
            endif
            // "file": open the source and a temp file in the destination dir.
            j[ "hSrc" ] := FOpen( f[ 2 ], 0 )
            if j[ "hSrc" ] < 0
               JobErr( j, f[ 2 ], "cannot open source" )
            else
               j[ "hDst" ] := hb_FTempCreate( hb_DirSepAdd( hb_FNameDir( f[ 3 ] ) ), "hbmc",, @cTmp )
               if j[ "hDst" ] < 0
                  FClose( j[ "hSrc" ] )
                  j[ "hSrc" ] := -1
                  JobErr( j, f[ 3 ], "cannot create destination" )
               else
                  j[ "tmp" ] := cTmp
                  j[ "cur" ] := f
               endif
            endif
      endcase
      return .T.
   endif

   // Copy one chunk of the current file.
   cBuf := Space( s_nChunk )
   nRead := FRead( j[ "hSrc" ], @cBuf, s_nChunk )
   if nRead > 0
      if FWrite( j[ "hDst" ], Left( cBuf, nRead ) ) != nRead
         JobErr( j, j[ "tmp" ], "write failed" )
         MCCloseJob( j )
         return .T.
      endif
      j[ "done" ] += nRead
   endif
   if nRead == 0 .and. FError() != 0
      JobErr( j, j[ "cur" ][ 2 ], "read failed" )
      MCCloseJob( j )
      return .T.
   endif
   if nRead < s_nChunk
      JobFinishFile( j )
   endif

return .T.

//-----------------------------------------------------------------------------------------//

// Close the current file and move its complete temp copy into place, with
// the same replace semantics as the foreground copy: an existing destination
// is only replaced after a complete copy, and a failed rename never destroys
// the previous file.
static function JobFinishFile( j )

   local f := j[ "cur" ], cTmp := j[ "tmp" ], cBak := "", nBak, nLink, cLinkOut

   FClose( j[ "hSrc" ] )
   FClose( j[ "hDst" ] )
   j[ "hSrc" ] := -1
   j[ "hDst" ] := -1
   j[ "tmp" ] := ""
   j[ "cur" ] := nil

   // hb_FTempCreate() uses 0600; give the copy the source file's permissions.
   hb_ProcessRun( MCShWrap( "chmod --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( cTmp ) ),, )
   if j[ "move" ]
      // Atomic no-clobber publish: link the complete temp into place; EEXIST
      // can never replace a destination that raced in during the copy.
      nLink := MCLinkNoClobber( cTmp, f[ 3 ], @cLinkOut )
      if nLink != 0
         FErase( cTmp )
         do case
            case nLink == 1
               JobErr( j, f[ 3 ], "destination appeared during move; source kept" )
            case nLink == 3
               j[ "nolink" ] := .T.
               JobErr( j, f[ 3 ], "destination filesystem cannot hard-link; source kept" )
            otherwise
               JobErr( j, f[ 3 ], "cannot create destination" )
         endcase
         return nil
      endif
      FErase( cTmp )   // drop the temp name; the data is published
      j[ "moved" ]++
      hb_ProcessRun( MCShWrap( "touch --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( f[ 3 ] ) + " 2>/dev/null" ),, )
      if FErase( f[ 2 ] ) != 0
         JobErr( j, f[ 2 ], "copied but source not removed" )
      endif
      return nil
   endif
   if FRename( cTmp, f[ 3 ] ) != 0
      if File( f[ 3 ] )
         // Move the previous destination aside, retry, restore on failure.
         nBak := hb_FTempCreate( hb_DirSepAdd( hb_FNameDir( f[ 3 ] ) ), "hbmc",, @cBak )
         if nBak < 0
            FErase( cTmp )
            JobErr( j, f[ 3 ], "cannot replace destination; previous file unchanged" )
            return nil
         endif
         FClose( nBak )
         FErase( cBak )   // keep the unique name, free the slot
         if FRename( f[ 3 ], cBak ) != 0
            FErase( cTmp )
            JobErr( j, f[ 3 ], "cannot replace destination; previous file unchanged" )
            return nil
         endif
         if FRename( cTmp, f[ 3 ] ) != 0
            FRename( cBak, f[ 3 ] )   // best-effort restore
            FErase( cTmp )
            JobErr( j, f[ 3 ], "cannot replace destination; previous file unchanged" )
            return nil
         endif
         FErase( cBak )   // replace succeeded: drop the moved-aside original
      else
         FErase( cTmp )
         JobErr( j, f[ 3 ], "cannot create destination" )
         return nil
      endif
   endif
   // Keep the source file's modification time on the destination.
   hb_ProcessRun( MCShWrap( "touch --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( f[ 3 ] ) ),, )
   if j[ "move" ]
      // The destination is complete and in place: only now drop the source.
      if FErase( f[ 2 ] ) != 0
         JobErr( j, f[ 2 ], "copied but source not removed" )
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

// True while the queue needs idle ticks: work active or a finished-job
// notice still waiting for the main loop to rescan panels.
function MCJobsNeedTick()

return MCJobsActive() .or. s_lJustDone

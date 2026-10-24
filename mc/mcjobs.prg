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

static function JobErr( j, cPath, cWhy )

   j[ "err" ] += hb_FNameNameExt( cPath ) + ": " + cWhy + "; "
   if Len( j[ "err" ] ) > 200
      j[ "err" ] := Left( j[ "err" ], 200 ) + "..."
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Advance the queue by one chunk. Called on idle from the main loop and from
// the Background jobs dialog.
function MCJobsStep()

   local i, j, f, cTmp := ""
   local cBuf, nRead

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
            if hb_DirExists( f[ 3 ] )
               if j[ "move" ]
                  // Raced in after enqueue: a move never merges into an
                  // existing destination dir; its subtree stays in place.
                  JobErr( j, f[ 3 ], "destination exists; move does not overwrite" )
                  AAdd( j[ "skipdirs" ], hb_DirSepAdd( f[ 3 ] ) )
               endif
            elseif hb_DirCreate( f[ 3 ] ) != 0
               JobErr( j, f[ 3 ], "cannot create directory" )
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
               if File( f[ 3 ] ) .or. hb_DirExists( f[ 3 ] )
                  JobErr( j, f[ 3 ], "destination exists; move does not overwrite" )
                  return .T.
               endif
               // Same-filesystem move: rename in place and the entry is done.
               if FRename( f[ 2 ], f[ 3 ] ) == 0
                  j[ "done" ] += f[ 4 ]
                  return .T.
               endif
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

   local f := j[ "cur" ], cTmp := j[ "tmp" ], cBak := "", nBak

   FClose( j[ "hSrc" ] )
   FClose( j[ "hDst" ] )
   j[ "hSrc" ] := -1
   j[ "hDst" ] := -1
   j[ "tmp" ] := ""
   j[ "cur" ] := nil

   // hb_FTempCreate() uses 0600; give the copy the source file's permissions.
   hb_ProcessRun( MCShWrap( "chmod --reference=" + ShellQuote( f[ 2 ] ) + " " + ShellQuote( cTmp ) ),, )
   if j[ "move" ] .and. ( File( f[ 3 ] ) .or. hb_DirExists( f[ 3 ] ) )
      // Raced in during the copy: a move never overwrites; source kept.
      FErase( cTmp )
      JobErr( j, f[ 3 ], "destination appeared during move; source kept" )
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

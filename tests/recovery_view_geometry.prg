// Dedicated test entry point: production methods unchanged. Build with
// hbmk2 hbide.hbp tests/recovery_view_geometry.prg -main=RecoveryViewProbe
// and pass journal base, target, rows, columns, optional geometry marker.
procedure RecoveryViewProbe( cBase, cTarget, cRows, cCols, cMarker )
   local o := HBIde():New(), nRows := Val( cRows ), nCols := Val( cCols )
   o:Show()
   o:ApplyDisplay( nRows, nCols )
   if MaxRow() + 1 != nRows .or. MaxCol() + 1 != nCols
      ErrorLevel( 2 )
      return
   endif
   if ! Empty( cMarker )
      hb_MemoWrit( cMarker, hb_ntos( MaxRow() + 1 ) + "x" + hb_ntos( MaxCol() + 1 ) )
   endif
   o:RecoveryCompareView( cBase, cTarget )
return

#include "hbclass.ch"
PROCEDURE Main()
   LOCAL o,cIncremental,cFresh,aOld,aNew,aMode,cFrom,cTo,nFrom,nTo
   LOCAL aTypes:={"say","get","button","checkbox","radiogroup","listbox","combobox"}
   LOCAL nTransitions:=0,nMoves:=0,nEdges:=0,aFrom,aTo
   LOCAL aPositions:={{0,0},{0,1000},{1000,0},{1000,1000},{6,5},{2,86}}
   FOR EACH aMode IN {{40,120},{25,80}}
      SetMode(aMode[1],aMode[2])
      Check(MaxRow()==aMode[1]-1 .and. MaxCol()==aMode[2]-1,"model mode exact")
      o:=HbDesigner():New(PaintHost():New())
      o:oWnd:=HBWindow():Dialog("Fixture",60,20,"W+/W")
      o:FitWindow()
      o:lInspector:=.T.
      o:aControls:={}
      FOR EACH cFrom IN aTypes
         AAdd(o:aControls,DsnNewControl(cFrom,{}))
      NEXT
      FOR nFrom:=0 TO Len(aTypes)
         FOR nTo:=0 TO Len(aTypes)
            o:nSelected:=nFrom
            aOld:=o:InspRect()
            o:nSelected:=nTo
            aNew:=o:InspRect()
            IF aOld[3]==aNew[3]
               LOOP // Same-height selection uses caller Redraw, not this cache path.
            ENDIF
            o:nSelected:=nFrom
            o:Redraw()
            o:nSelected:=nTo
            o:DrawInspector()
            cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
            o:Redraw()
            cFresh:=SaveScreen(0,0,MaxRow(),MaxCol())
            Check(cIncremental==cFresh,"changed-height selection repaint equals clean repaint")
            nTransitions++
         NEXT
      NEXT
      FOR nFrom:=0 TO Len(aTypes)
         o:nSelected:=nFrom
         o:nInspRow:=2
         o:nInspCol:=86
         o:Redraw()
         o:nInspRow:=6
         o:nInspCol:=5
         o:DrawInspector()
         cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
         o:Redraw()
         Check(cIncremental==SaveScreen(0,0,MaxRow(),MaxCol()),"moved panel restores underlay")
         nMoves++
      NEXT
      FOR nFrom:=0 TO Len(aTypes)
         o:nSelected:=nFrom
         FOR EACH aFrom IN aPositions
            FOR EACH aTo IN aPositions
               o:nInspRow:=aFrom[1]
               o:nInspCol:=aFrom[2]
               aOld:=o:InspRect()
               o:nInspRow:=aTo[1]
               o:nInspCol:=aTo[2]
               aNew:=o:InspRect()
               IF aOld[1]==aNew[1].and.aOld[2]==aNew[2]
                  LOOP // Count only actual changed clamped screen positions.
               ENDIF
               Check(aNew[1]>=0.and.aNew[2]>=0.and.aNew[3]<=MaxRow().and.aNew[4]<=MaxCol(),"edge panel remains on screen")
               o:nInspRow:=aFrom[1]
               o:nInspCol:=aFrom[2]
               o:Redraw()
               o:nInspRow:=aTo[1]
               o:nInspCol:=aTo[2]
               o:DrawInspector()
               cIncremental:=SaveScreen(0,0,MaxRow(),MaxCol())
               o:Redraw()
               Check(cIncremental==SaveScreen(0,0,MaxRow(),MaxCol()),"edge to edge restores exact underlay")
               nEdges++
            NEXT
         NEXT
      NEXT
   NEXT
   ? "PASS inspector repaint",nTransitions,"height transitions",nMoves,"panel moves",nEdges,"edge moves"
   RETURN
STATIC PROCEDURE Check(lOk,cText)
   IF !lOk
      ? "FAIL:",cText
      ErrorLevel(1)
      QUIT
   ENDIF
   RETURN
CLASS PaintHost
   METHOD SuspendStatus() INLINE NIL
   METHOD ResumeStatus() INLINE NIL
   METHOD ShowStatus() INLINE NIL
   METHOD Repaint() INLINE hb_Scroll(0,0,MaxRow(),MaxCol(),,,"W/B")
ENDCLASS

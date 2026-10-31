function Main()
 local a := "x" != [/* different]
 local b := "x" <> [/* alternate]
 local c := "x" # [/* hash]
 local d := "x" <= [/* less]
 local e := "x" >= [/* greater]
 local f := "x" = [/* equal]
 local g := "x" < [/* below]
 local h := "x" > [/* above]
 local i := "x" $ [/* contains]
return g .or. h .or. i .or. a .or. b .or. c .or. d .or. e .or. f
function Target()
return nil

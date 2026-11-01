function Main()
 local b := {|| [/* literal] }
 local d := {|x| [/* argument] }
 local e := {|| /* gap */ [/* gapliteral] }
 local c := Eval(b)
return c
function Target()
return nil

function Main()
 local a := e"quoted\"/* literal"
 local b := E"quoted\"// literal"
 local c := e"slash\\" /* real */
 local d := e"tab\t&& literal"
return a+b+c+d

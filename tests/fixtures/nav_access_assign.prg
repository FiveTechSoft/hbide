#include "hbclass.ch"
function Main()
return nil
CLASS Demo
 ACCESS Value()
 ASSIGN Value(n)
ENDCLASS
ACCESS Value() CLASS Demo
return 1
ASSIGN Value(n) CLASS Demo
return n

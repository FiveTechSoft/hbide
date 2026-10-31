#include "hbclass.ch"
function Main()
return Demo():New()
CLASS Demo
 CLASS VAR shared INIT 1
 METHOD New()
 METHOD Touch()
ENDCLASS
METHOD FUNCTION New() CLASS Demo
return Self
METHOD PROCEDURE Touch() CLASS Demo
return

#include "hbclass.ch"
function Main()
return nil
CLASS Demo
 DESTRUCTOR Cleanup()
ENDCLASS
DESTRUCTOR Cleanup() CLASS Demo
return

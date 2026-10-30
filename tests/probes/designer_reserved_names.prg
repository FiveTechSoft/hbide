PROCEDURE Main(cOut,cName)
   LOCAL a:={DsnNewControl("get",{}),DsnNewControl("combobox",{})}
   a[1,"variable"]:=cName
   a[2,"variable"]:="sHaReD"
   hb_MemoWrit(cOut,DsnGenCode({"name"=>"Reserved","controls"=>a}))
   RETURN

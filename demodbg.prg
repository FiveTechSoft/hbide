function Main()

   local nTotal := 0, n2
   local aNums := { 1, 2, 3, 4, 5 }

   for each n2 in aNums
      nTotal += AddNum( n2, n2 * 2 )
   next

   ? "Total:", nTotal

return nil

function AddNum( a, b )

return a + b

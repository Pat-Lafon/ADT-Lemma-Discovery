let concat = 
	let l1 = (v:int list) true in
	let l2 = (v:int list) true in
	let l3 = (v:int list) true in
	(fun (u:'fa) ->
    (
     (iff (list_member l3 u) 
      ((list_member l1 u) || (list_member l2 u))) &&
     (
implies       (list_head l3 u) 
      ((list_head l1 u) || (list_head l2 u))
     )
    ))
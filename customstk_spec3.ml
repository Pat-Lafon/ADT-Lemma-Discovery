let concat = 
	let l1 = (v:int list) true in
	let l2 = (v:int list) true in
	(l3:int list) (fun (u:'fa) -> fun (v:'fa) ->
    (
     (iff (list_member l3 u) 
      ((list_member l1 u) || (list_member l2 u))) &&
     (
implies       ((list_order l1 u v) || (list_order l2 u v)) 
      (list_order l3 u v)
     )
    ))
let preds = [| "mem"; "hd"; "once" |]

let post (x : int) (l1 : Uniquel.t) (l2 : Uniquel.t) (u : int) =
  iff (mem l2 u) (mem l1 u || u == x)

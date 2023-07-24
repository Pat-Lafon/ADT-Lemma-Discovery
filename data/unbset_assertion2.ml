let preds = [| "mem"; "root" |]

let post (x : int) (tree1 : Unbset.t) (tree2 : Unbset.t) (u : int) =
  implies (root tree1 u)
    (implies (u < x) (root tree2 u) && implies (u >= x) (root tree2 x))
  && iff (mem tree2 u) (mem tree1 u || u == x)

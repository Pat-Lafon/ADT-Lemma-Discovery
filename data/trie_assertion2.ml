let preds = [| "mem" |]

let post (default : int) (i : Trie.tp) (a : int) (m : Trie.t) (nu : Trie.t)
    (u : int) =
  implies (mem m u || u == default || u == a) (mem nu u)

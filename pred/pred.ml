module type Predicate = sig
  module V : Value.Value

  type t = string

  val layout : t -> string
  val layout_simple : t -> string
  val apply_layout : t * V.t * V.t list -> string
  val apply : t * V.t * V.t list -> bool
  val desugar : t -> t * int list

  type pred_info = {
    name : string;
    num_dt : int;
    num_int : int;
    permu : bool;
    dttp : Tp.Tp.t;
  }

  type raw_pred_info = { raw_name : string; raw_num_args : int }

  val raw_preds_info : raw_pred_info list
  val preds_info : pred_info list
  val fixed_dt_truth_tab : t -> V.t -> int list list
  val find_pred_info_by_name : string -> pred_info
  val tp_to_preds : Tp.Tp.t -> pred_info list
end

module Predicate (V : Value.Value) : Predicate with type V.t = V.t = struct
  module V = V
  module T = Tp.Tp
  open Utils
  open Printf

  type t = string

  type pred_info = {
    name : string;
    num_dt : int;
    num_int : int;
    permu : bool;
    dttp : Tp.Tp.t;
  }

  type raw_pred_info = { raw_name : string; raw_num_args : int }

  let preds_info : pred_info list =
    [
      { name = "=="; num_dt = 0; num_int = 2; permu = false; dttp = T.Int };
      {
        name = "list_length";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntList;
      };
      {
        name = "list_member";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntList;
      };
      {
        name = "list_head";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntList;
      };
      {
        name = "list_order";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntList;
      };
      {
        name = "list_once";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntList;
      };
      {
        name = "list_last";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntList;
      };
      {
        name = "list_next";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntList;
      };
      {
        name = "tree_head";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "tree_member";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "tree_left";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTree;
      };
      {
        name = "tree_right";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTree;
      };
      {
        name = "tree_parallel";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTree;
      };
      {
        name = "tree_once";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "tree_leaf";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "tree_node";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "tree_ancestor";
        num_dt = 1;
        num_int = 2;
        permu = false;
        dttp = T.IntTree;
      };
      {
        name = "treei_head";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_member";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_left";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_right";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_parallel";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_once";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_leaf";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_node";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treei_ancestor";
        num_dt = 1;
        num_int = 2;
        permu = false;
        dttp = T.IntTreeI;
      };
      {
        name = "treeb_head";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_member";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_left";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_right";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_parallel";
        num_dt = 1;
        num_int = 2;
        permu = true;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_once";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_leaf";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeB;
      };
      {
        name = "treeb_node";
        num_dt = 1;
        num_int = 1;
        permu = false;
        dttp = T.IntTreeB;
      };
      {
        name = "treei_ancestor";
        num_dt = 1;
        num_int = 2;
        permu = false;
        dttp = T.IntTreeB;
      };
    ]

  (* desugared *)
  let raw_preds_info =
    [
      { raw_name = "len"; raw_num_args = 2 };
      { raw_name = "member"; raw_num_args = 2 };
      { raw_name = "head"; raw_num_args = 2 };
      { raw_name = "last"; raw_num_args = 2 };
      { raw_name = "next"; raw_num_args = 3 };
      { raw_name = "leaf"; raw_num_args = 2 };
      { raw_name = "node"; raw_num_args = 2 };
      { raw_name = "once"; raw_num_args = 2 };
      { raw_name = "order"; raw_num_args = 5 };
    ]

  let apply_layout (pred, dt, args) =
    sprintf "%s(%s, %s)" pred (V.layout dt) (List.to_string V.layout args)

  let find_pred_info_by_name name =
    match
      List.find_opt (fun info -> String.equal info.name name) preds_info
    with
    | None -> raise @@ InterExn "find_pred_info_by_name"
    | Some info -> info

  let layout name = name

  let layout_simple name =
    match name with
    | "list_length" -> "len"
    | "list_member" -> "mem"
    | "list_head" -> "hd"
    | "list_order" -> "ord"
    | "list_once" -> "once"
    | "list_last" -> "last"
    | "list_next" -> "next"
    | "tree_head" -> "hd"
    | "tree_member" -> "mem"
    | "tree_left" -> "left"
    | "tree_right" -> "right"
    | "tree_parallel" -> "para"
    | "tree_once" -> "once"
    | "tree_leaf" -> "leaf"
    | "tree_node" -> "node"
    | "tree_ancestor" -> "ance"
    | "treei_head" -> "hd"
    | "treei_member" -> "mem"
    | "treei_left" -> "left"
    | "treei_right" -> "right"
    | "treei_parallel" -> "para"
    | "treei_once" -> "once"
    | "treei_leaf" -> "leaf"
    | "treei_node" -> "node"
    | "treei_ancestor" -> "ance"
    | "treeb_head" -> "hd"
    | "treeb_member" -> "mem"
    | "treeb_left" -> "left"
    | "treeb_right" -> "right"
    | "treeb_parallel" -> "para"
    | "treeb_once" -> "once"
    | "treeb_leaf" -> "leaf"
    | "treeb_node" -> "node"
    | "treeb_ancestor" -> "ance"
    | _ -> raise @@ InterExn "unknown pred"

  let tp_to_preds tp =
    let pres =
      match tp with
      | T.IntTreeB ->
          [
            "treeb_head";
            "treeb_member";
            "treeb_left";
            "treeb_right";
            "treeb_parallel";
          ]
      | T.IntTreeI ->
          [
            "treei_head";
            "treei_member";
            "treei_left";
            "treei_right";
            "treei_parallel";
          ]
      | T.IntTree ->
          [
            "tree_head";
            "tree_member";
            "tree_left";
            "tree_right";
            "tree_parallel";
          ]
      | T.IntList -> [ "list_head"; "list_member"; "list_order"; "list_length" ]
      | _ -> []
    in
    List.map find_pred_info_by_name pres
  (* List.filter_map (fun info ->
   *     if T.is_dt tp && T.eq info.dttp tp
   *     then Some info
   *     else None
   *   ) preds_info *)

  let head_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.L l, V.I e -> ( match l with [] -> false | h :: _ -> h == e)
    | V.T t, V.I e -> (
        match t with Tree.Leaf -> false | Tree.Node (root, _, _) -> root == e)
    | V.TI t, V.I e -> (
        match t with
        | LabeledTree.Leaf -> false
        | LabeledTree.Node (_, root, _, _) -> root == e)
    | V.TB t, V.I e -> (
        match t with
        | LabeledTree.Leaf -> false
        | LabeledTree.Node (_, root, _, _) -> root == e)
    | _ -> raise @@ InterExn "head_apply"

  let length_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.L l, V.I e -> List.length l == e
    | _ -> raise @@ InterExn "length_apply"

  let member_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.L l, V.I e -> List.exists (fun x -> x == e) l
    | V.T t, V.I e -> Tree.exists (fun x -> x == e) t
    | V.TI t, V.I e -> LabeledTree.exists (fun x -> x == e) t
    | V.TB t, V.I e -> LabeledTree.exists (fun x -> x == e) t
    | _ -> raise @@ InterExn "member_apply"

  let once_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.L l, V.I e -> List.once (fun x y -> x == y) l e
    | V.T t, V.I e -> Tree.once (fun x y -> x == y) t e
    | V.TI t, V.I e -> LabeledTree.once (fun x y -> x == y) t e
    | V.TB t, V.I e -> LabeledTree.once (fun x y -> x == y) t e
    | _ -> raise @@ InterExn "once_apply"

  let last_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.L l, V.I e -> List.lastb l e
    | _ -> raise @@ InterExn "last_apply"

  let next_apply (dt : V.t) (u : V.t) (v : V.t) =
    match (dt, u, v) with
    | V.L l, V.I u, V.I v ->
        let rec aux l =
          match l with
          | [] -> false
          | [ _ ] -> false
          | x :: y :: t -> if x == u && y == v then true else aux (y :: t)
        in
        aux l
    | _ -> raise @@ InterExn "last_apply"

  let ancestor_apply (dt : V.t) (u : V.t) (v : V.t) =
    let eq x y = x == y in
    match (dt, u, v) with
    | V.T t, V.I e0, V.I e1 ->
        Tree.left_child eq t e0 e1 || Tree.right_child eq t e0 e1
    | V.TI t, V.I e0, V.I e1 ->
        LabeledTree.left_child eq t e0 e1 || LabeledTree.right_child eq t e0 e1
    | V.TB t, V.I e0, V.I e1 ->
        LabeledTree.left_child eq t e0 e1 || LabeledTree.right_child eq t e0 e1
    | _ -> raise @@ InterExn "ancestor_apply"

  let leaf_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.T t, V.I e -> Tree.leaf (fun x y -> x == y) t e
    | V.TI t, V.I e -> LabeledTree.leaf (fun x y -> x == y) t e
    | V.TB t, V.I e -> LabeledTree.leaf (fun x y -> x == y) t e
    | _ -> raise @@ InterExn "leaf_apply"

  let node_apply (dt : V.t) (e : V.t) =
    match (dt, e) with
    | V.T t, V.I e -> Tree.node (fun x y -> x == y) t e
    | V.TI t, V.I e -> LabeledTree.node (fun x y -> x == y) t e
    | V.TB t, V.I e -> LabeledTree.node (fun x y -> x == y) t e
    | _ -> raise @@ InterExn "node_apply"

  let order_apply (dt : V.t) i0 i1 (e0 : V.t) (e1 : V.t) =
    let eq x y = x == y in
    match (dt, i0, i1, e0, e1) with
    | V.L l, 0, 1, V.I e0, V.I e1 -> List.order eq l e0 e1
    | V.T t, 0, 1, V.I e0, V.I e1 -> Tree.left_child eq t e0 e1
    | V.T t, 0, 2, V.I e0, V.I e1 -> Tree.right_child eq t e0 e1
    | V.T t, 1, 2, V.I e0, V.I e1 -> Tree.parallel_child eq t e0 e1
    | V.TI t, 0, 1, V.I e0, V.I e1 -> LabeledTree.left_child eq t e0 e1
    | V.TI t, 0, 2, V.I e0, V.I e1 -> LabeledTree.right_child eq t e0 e1
    | V.TI t, 1, 2, V.I e0, V.I e1 -> LabeledTree.parallel_child eq t e0 e1
    | V.TB t, 0, 1, V.I e0, V.I e1 -> LabeledTree.left_child eq t e0 e1
    | V.TB t, 0, 2, V.I e0, V.I e1 -> LabeledTree.right_child eq t e0 e1
    | V.TB t, 1, 2, V.I e0, V.I e1 -> LabeledTree.parallel_child eq t e0 e1
    | _ -> raise @@ InterExn "order_apply"

  let eq_apply (e0 : V.t) (e1 : V.t) =
    match (e0, e1) with
    | V.I e0, V.I e1 -> e0 == e1
    | _ -> raise @@ InterExn "eq_apply"

  let desugar pred =
    match pred with
    | "member" | "==" | "order" | "head" -> (pred, [])
    | "list_member" | "tree_member" | "treei_member" | "treeb_member" ->
        ("member", [])
    | "list_head" | "tree_head" | "treei_head" | "treeb_head" -> ("head", [])
    | "list_length" -> ("length", [])
    | "list_last" -> ("last", [])
    | "list_next" -> ("next", [])
    | "tree_node" | "treei_node" | "treeb_node" -> ("node", [])
    | "tree_leaf" | "treei_leaf" | "treeb_leaf" -> ("leaf", [])
    | "tree_ancestor" | "treei_ancestor" | "treeb_ancestor" -> ("ancestor", [])
    | "list_once" | "tree_once" | "treei_once" | "treeb_once" -> ("once", [])
    | "list_order" -> ("order", [ 0; 1 ])
    | "tree_left" | "treei_left" | "treeb_left" -> ("order", [ 0; 1 ])
    | "tree_right" | "treei_right" | "treeb_right" -> ("order", [ 0; 2 ])
    | "tree_parallel" | "treei_parallel" | "treeb_parallel" ->
        ("order", [ 1; 2 ])
    | _ -> raise @@ InterExn "desugar"

  let desugar_ (pred, dt, args) =
    let pred, args' = desugar pred in
    let args' = List.map (fun x -> V.I x) args' in
    (pred, dt, args' @ args)

  let apply_ ((pred, dt, args) : t * V.t * V.t list) : bool =
    match (pred, args) with
    | "length", [ arg ] -> length_apply dt arg
    | "member", [ arg ] -> member_apply dt arg
    | "head", [ arg ] -> head_apply dt arg
    | "last", [ arg ] -> last_apply dt arg
    | "next", [ arg0; arg1 ] -> next_apply dt arg0 arg1
    | "leaf", [ arg ] -> leaf_apply dt arg
    | "node", [ arg ] -> node_apply dt arg
    | "once", [ arg ] -> once_apply dt arg
    | "ancestor", [ arg0; arg1 ] -> ancestor_apply dt arg0 arg1
    | "order", [ V.I i0; V.I i1; arg0; arg1 ] -> order_apply dt i0 i1 arg0 arg1
    | "==", [ arg0; arg1 ] -> eq_apply arg0 arg1
    | _ ->
        raise
        @@ InterExn
             (sprintf "apply_:%s(%s)" pred (List.to_string V.layout args))

  let apply ((pred, dt, args) : t * V.t * V.t list) : bool =
    let pred, dt, args = desugar_ (pred, dt, args) in
    apply_ (pred, dt, args)

  let fixed_dt_truth_tab pred dt =
    let forallu = V.flatten_forall dt in
    match (dt, pred) with
    | _, "list_length" -> List.map (fun i -> [ i ]) forallu
    | _, "list_head" -> List.map (fun i -> [ i ]) forallu
    | _, "list_member" -> List.map (fun i -> [ i ]) forallu
    | V.L l, "list_order" ->
        let args_list = List.cross forallu forallu in
        let args_list =
          List.filter
            (fun (u, v) -> List.order (fun x y -> x == y) l u v)
            args_list
        in
        List.map (fun (u, v) -> [ u; v ]) args_list
    | _ -> raise @@ InterExn "fixed_dt_truth_tab"
end

module Pred = Predicate (Value.Value)
module Value = Pred.V

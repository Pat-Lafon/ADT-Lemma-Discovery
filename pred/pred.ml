module type Pred = sig
  module V: Value.Value
  type t = string
  val layout : t -> string
  val apply_layout: (t * V.t * V.t list) -> string
  val apply: (t * V.t * V.t list) -> bool
  val desugar: t -> t * int list
  type pred_info = {name:string; num_dt:int; num_int: int; permu: bool}
  val raw_preds_info: pred_info list
  val preds_info: pred_info list
  val fixed_dt_truth_tab: t -> V.t -> int list list
end

module Pred (V: Value.Value) : Pred with type V.t = V.t = struct
  module V = V
  open Utils
  open Printf
  type t = string
  type pred_info = {name:string; num_dt:int; num_int: int; permu: bool}
  let preds_info = [
    {name="member"; num_dt=1; num_int=1; permu=false};
    {name="head"; num_dt=1; num_int=1; permu=false};
    {name="=="; num_dt=0; num_int=2; permu=false};
    {name="list_order"; num_dt=1; num_int=2; permu=true};
    {name="tree_left"; num_dt=1; num_int=2; permu=true};
    {name="tree_right"; num_dt=1; num_int=2; permu=true};
    {name="tree_parallel"; num_dt=1; num_int=2; permu=true};]
  (* desugared *)
  let raw_preds_info = [
    {name="member"; num_dt=1; num_int=1; permu=false};
    {name="head"; num_dt=1; num_int=1; permu=false};
    {name="order"; num_dt=1; num_int=4; permu=false};]
  let apply_layout (pred, dt, args) =
    sprintf "%s(%s, %s)" pred (V.layout dt) (List.to_string V.layout args)

  let layout name = name

  let head_apply (dt: V.t) (e: V.t) =
    match (dt, e) with
    | (V.L l, V.I e) ->
      (match l with
        | [] -> false
        | h :: _ -> h == e)
    | (V.T t, V.I e) ->
      (match t with
       | Tree.Leaf -> false
       | Tree.Node (root, _, _) -> root == e)
    | _ -> raise @@ InterExn "head_apply"

  let member_apply (dt: V.t) (e: V.t) =
    match (dt, e) with
    | (V.L l, V.I e) -> List.exists (fun x -> x == e) l
    | (V.T t, V.I e) -> Tree.exists (fun x -> x == e) t
    | _ -> raise @@ InterExn "member_apply"

  let order_apply (dt: V.t) i0 i1 (e0: V.t) (e1: V.t) =
    let eq x y = x == y in
    match (dt, i0, i1, e0, e1) with
    | (V.L l, 0, 1, V.I e0, V.I e1) -> List.order eq l e0 e1
    | (V.T t, 0, 1, V.I e0, V.I e1) -> Tree.left_child eq t e0 e1
    | (V.T t, 0, 2, V.I e0, V.I e1) -> Tree.right_child eq t e0 e1
    | (V.T t, 1, 2, V.I e0, V.I e1) -> Tree.parallel_child eq t e0 e1
    | _ -> raise @@ InterExn "order_apply"

  let eq_apply (e0: V.t) (e1: V.t) =
    match e0, e1 with
    | (V.I e0, V.I e1) -> e0 == e1
    | _ -> raise @@ InterExn "eq_apply"

  let desugar pred =
    match pred with
    | "member" | "==" | "order" | "head" -> pred, []
    | "list_order" -> "order", [0;1]
    | "tree_left" -> "order", [0;1]
    | "tree_right" -> "order", [0;2]
    | "tree_parallel" -> "order", [1;2]
    | _ -> raise @@ InterExn "desugar"

  let desugar_ (pred, dt, args) =
    let pred, args' = desugar pred in
    let args' = List.map (fun x -> V.I x) args' in
    (pred, dt, args' @ args)

  let apply_ ((pred, dt, args) : t * V.t * V.t list) : bool =
    match pred, args with
    | "member", [arg] -> member_apply dt arg
    | "head", [arg] -> head_apply dt arg
    | "order", [V.I i0; V.I i1; arg0; arg1] -> order_apply dt i0 i1 arg0 arg1
    | "==", [arg0; arg1] -> eq_apply arg0 arg1
    | _ -> raise @@ InterExn "apply"

  let apply ((pred, dt, args) : t * V.t * V.t list) : bool =
    let (pred, dt, args) = desugar_ (pred, dt, args) in
    apply_ (pred, dt, args)
  let fixed_dt_truth_tab pred dt =
    let forallu = V.flatten_forall dt in
    match dt, pred with
    | (_, "head") -> List.map (fun i -> [i]) forallu
    | (_, "member") -> List.map (fun i -> [i]) forallu
    | (V.L l, "list_order") ->
      let args_list = List.cross forallu forallu in
      let args_list =
        List.filter (fun (u, v) -> List.order (fun x y -> x == y) l u v) args_list in
      List.map (fun (u, v) -> [u;v]) args_list
    | _ -> raise @@ InterExn "fixed_dt_truth_tab"
end

module Predicate = Pred(Value.Value);;
module Value = Predicate.V;;

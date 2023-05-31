module Ast = Language.SpecAst
module Value = Pred.Value
module Axiom = Inference.AxiomSyn
module Spec = Inference.SpecSyn

open Ast
open Utils
open Z3
open Printf
module SE = E.SE
module T = Tp.Tp
module V = Pred.Value
open Language.Helper
open Bench_utils
open Frontend.Fast.Fast
;;

let testname = "customstk" in
(* starting program stored where? *)
(* let rec concat l1 l2 =
 *   if Customstack.is_empty l1 then l2
 *   else Customstack.push (Customstack.top l1) (concat (Customstack.tail l1) l2) *)


(* Initialization*)
let ctx = init () in
let spec_tab = predefined_spec_tab in

(* Load in components *)
let spec_tab, cons = register spec_tab
    {name = "StackPush"; intps = [T.Int; T.IntList]; outtps = [T.IntList];
            prog = function
              | [V.I h; V.L t] -> [V.L (h :: t)]
              | _ -> raise @@ InterExn "bad prog"
    } in
let spec_tab, is_empty = register spec_tab
    {name = "IsEmpty"; intps = [T.IntList]; outtps = [T.Bool];
     prog = function
       | [V.L []] -> [V.B false]
       | [V.L _] -> [V.B true]
       | _ -> raise @@ InterExn "bad prog"
    } in
let spec_tab, stack_head = register spec_tab
    {name = "StackTop"; intps = [T.IntList]; outtps = [T.Int];
     prog = function
       | [V.L (h :: t)] -> [V.I h]
       | _ -> raise @@ InterExn "bad prog"
    } in
let spec_tab, stack_tail = register spec_tab
    {name = "StackTail"; intps = [T.IntList]; outtps = [T.IntList];
     prog = function
       | [V.L (h :: t)] -> [V.L t]
       | _ -> raise @@ InterExn "bad prog"
    } in

(* Load in target program *)
let concat l = SpecApply ("Concat", l) in
let vc =
  Ast.Ite (is_empty [l1],
       concat [l1; l2; l2],
       Implies (And [stack_head [l1; x];
                     stack_tail [l1; l3];
                     concat [l3; l2; l4];
                     cons [x; l4; l5;]],
                concat [l1; l2; l5])
      )
in
(* let ast =
 *   ("Concat", [T.IntList, "l1"; T.IntList, "l2"],
 *      (Ite(T.IntList,
 *           App(T.Bool, "IsEmpty", [T.IntList, "l1";]),
 *           (Var [T.IntList, "l2"]),
 *           make_lets
 *             [[T.Int, "x"], App(T.Int, "StackTop", [T.IntList, "l1"]);
 *              [T.IntList, "l3"], App(T.IntList, "StackTail", [T.IntList, "l1"]);
 *              [T.IntList, "l4"], App(T.IntList, "Concat", [T.IntList, "l3"; T.IntList, "l2"]);
 *              [T.IntList, "l5"], App(T.IntList, "Stack
Push", [T.Int, "x"; T.IntList, "l4"]);
 *             ]
 *             (Var [T.Int, "l5"])
 *          ))
 *   )
 * in
 * let vc = func_to_vc [T.IntList, "l6"] ast in *)
(* let _ = printf "\nvc=%s\n" (A.layout vc) in *)

(* Declare predicates *)
let preds = ["list_once"; "list_member"; "list_order"; "list_head"; "list_last"; "list_next"] in
let bpreds = ["=="] in


let spec_tab_1 = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u"]
    (E.And [
        E.Implies(E.And[list_head l1 u], list_member l3 u);
      ]) [T.IntList, "l1"; T.IntList, "l2"] [T.IntList, "l3"]
in
let oc1 = open_out "customstk_spec1.ml" in
let oc1_2 = open_out "customstk_api_spec1.ml" in
let _ = printf_assertion_refinement spec_tab_1 oc1 ["Concat"] in
let axiom1 = assertion ctx vc spec_tab_1
    ["list_member"; "list_order"; "list_head"; "list_last";]
    bpreds 100 6 true testname "axiom1" in
let _ = print_spec_refinement spec_tab oc1_2 axiom1 in


let spec_tab_2 = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u"]
      (E.And [
        E.Iff(list_member l3 u, E.Or [list_member l1 u; list_member l2 u]);
      ]) [T.IntList, "l1"; T.IntList, "l2"] [T.IntList, "l3"]
in
let oc2 = open_out "customstk_spec2.ml" in
let oc2_2 = open_out "customstk_api_spec2.ml" in
let _ = printf_assertion_refinement spec_tab_2 oc2 ["Concat"] in
let axiom2 = assertion ctx vc spec_tab_2
    ["list_member"; "list_order"; "list_head"; "list_next"]
    bpreds 115 6 true testname "axiom2" in
let _ = print_spec_refinement spec_tab oc2_2 axiom2 in



let spec_tab_3 = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u";"v"]
     (E.And [
        E.Iff(list_member l3 u, E.Or [list_member l1 u; list_member l2 u]);
        E.Implies(E.Or [list_order l1 u v; list_order l2 u v],
                  list_order l3 u v);
      ]) [T.IntList, "l1"; T.IntList, "l2"] [T.IntList, "l3"]
in
let oc3 = open_out "customstk_spec3.ml" in
let oc3_2 = open_out "customstk_api_spec3.ml" in
let _ = printf_assertion_refinement spec_tab_3 oc3 ["Concat"] in
let axiom3 = assertion ctx vc spec_tab_3
    ["list_member"; "list_order"; "list_head";]
    bpreds 120 6 true testname "axiom3" in
let _ = print_spec_refinement spec_tab oc3_2 axiom3 in



let spec_tab_4 = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u"]
     (E.And [
        E.Iff(list_member l3 u, E.Or [list_member l1 u; list_member l2 u]);
        E.Implies (list_head l3 u, E.Or [list_head l1 u; list_head l2 u])
      ]) [T.IntList, "l1"; T.IntList, "l2"; T.IntList, "l3"] []
in
let oc4 = open_out "customstk_spec4.ml" in
let oc4_2 = open_out "customstk_api_spec4.ml" in
let _ = printf_assertion_refinement spec_tab_4 oc4 ["Concat"] in
let axiom4 = assertion ctx vc spec_tab_4 preds bpreds 110 6 true testname "axiom4" in
let _ = print_spec_refinement spec_tab oc4_2 axiom4 in

(* let spec_tab, stack_tail = register spec_tab
 *     {name = "StackTail"; intps = [T.IntList]; outtps = [T.IntList];
 *      prog = function
 *        | [V.L l] -> [V.L []]
 *        | _ -> raise @@ InterExn "bad prog"
 *     } in
 * (\* let axiom4 = assertion ctx vc spec_tab preds bpreds 100 8 false testname "axiom4" in *\)
 * let spec_tab, stack_tail = register spec_tab
 *     {name = "StackTail"; intps = [T.IntList]; outtps = [T.IntList];
 *      prog = function
 *        | [V.L (h:: t)] -> [V.L t]
 *        | _ -> raise @@ InterExn "bad prog"
 *     } in
 *
 * let spec_tab = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u"]
 *     (E.And [
 *         E.Iff(list_member l3 u, list_member l1 u);
 *       ])
 * in
 * (\* let axiom5 = assertion ctx vc spec_tab preds bpreds 100 8 false testname "axiom5" in *\)
 *
 * let spec_tab = add_spec spec_tab "Concat" ["l1";"l2";"l3"] ["u"]
 *     (E.And [
 *         E.Iff(list_member l3 u, list_member l2 u);
 *       ])
 * in *)
(* let axiom6 = assertion ctx vc spec_tab preds bpreds 100 8 false testname "axiom6" in *)
let _ = to_verifier testname [axiom1;axiom2;axiom3;axiom4] in
();;

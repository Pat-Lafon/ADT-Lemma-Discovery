module type Ast = sig
  include AstTree.AstTree

  type value = E.value

  val fv : t -> (Tp.Tp.t * string) list
  val type_check : t -> t * bool
  val spec_exec : spec -> string list -> value Utils.StrMap.t -> bool
  val exec : t -> spec Utils.StrMap.t -> value Utils.StrMap.t -> bool

  (* val spec_to_z3: Z3.context -> string -> spec ->
   *   Solver.Z3aux.imp_version -> Z3.FuncDecl.func_decl * Z3.Expr.expr *)
  (* val to_z3_with_q: Z3.context -> t -> spec Utils.StrMap.t -> string list -> (Tp.Tp.t * string) list -> Z3.Expr.expr *)
  val to_z3 :
    Z3.context ->
    t ->
    spec Utils.StrMap.t ->
    Solver.Z3aux.imp_version ->
    Tp.Tp.tpedvar list ->
    Z3.Expr.expr

  (* val neg_to_z3: Z3.context -> t -> spec Utils.StrMap.t -> Solver.Z3aux.imp_version ->
   *   Tp.Tp.tpedvar list * Z3.Expr.expr *)
  val application : t -> spec Utils.StrMap.t -> t
  val to_nnf : t -> t
  val remove_unsat_clause : t -> t

  (* val get_sat_conj: ctx -> t spec Utils.StrMap.t -> t *)
  val skolemize_conj : t -> string list * string list * t
  val skolemize : t -> string list * t
  val elem_not_conj : t -> t
  val extract_variables : t -> int list * (E.SE.tp * string) list
  val eliminate_cond : t -> t list
  val eliminate_cond_one : t -> t
end

module Ast (A : AstTree.AstTree) : Ast = struct
  include A
  module T = Tp.Tp
  module SE = E.SE
  open Utils

  (* open Printf *)
  type value = E.value

  let fv ast =
    let rec aux = function
      | ForAll _ -> raise @@ InterExn "ast:fv"
      | Implies (p1, p2) -> aux p1 @ aux p2
      | Ite (p1, p2, p3) -> aux p1 @ aux p2 @ aux p3
      | Not p -> aux p
      | And ps -> List.flatten (List.map aux ps)
      | Or ps -> List.flatten (List.map aux ps)
      | Iff (p1, p2) -> aux p1 @ aux p2
      | SpecApply (_, argsvalue) ->
          List.filter_map
            (fun e ->
              match e with
              | SE.Var (tp, name) -> Some (tp, name)
              | SE.Op (_, _, _) -> raise @@ UndefExn "ast:fv"
              | SE.Literal (_, _) -> None)
            argsvalue
    in
    aux ast

  let type_check bexpr = (bexpr, true)

  let spec_exec (args, forallf) args' env =
    let argsmap = List.combine args args' in
    let new_env =
      List.fold_left
        (fun m ((_, name), name') ->
          StrMap.add name (StrMap.find "spec_exex" env name') m)
        StrMap.empty argsmap
    in
    E.forallformula_exec forallf new_env

  let exec ast stable env =
    let rec aux = function
      | ForAll ff -> E.forallformula_exec ff env
      | Implies (e1, e2) -> if aux e1 then aux e2 else true
      | Ite (e1, e2, e3) -> if aux e1 then aux e2 else aux e3
      | Not e -> not (aux e)
      | And l -> List.for_all (fun x -> x) @@ List.map aux l
      | Or l -> List.exists (fun x -> x) @@ List.map aux l
      | Iff (e1, e2) -> aux e1 == aux e2
      | SpecApply (spec_name, args) ->
          let argsvalue = List.map (fun b -> E.SE.exec b env) args in
          let args', body = StrMap.find "ast:exec" stable spec_name in
          let env =
            List.fold_left
              (fun env ((_, k), v) -> StrMap.add k v env)
              env
              (List.combine args' argsvalue)
          in
          E.forallformula_exec body env
    in
    aux ast

  open Solver.Z3aux
  open Z3
  (* open Arithmetic *)

  (* let spec_to_z3 ctx name (args, forallf) version =
   *   let fdecl = FuncDecl.mk_func_decl_s ctx name
   *       (List.init (List.length args) (fun _ -> Integer.mk_sort ctx))
   *       (Boolean.mk_sort ctx) in
   *   let args = List.map (fun name -> tpedvar_to_z3 ctx name) args in
   *   let body = make_forall ctx args (
   *       Boolean.mk_iff ctx (FuncDecl.apply fdecl args)
   *         (E.forallformula_to_z3 ctx forallf version)) in
   *   fdecl, body *)

  let application a (spec_tab : spec StrMap.t) =
    let rec aux = function
      | ForAll ff -> ForAll ff
      | Implies (p1, p2) -> Implies (aux p1, aux p2)
      | Ite (p1, p2, p3) -> Ite (aux p1, aux p2, aux p3)
      | Not p -> Not (aux p)
      | And ps -> And (List.map aux ps)
      | Or ps -> Or (List.map aux ps)
      | Iff (p1, p2) -> Iff (aux p1, aux p2)
      | SpecApply (spec_name, argsvalue) ->
          let args, body = StrMap.find "ast::application" spec_tab spec_name in
          ForAll (E.subst_forallformula body (snd @@ List.split args) argsvalue)
    in
    aux a

  let to_z3 ctx a (spec_tab : spec StrMap.t) version vars =
    (* let ptab, bodys = make_spec_def ctx spec_tab in *)
    let rec aux = function
      | ForAll ff -> E.forallformula_to_z3 ctx ff version
      | Implies (p1, p2) -> Boolean.mk_implies ctx (aux p1) (aux p2)
      | Ite (_, _, _) ->
          raise @@ InterExn "never happen in ast to z3"
          (* (match p1 with
           *  | SpecApply (_, argsvalue) ->
           *    let b = List.last argsvalue in
           *    Boolean.mk_implies ctx (aux p1)
           *      (Boolean.mk_ite ctx (E.SE.to_z3 ctx b) (aux p2) (aux p3))
           *  | _ -> raise @@ InterExn "bad ast to z3 in cond") *)
      | Not p -> Boolean.mk_not ctx (aux p)
      | And ps -> Boolean.mk_and ctx (List.map aux ps)
      | Or ps -> Boolean.mk_or ctx (List.map aux ps)
      | Iff (p1, p2) -> Boolean.mk_iff ctx (aux p1) (aux p2)
      | SpecApply (spec_name, argsvalue) ->
          let args, body =
            StrMap.find
              (Printf.sprintf "ast::to_z3: spec(%s) no found" spec_name)
              spec_tab spec_name
          in
          E.forallformula_to_z3 ctx
            (E.subst_forallformula body (snd @@ List.split args) argsvalue)
            version
    in
    let body = aux a in
    match version with
    | V1 -> neg_avoid_timeout_constraint ctx vars body
    | V2 -> body

  (* let to_z3_with_q ctx a (spec_tab: spec StrMap.t) qv qargs =
   *   (\* let ptab, bodys = make_spec_def ctx spec_tab in *\)
   *   let rec aux = function
   *     | ForAll _ -> raise @@ InterExn "bad ast to z3 q"
   *     | Implies (p1, p2) -> Boolean.mk_implies ctx (aux p1) (aux p2)
   *     | Ite (p1, p2, p3) ->
   *       (match p1 with
   *        | SpecApply (_, argsvalue) ->
   *          let b = List.last argsvalue in
   *          Boolean.mk_implies ctx (aux p1)
   *            (Boolean.mk_ite ctx (E.SE.to_z3 ctx b) (aux p2) (aux p3))
   *        | _ -> raise @@ InterExn "bad ast to z3 q in cond")
   *     | Not p -> Boolean.mk_not ctx (aux p)
   *     | And ps -> Boolean.mk_and ctx (List.map aux ps)
   *     | Or ps -> Boolean.mk_or ctx (List.map aux ps)
   *     | Iff (p1, p2) -> Boolean.mk_iff ctx (aux p1) (aux p2)
   *     | SpecApply (spec_name, argsvalue) ->
   *       let args, body = StrMap.find
   *           (Printf.sprintf "ast::to_z3: spec(%s) no found" spec_name) spec_tab spec_name in
   *       let (qv', body') = E.subst_forallformula body (snd @@ List.split args) argsvalue in
   *       if (List.length qv) != (List.length qv')
   *       then raise @@ InterExn "unimplemented z3 q"
   *       else
   *         let qv_se = List.map (fun qv -> SE.Var (T.Int, qv)) qv in
   *         let _, qv' = List.split qv' in
   *         let body = E.subst body' qv' qv_se in
   *         E.to_z3 ctx body
   *   in
   *   let body = aux a in
   *   let qargs = List.map (tpedvar_to_z3 ctx) qargs in
   *   make_forall ctx qargs body *)

  let eliminate_cond_one ast =
    let rec aux = function
      | ForAll _ -> raise @@ InterExn "eliminate_cond:never happen"
      | Implies (p1, p2) -> Implies (aux p1, aux p2)
      | Ite (p1, p2, p3) -> (
          match p1 with
          | SpecApply (specname, argsvalue) -> (
              match argsvalue with
              | [] -> raise @@ InterExn "bad ast to z3 in cond"
              | _ ->
                  let argsvalue' = List.rev @@ List.tl @@ List.rev argsvalue in
                  Or
                    [
                      And
                        [
                          SpecApply
                            ( specname,
                              argsvalue'
                              @ [ SE.Literal (T.Bool, SE.L.Bool true) ] );
                          aux p2;
                        ];
                      And
                        [
                          SpecApply
                            ( specname,
                              argsvalue'
                              @ [ SE.Literal (T.Bool, SE.L.Bool false) ] );
                          aux p3;
                        ];
                    ])
          | _ -> raise @@ InterExn "bad ast to z3 in cond")
      | Not _ -> raise @@ InterExn "eliminate_cond:never happen"
      | And ps -> And (List.map aux ps)
      | Or ps -> Or (List.map aux ps)
      | Iff (_, _) -> raise @@ InterExn "eliminate_cond:never happen"
      | SpecApply (spec_name, argsvalue) -> SpecApply (spec_name, argsvalue)
    in
    aux ast

  let eliminate_cond ast =
    let rec aux = function
      | ForAll _ -> raise @@ InterExn "eliminate_cond:never happen"
      | Implies (p1, p2) ->
          let p1s = aux p1 in
          let p2s = aux p2 in
          List.map (fun (p1, p2) -> Implies (p1, p2)) (List.cross p1s p2s)
      | Ite (p1, p2, p3) -> (
          match p1 with
          | SpecApply (specname, argsvalue) -> (
              match argsvalue with
              | [] -> raise @@ InterExn "bad ast to z3 in cond"
              | _ ->
                  let argsvalue' = List.rev @@ List.tl @@ List.rev argsvalue in
                  let p2s = aux p2 in
                  let p3s = aux p3 in
                  List.map
                    (fun p2 ->
                      Implies
                        ( SpecApply
                            ( specname,
                              argsvalue'
                              @ [ SE.Literal (T.Bool, SE.L.Bool true) ] ),
                          p2 ))
                    p2s
                  @ List.map
                      (fun p3 ->
                        Implies
                          ( SpecApply
                              ( specname,
                                argsvalue'
                                @ [ SE.Literal (T.Bool, SE.L.Bool true) ] ),
                            p3 ))
                      p3s)
          | _ -> raise @@ InterExn "bad ast to z3 in cond")
      | Not _ -> raise @@ InterExn "eliminate_cond:never happen"
      | And ps ->
          let ps = List.map aux ps in
          List.map (fun ps -> And ps) (List.choose_list_list ps)
      | Or ps ->
          let ps = List.map aux ps in
          List.map (fun ps -> Or ps) (List.choose_list_list ps)
      | Iff (_, _) -> raise @@ InterExn "eliminate_cond:never happen"
      | SpecApply (spec_name, argsvalue) -> [ SpecApply (spec_name, argsvalue) ]
    in
    aux ast

  (* let neg_to_z3 ctx a (spec_tab: spec StrMap.t) =
   *   match a with
   *   | Implies (p, SpecApply (name, argsvalue)) ->
   *     let args, body = StrMap.find "neg_to_z3" spec_tab name in
   *     let body = E.subst_forallformula body (snd @@ List.split args) argsvalue in
   *     let fv, body = E.neg_forallf body in
   *     fv, to_z3 ctx (And [p;ForAll body]) spec_tab
   *   | _ -> raise @@ InterExn "neg_to_z3" *)

  let desugar a =
    let rec aux = function
      | ForAll ff -> ForAll ff
      | Implies (p1, p2) -> aux (Or [ Not p1; p2 ])
      | Ite (p1, p2, p3) -> aux (And [ Implies (p1, p2); Implies (Not p1, p3) ])
      | Not p -> Not (aux p)
      | And ps -> And (List.map aux ps)
      | Or ps -> Or (List.map aux ps)
      | Iff (p1, p2) -> aux (Or [ And [ p1; p2 ]; And [ Not p1; Not p2 ] ])
      | SpecApply (spec_name, argsvalue) -> SpecApply (spec_name, argsvalue)
    in
    aux a

  let to_nnf a =
    let rec aux a =
      match a with
      | ForAll _ | SpecApply (_, _) -> a
      | Not (SpecApply (_, _)) | Not (ForAll _) -> a
      | Not (Not p) -> aux p
      | Not (And ps) -> Or (List.map (fun p -> aux (Not p)) ps)
      | Not (Or ps) -> And (List.map (fun p -> aux (Not p)) ps)
      | And ps -> And (List.map aux ps)
      | Or ps -> Or (List.map aux ps)
      | _ -> raise @@ InterExn "undesugar"
    in
    aux (desugar a)

  let remove_unsat_clause a =
    let conflict a b =
      match (a, b) with
      | Not a, b ->
          (* Printf.printf "%s %s: %b\n" (layout a) (layout b) (eq a b); *)
          eq a b
      | a, Not b ->
          (* Printf.printf "%s %s: %b\n" (layout a) (layout b) (eq a b); *)
          eq a b
      | _ -> false
    in
    let rec aux a =
      match a with
      | ForAll _ | SpecApply (_, _) | Not _ -> a
      | And ps ->
          let ps = List.remove_duplicates eq (List.map aux ps) in
          if List.double_exists conflict ps then Or [] else And ps
      | Or ps ->
          let ps = List.map aux ps in
          if List.double_exists conflict ps then And [] else Or ps
      | _ -> raise @@ InterExn "undesugar"
    in
    aux a

  let skolemize_clasue = function
    | ForAll ff -> (None, ForAll ff)
    | Not (ForAll (fv, body)) ->
        let _, fv = List.split fv in
        let dts = E.related_dt body fv in
        let fv' = List.init (List.length fv) (fun _ -> Renaming.name ()) in
        let fvse' = List.map (fun n -> E.SE.Var (T.Int, n)) fv' in
        (Some (fv', dts), ForAll ([], E.subst (E.Not body) fv fvse'))
    | _ -> raise @@ InterExn "skolemize: not a nnf"

  let rec skolemize a =
    match a with
    | ForAll _ -> ([], a)
    | SpecApply (_, _) | Not (SpecApply (_, _)) ->
        raise @@ InterExn "need apply"
    | Not (ForAll (fv, body)) ->
        let fv' = List.init (List.length fv) (fun _ -> Renaming.name ()) in
        let fvse' = List.map (fun n -> E.SE.Var (T.Int, n)) fv' in
        (fv', ForAll ([], E.subst (E.Not body) (snd (List.split fv)) fvse'))
    | Or ps ->
        let newvars, ps = List.split (List.map skolemize ps) in
        (List.flatten newvars, Or ps)
    | And ps ->
        let newvars, ps = List.split (List.map skolemize ps) in
        (List.flatten newvars, And ps)
    | _ -> raise @@ InterExn "undesugar"

  let skolemize_conj = function
    | And ps ->
        let newvars, ps = List.split (List.map skolemize_clasue ps) in
        let vars, dts = List.split (List.filter_map (fun x -> x) newvars) in
        let vars, dts =
          map_double
            (fun l -> List.remove_duplicates String.equal @@ List.flatten l)
            (vars, dts)
        in
        (vars, dts, And ps)
    | _ -> raise @@ InterExn "skolemize_conj::not a conj"

  let elem_not_conj = function
    | And ps ->
        And
          (List.map
             (fun p ->
               match p with
               | ForAll _ | SpecApply (_, _) -> p
               | Not (ForAll ff) -> ForAll ff
               | Not (SpecApply (a, b)) -> SpecApply (a, b)
               | _ -> raise @@ InterExn "elem_not_conj::not a nnf")
             ps)
    | _ -> raise @@ InterExn "elem_not_conj::not a conj"

  let extract_variables a =
    let merge l =
      let a, b = List.split l in
      (List.flatten a, List.flatten b)
    in
    let rec aux = function
      | SpecApply (_, args) -> merge (List.map E.SE.var_to_tp_name args)
      | ForAll _ -> raise @@ InterExn "extract_variables"
      | Implies (p1, p2) -> merge (List.map aux [ p1; p2 ])
      | Ite (p1, p2, p3) -> merge (List.map aux [ p1; p2; p3 ])
      | Not p -> aux p
      | And ps -> merge (List.map aux ps)
      | Or ps -> merge (List.map aux ps)
      | Iff (p1, p2) -> merge (List.map aux [ p1; p2 ])
    in
    let eq (tp1, name1) (tp2, name2) =
      T.eq tp1 tp2 && String.equal name1 name2
    in
    let a, b = aux a in
    (List.remove_duplicates (fun x y -> x == y) a, List.remove_duplicates eq b)
end

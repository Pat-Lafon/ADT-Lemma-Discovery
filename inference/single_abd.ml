module P = Pred.Pred
module V = Pred.Value
module Ast = Language.SpecAst
module Epr = Ast.E
module SE = Epr.SE
module S = Solver
module SZ = S.Z3aux
module T = Tp.Tp
module F = Feature.Feature
module FV = Sample.FeatureVector
module D = Dtree.Dtree
open Utils
open Z3
open Env
open Language.Helper

let unknown_fv_fset_to_epr fset unknown_fv =
  let unknown_fv_se = List.map SE.from_tpedvar unknown_fv in
  let l =
    List.map
      (fun (f, b) -> Epr.Iff (F.to_epr f, Epr.Atom b))
      (List.combine fset unknown_fv_se)
  in
  Epr.And l

let default_spec = ([], Epr.True)

let rm_hole_from_spectab m hole =
  StrMap.update hole.name
    (fun v ->
      match v with
      | Some _ -> Some default_spec
      | None -> raise @@ InterExn "rm_hole_from_spectab")
    m

let default_constrint = Boolean.mk_true

let get_increamental_body sr =
  let _, (_, init_body) = sr.init_spec in
  let _, (_, additional_body) = sr.additional_spec in
  Epr.Or [ init_body; additional_body ]

let get_increamental_spec sr =
  let args, (qv, init_body) = sr.init_spec in
  let _, (_, additional_body) = sr.additional_spec in
  (args, (qv, Epr.Or [ init_body; additional_body ]))

let make_spec_with_unknown env =
  let fv_epr = unknown_fv_fset_to_epr env.fset env.unknown_fv in
  let body = get_increamental_body env.current in
  let spec = (env.hole.args, (env.qv, Epr.And [ Epr.Or [ body; fv_epr ] ])) in
  spec

let make_spec_with_fv env fv =
  let fv_epr =
    Epr.And
      (List.map
         (fun (f, b) -> if b then F.to_epr f else Epr.Not (F.to_epr f))
         (List.combine env.fset fv))
  in
  let body = get_increamental_body env.current in
  let spec = (env.hole.args, (env.qv, Epr.And [ Epr.Or [ body; fv_epr ] ])) in
  spec

let fv_not_in_curr_constraint env =
  let args_e =
    List.map (fun v -> Epr.Atom (SE.from_tpedvar v)) env.unknown_fv
  in
  let init_body = D.to_epr_idx env.current.init_dt args_e in
  let additional_body = D.to_epr_idx env.current.additional_dt args_e in
  Epr.Not (Epr.Or [ init_body; additional_body ])

let fv_no_repeat env =
  let unknown_fv_e =
    List.map (fun fv -> Epr.Atom (SE.from_tpedvar fv)) env.unknown_fv
  in
  let c =
    Hashtbl.fold
      (fun k v l ->
        match v with
        | D.Neg ->
            let c =
              Epr.And
                (List.map
                   (fun (arg, b) -> if b then arg else Epr.Not arg)
                   (List.combine unknown_fv_e k))
            in
            c :: l
        | D.Pos | D.MayNeg -> l)
      env.fvtab []
  in
  let c = Epr.Not (Epr.Or c) in
  c

type pos_fv = NoPosFv | MayNoPosFv | PosFv of bool list

let pos_query_c = ref 0

let pos_query ctx vc_env env stat =
  let _ = addadd stat.num_pos_query in
  let pre = Ast.Or (List.map (fun flow -> flow.pre_flow) vc_env.multi_pre) in
  let spec = make_spec_with_unknown env in
  let new_spectable =
    StrMap.update env.hole.name
      (fun v ->
        match v with
        | None -> raise @@ InterExn "never happen multi_apply_constraint"
        | Some _ -> Some spec)
      vc_env.spectable
  in
  let force_enum_neg = Epr.to_z3 ctx (fv_not_in_curr_constraint env) in
  let force_no_repeat = Epr.to_z3 ctx @@ fv_no_repeat env in
  let build_pos_query version =
    let pos_phi =
      Ast.to_z3 ctx
        (Ast.Implies (pre, vc_env.post))
        new_spectable version vc_env.vars
    in
    Boolean.mk_and ctx [ pos_phi; force_enum_neg; force_no_repeat ]
  in
  let handle_model m =
    let fv = S.get_unknown_fv ctx m env.unknown_fv in
    (* let _ = Printf.printf "fset = %s\n" (F.layout_set env.fset) in
     * let _ = Printf.printf "may pos:fv = %s\n" (boollist_to_string fv) in *)
    PosFv fv
  in
  (* let _ = if String.equal env.hole.name "top" then
   *     if !pos_query_c > 2 then
   *       let _ = Printf.printf "%s\n" (Expr.to_string @@ build_pos_query SZ.V2) in
   *       let _ = Hashtbl.iter (fun vec label ->
   *           Printf.printf "<%s>:%s\n" (boollist_to_string vec) (D.layout_label label)
   *         ) env.fvtab in
   *       raise @@ InterExn "pos end"
   *     else ()
   *   else ()
   * in *)
  let version = SZ.V1 in
  let pos_query = build_pos_query version in
  (* let _ = Printf.printf "pos_query:\n%s\n" (Expr.to_string pos_query) in *)
  let _ = addadd stat.num_z3_pos_query in
  match S.check ctx pos_query with
  | S.SmtUnsat -> NoPosFv
  (* let version = SZ.V2 in
   * let pos_query = build_pos_query version in
   * (match S.check ctx pos_query with
   *  | S.SmtUnsat -> NoPosFv
   *  | S.Timeout -> MayNoPosFv
   *    (\* raise @@ InterExn (Printf.sprintf "[%s]pos query time out!" (SZ.layout_imp_version version)) *\)
   *  | S.SmtSat m -> handle_model m) *)
  | S.Timeout -> MayNoPosFv
  (* raise @@ InterExn (Printf.sprintf "[%s]pos query time out!" (SZ.layout_imp_version version)) *)
  | S.SmtSat m -> handle_model m

open Printf

type smt_status = Pass | NeedRefine
(* | FailBack *)

let gather_neg_fvec_to_tab_flow ctx env applied_args qvrange model =
  let se_range = List.map (fun x -> SE.Literal (T.Int, SE.L.Int x)) qvrange in
  let sub_assignment = List.map (fun _ -> se_range) env.qv in
  let _, names = List.split (env.hole.args @ env.qv) in
  let counter = ref 0 in
  let _ =
    List.map
      (fun args ->
        (* let args = List.map SE.from_tpedvar args in *)
        let extract_fvec _ values =
          let vec =
            List.map
              (fun feature ->
                Epr.subst (F.to_epr feature) names (args @ values))
              env.fset
          in
          (* let _ = printf "[vec]:%s\n" (List.to_string Epr.layout vec) in *)
          let vec' =
            List.map (fun e -> S.get_pred model (Epr.to_z3 ctx e)) vec
          in
          (* let _ = printf "[vec]:%s%s\n" (List.to_string Epr.layout vec)
           *     (boollist_to_string vec') in *)
          match Hashtbl.find_opt env.fvtab vec' with
          | Some D.Neg ->
              let _ =
                printf "additional_dt:\n%s\n"
                  (Ast.layout_spec @@ env.current.additional_spec)
              in
              let _ =
                printf "[fset]:%s\n%s\n"
                  (List.to_string F.layout env.fset)
                  (boollist_to_string vec')
              in
              let _ =
                printf "add:%b\n"
                  (D.exec_vector_idx env.current.additional_dt vec')
              in
              let _ =
                printf "init:%b\n" (D.exec_vector_idx env.current.init_dt vec')
              in
              raise @@ InterExn "never happen single gather"
          | Some D.Pos -> ()
          | Some D.MayNeg ->
              let _ = counter := !counter + 1 in
              ()
          | None ->
              let _ = counter := !counter + 1 in
              (* Hashtbl.add env.fvtab vec' D.MayNeg *)
              if D.exec_vector_idx env.current.init_dt vec' then
                Hashtbl.add env.fvtab vec' D.Pos
              else Hashtbl.add env.fvtab vec' D.MayNeg
        in
        let _ =
          List.choose_list_list_order_fold extract_fvec () sub_assignment
        in
        ())
      applied_args
  in
  let _ =
    if !counter == 0 then raise @@ InterExn "never happen gather neg single abd"
    else ()
  in
  ()

let gather_neg_fvec_to_tab ctx vc_env env qvrange model =
  List.iter
    (fun flow ->
      let applied_args =
        StrMap.find "[single] gather_neg_fvec_to_tab" flow.applied_args_map
          env.hole.name
      in
      gather_neg_fvec_to_tab_flow ctx env applied_args qvrange model)
    vc_env.multi_pre

let pos_verify_flow ctx vc_env env flow fv stat =
  (* let _ = StrMap.iter (fun name args ->
   *     printf "%s: [%s]\n" name (List.to_string
   *                                 (fun x -> List.to_string T.layouttvar x)
   *                                 args
   *                              )
   *   ) flow.applied_args_map iin
   * let _ = printf "env.hole.name:%s\n" env.hole.name in *)
  match StrMap.find_opt flow.applied_args_map env.hole.name with
  | None -> true
  | _ ->
      let spec = make_spec_with_fv env fv in
      let new_spectable =
        StrMap.update env.hole.name
          (fun v ->
            match v with
            | None -> raise @@ InterExn "never happen multi_apply_constraint"
            | Some _ -> Some spec)
          vc_env.spectable
      in
      let build_neg_phi version =
        Ast.to_z3 ctx
          (Ast.Not (Ast.Implies (flow.pre_flow, vc_env.post)))
          new_spectable version vc_env.vars
      in
      let version = SZ.V1 in
      let neg_phi = build_neg_phi version in
      (* let _ = Printf.printf "verify:%s\n" (Expr.to_string neg_phi) in *)
      let _ = addadd stat.num_z3_pos_verify in
      let if_pos =
        match S.check ctx neg_phi with
        | S.SmtUnsat ->
            (* let _ = Printf.printf "real pos[%s]\n" (boollist_to_string fv) in *)
            true
        | S.Timeout -> false
        (* raise @@ InterExn (Printf.sprintf "[%s]pos verify time out!" (SZ.layout_imp_version version)) *)
        (* let version = SZ.V1 in
         * let neg_phi = build_neg_phi version in
         * (match S.check ctx neg_phi with
         *  | S.SmtUnsat | S.Timeout -> raise (InterExn "verify candidate pos time out!")
         *  | S.SmtSat _ -> false) *)
        | S.SmtSat _ ->
            (* let _ = if List.eq (fun x y -> x == y) fv [true;true;true;true;true] then
             *     let _ = printf "%s\n" (Expr.to_string neg_phi) in
             *     let _ = printf "%s\n" (Model.to_string m) in
             *     ()
             *     else () in *)
            (* let _ = Printf.printf "false pos[%s]\n" (boollist_to_string fv) in *)
            false
      in
      if_pos

let pos_verify_update_env ctx vc_env env fv stat =
  let _ = addadd stat.num_pos_verify in
  let if_pos =
    List.fold_left
      (fun if_pos flow ->
        if if_pos then pos_verify_flow ctx vc_env env flow fv stat else false)
      true vc_env.multi_pre
  in
  let _ =
    match (Hashtbl.find_opt env.fvtab fv, if_pos) with
    | Some D.Pos, b ->
        (* let _ = Hashtbl.iter (fun vec label ->
         *     printf "%s -> <%s>\n" (boollist_to_string vec) (D.layout_label label)
         *   ) env.fvtab in *)
        raise
        @@ InterExn
             (sprintf "never happen in single abduction(%s,%b)"
                (D.layout_label D.Pos) b)
    | Some D.Neg, b ->
        raise
        @@ InterExn
             (sprintf "never happen in single abduction(%s,%b)"
                (D.layout_label D.Neg) b)
    | Some D.MayNeg, true -> Hashtbl.replace env.fvtab fv D.Pos
    | Some D.MayNeg, false | None, false -> Hashtbl.replace env.fvtab fv D.Neg
    | None, true -> Hashtbl.add env.fvtab fv D.Pos
  in
  if_pos

let body_to_spec env body = (env.hole.args, (env.qv, body))

let summary_fv_num env =
  let pos_num = ref 0 in
  let neg_num = ref 0 in
  let mayneg_num = ref 0 in
  let _ =
    Hashtbl.iter
      (fun _ label ->
        match label with
        | D.Pos -> pos_num := !pos_num + 1
        | D.Neg -> neg_num := !neg_num + 1
        | D.MayNeg -> mayneg_num := !mayneg_num + 1)
      env.fvtab
  in
  let _ =
    printf "{pos:%i; neg:%i; maynge:%i}\n" !pos_num !neg_num !mayneg_num
  in
  ()

let is_pass = function Pass -> true | _ -> false

let neg_query ctx vc_env env new_sr stat =
  let _ = addadd stat.num_neg_query in
  let counter = ref 0 in
  let rec loop new_sr =
    let new_spectable =
      StrMap.update env.hole.name
        (fun v ->
          match v with
          | None -> raise @@ InterExn "never happen multi_apply_constraint"
          | Some _ -> Some (get_increamental_spec new_sr))
        vc_env.spectable
    in
    let once flow =
      match StrMap.find_opt flow.applied_args_map env.hole.name with
      | None -> Pass
      | _ -> (
          let handle_sat m version =
            let bounds = S.Z3aux.get_preds_interp m version in
            let applied_args =
              StrMap.find "gather_neg_fvec_to_tab_flow" flow.applied_args_map
                env.hole.name
            in
            let _ = gather_neg_fvec_to_tab_flow ctx env applied_args bounds m in
            (* let _ = Hashtbl.iter (fun vec label ->
             *     printf "%s:%s\n" (boollist_to_string vec) (D.layout_label label)
             *   ) env.fvtab in *)
            let _ = summary_fv_num env in
            NeedRefine
          in
          let build_neg_phi version =
            Ast.to_z3 ctx
              (Ast.Not (Ast.Implies (flow.pre_flow, vc_env.post)))
              new_spectable version vc_env.vars
          in
          let version = SZ.V1 in
          let neg_phi = build_neg_phi version in
          (* let _ = Printf.printf "neg_query ast:%s\n"
           *   (Ast.vc_layout (Ast.Not (Ast.Implies (flow.pre_flow, vc_env.post)))) in
           * let _ = StrMap.iter (fun name spec ->
           *   printf "%s\n" (Ast.layout_spec_entry name spec)
           * ) new_spectable in
           * let _ = Printf.printf "neg_query:%s\n" (Expr.to_string neg_phi) in *)
          let _ = addadd stat.num_z3_neg_query in
          match S.check ctx neg_phi with
          | S.SmtUnsat -> Pass
          | S.Timeout -> Pass
          (* raise @@ InterExn (Printf.sprintf "[%s]neg query time out!" (SZ.layout_imp_version version)) *)
          (* let _ = Printf.printf "neg_query:%s\n" (Expr.to_string neg_phi) in
           * let version = SZ.V1 in
           * let neg_phi = build_neg_phi version in
           * (match S.check ctx neg_phi with
           *  | S.SmtUnsat | S.Timeout -> raise (InterExn "neg query time out!")
           *  | S.SmtSat m -> handle_sat m version) *)
          | S.SmtSat m -> handle_sat m version)
    in
    let res = List.map once vc_env.multi_pre in
    if List.for_all is_pass res then if !counter == 0 then Pass else NeedRefine
    else
      let dt, dt_idx =
        if Hashtbl.length env.fvtab == 0 then (D.T, D.T)
        else D.classify_hash env.fset env.fvtab D.is_pos
      in
      let learned = body_to_spec env @@ Epr.simplify_dt_result @@ D.to_epr dt in
      let new_sr' =
        { new_sr with additional_dt = dt_idx; additional_spec = learned }
      in
      let _ = counter := !counter + 1 in
      loop new_sr'
  in
  loop new_sr

let weaker_safe_loop ctx vc_env env stat =
  let rec loop () =
    let dt_spec, dt_idx =
      if Hashtbl.length env.fvtab == 0 then (D.T, D.T)
      else D.classify_hash env.fset env.fvtab D.is_pos
    in
    let learned_body = Epr.simplify_dt_result @@ D.to_epr dt_spec in
    let new_spec = body_to_spec env learned_body in
    let new_sr =
      { env.current with additional_dt = dt_idx; additional_spec = new_spec }
    in
    (* let _ = Printf.printf "learn_weaker:\n%s\n" (Ast.layout_spec new_spec) in *)
    match neg_query ctx vc_env env new_sr stat with
    | Pass ->
        let new_spectable =
          StrMap.update env.hole.name
            (fun v ->
              match v with
              | None -> raise @@ InterExn "never happen multi_apply_constraint"
              | Some _ -> Some (get_increamental_spec new_sr))
            vc_env.spectable
        in
        ( { vc_env with spectable = new_spectable },
          { env with current = new_sr } )
    | NeedRefine -> loop ()
  in
  loop ()

let refresh_single_abd_env env =
  let _ =
    Hashtbl.filter_map_inplace
      (fun _ label ->
        match label with
        | D.Pos -> Some D.Pos
        | D.Neg -> Some D.MayNeg
        | D.MayNeg -> Some D.MayNeg)
      env.fvtab
  in
  ()

let update_vc_env vc_env spec_env =
  let new_spectable =
    StrMap.update spec_env.hole.name
      (fun v ->
        match v with
        | None -> raise @@ InterExn "refresh_vc_env"
        | Some _ -> Some (get_increamental_spec spec_env.current))
      vc_env.spectable
  in
  { vc_env with spectable = new_spectable }

type pos_loop_result = NoWeaker | MayNoWeaker | NewWeaker of spec_env

let start_time = ref (Sys.time ())

let update_stat stat delta_time =
  let _ = addadd stat.num_weakening in
  let weaken_run_time = delta_time -. !(stat.run_time) in
  let rec aux weaken_run_time l =
    let rest = stat.interval -. !(stat.interval_past) in
    if weaken_run_time > rest then
      let _ = stat.interval_past := 0.0 in
      aux (weaken_run_time -. rest) (0 :: l)
    else
      let _ = stat.interval_past := !(stat.interval_past) +. weaken_run_time in
      match l with
      | [] -> raise @@ InterExn "never happen single update_stat"
      | h :: t -> (h + 1) :: t
  in
  let _ =
    stat.num_weakening_every_interval :=
      aux weaken_run_time !(stat.num_weakening_every_interval)
  in
  let _ = stat.run_time := delta_time in
  ()

let record_interval = 3600.0
let last_record = ref 0.0

let record_stat benchname vc env stat delta_time time_bound =
  if delta_time > !last_record +. record_interval then
    let _ = last_record := delta_time in
    let filename = sprintf "%s%i" env.hole.name (int_of_float !last_record) in
    let _ = save_stat benchname filename time_bound stat in
    let _ =
      Yojson.Basic.to_file
        (sprintf "%s%s_tmp_sr.json" benchname filename)
        (Env.encode_single_infer_result (vc.preds, env.current))
    in
    ()
  else ()

let infer ctx benchname vc_env env time_bound =
  let stat = stat_init env in
  let _ = start_time := Sys.time () in
  if env.if_maximal then (AlreadyMaxed env, stat)
  else
    let _ = Printf.printf "single infer: %s\n" env.hole.name in
    let _ = Printf.printf "env.fset: %s\n" (F.layout_set env.fset) in
    let _ = summary_fv_num env in
    let max_loop_counter = ref 0 in
    let rec max_loop vc_env env =
      let rec find_pos env =
        match clock "pos_query" (fun _ -> pos_query ctx vc_env env stat) with
        | NoPosFv -> NoWeaker
        | MayNoPosFv -> MayNoWeaker
        | PosFv fv ->
            let if_pos =
              clock "pos_verify_update_env" (fun _ ->
                  pos_verify_update_env ctx vc_env env fv stat)
            in
            if not if_pos then find_pos env else NewWeaker env
      in
      match find_pos env with
      | NoWeaker ->
          if !max_loop_counter == 0 then AlreadyMaxed env
          else NewMaxed (vc_env, env)
      | MayNoWeaker ->
          if !max_loop_counter == 0 then MayAlreadyMaxed env
          else Weaker (vc_env, env)
      | NewWeaker env -> (
          let _ = max_loop_counter := !max_loop_counter + 1 in
          let vc_env, env =
            clock "weaker_safe_loop" (fun _ ->
                weaker_safe_loop ctx vc_env env stat)
          in
          (* let _ = Printf.printf "new current:\n%s\n" (Ast.layout_spec env.current) in *)
          let end_time = Sys.time () in
          let delta_time = end_time -. !start_time in
          let _ = update_stat stat delta_time in
          (* let _ = record_stat benchname env.hole.name stat delta_time time_bound in *)
          match time_bound with
          | None ->
              let _ =
                record_stat benchname vc_env env stat delta_time time_bound
              in
              max_loop vc_env env
          | Some time_bound ->
              if delta_time > time_bound then Weaker (vc_env, env)
              else max_loop vc_env env)
    in
    let env_opt = max_loop vc_env env in
    let env_opt' =
      match env_opt with
      | AlreadyMaxed env ->
          let _ = Printf.printf "already maxed:\n" in
          let _ = add_end_stat env stat in
          AlreadyMaxed { env with if_maximal = true }
      | MayAlreadyMaxed env ->
          let _ = Printf.printf "may already maxed:\n" in
          let _ = add_end_stat env stat in
          MayAlreadyMaxed { env with if_maximal = true }
      | NewMaxed (vc, env) ->
          let _ = Printf.printf "new max spec:\n" in
          let _ = add_end_stat env stat in
          NewMaxed (vc, { env with if_maximal = true })
      | Weaker (_, _) ->
          let _ = Printf.printf "weaker spec:\n" in
          let _ = add_end_stat env stat in
          env_opt
    in
    (env_opt', stat)

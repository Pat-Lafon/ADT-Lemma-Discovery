(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Detection of partial matches and unused match cases. *)

open Misc
open Asttypes
open Types
open Typedtree

(*************************************)
(* Utilities for building patterns   *)
(*************************************)

let make_pat desc ty tenv =
  {
    pat_desc = desc;
    pat_loc = Location.none;
    pat_extra = [];
    pat_type = ty;
    pat_env = tenv;
    pat_attributes = [];
  }

let omega = make_pat Tpat_any Ctype.none Env.empty

let extra_pat =
  make_pat (Tpat_var (Ident.create "+", mknoloc "+")) Ctype.none Env.empty

let rec omegas i = if i <= 0 then [] else omega :: omegas (i - 1)
let omega_list l = List.map (fun _ -> omega) l
let zero = make_pat (Tpat_constant (Const_int 0)) Ctype.none Env.empty

(***********************)
(* Compatibility check *)
(***********************)

(* p and q compatible means, there exists V that matches both *)

let is_absent tag row = Btype.row_field tag !row = Rabsent

let is_absent_pat p =
  match p.pat_desc with
  | Tpat_variant (tag, _, row) -> is_absent tag row
  | _ -> false

let const_compare x y =
  match (x, y) with
  | Const_float f1, Const_float f2 ->
      compare (float_of_string f1) (float_of_string f2)
  | Const_string (s1, _), Const_string (s2, _) -> String.compare s1 s2
  | _, _ -> compare x y

let records_args l1 l2 =
  (* Invariant: fields are already sorted by Typecore.type_label_a_list *)
  let rec combine r1 r2 l1 l2 =
    match (l1, l2) with
    | [], [] -> (List.rev r1, List.rev r2)
    | [], (_, _, p2) :: rem2 -> combine (omega :: r1) (p2 :: r2) [] rem2
    | (_, _, p1) :: rem1, [] -> combine (p1 :: r1) (omega :: r2) rem1 []
    | (_, lbl1, p1) :: rem1, (_, lbl2, p2) :: rem2 ->
        if lbl1.lbl_pos < lbl2.lbl_pos then
          combine (p1 :: r1) (omega :: r2) rem1 l2
        else if lbl1.lbl_pos > lbl2.lbl_pos then
          combine (omega :: r1) (p2 :: r2) l1 rem2
        else
          (* same label on both sides *)
          combine (p1 :: r1) (p2 :: r2) rem1 rem2
  in
  combine [] [] l1 l2

let rec compat p q =
  match (p.pat_desc, q.pat_desc) with
  | Tpat_alias (p, _, _), _ -> compat p q
  | _, Tpat_alias (q, _, _) -> compat p q
  | (Tpat_any | Tpat_var _), _ -> true
  | _, (Tpat_any | Tpat_var _) -> true
  | Tpat_or (p1, p2, _), _ -> compat p1 q || compat p2 q
  | _, Tpat_or (q1, q2, _) -> compat p q1 || compat p q2
  | Tpat_constant c1, Tpat_constant c2 -> const_compare c1 c2 = 0
  | Tpat_tuple ps, Tpat_tuple qs -> compats ps qs
  | Tpat_lazy p, Tpat_lazy q -> compat p q
  | Tpat_construct (_, c1, ps1), Tpat_construct (_, c2, ps2) ->
      c1.cstr_tag = c2.cstr_tag && compats ps1 ps2
  | Tpat_variant (l1, Some p1, r1), Tpat_variant (l2, Some p2, _) ->
      l1 = l2 && compat p1 p2
  | Tpat_variant (l1, None, r1), Tpat_variant (l2, None, _) -> l1 = l2
  | Tpat_variant (_, None, _), Tpat_variant (_, Some _, _) -> false
  | Tpat_variant (_, Some _, _), Tpat_variant (_, None, _) -> false
  | Tpat_record (l1, _), Tpat_record (l2, _) ->
      let ps, qs = records_args l1 l2 in
      compats ps qs
  | Tpat_array ps, Tpat_array qs ->
      List.length ps = List.length qs && compats ps qs
  | _, _ -> assert false

and compats ps qs =
  match (ps, qs) with
  | [], [] -> true
  | p :: ps, q :: qs -> compat p q && compats ps qs
  | _, _ -> assert false

exception Empty (* Empty pattern *)

(****************************************)
(* Utilities for retrieving type paths  *)
(****************************************)

(* May need a clean copy, cf. PR#4745 *)
let clean_copy ty =
  if ty.level = Btype.generic_level then ty
  else Subst.type_expr Subst.identity ty

let get_type_path ty tenv =
  let ty = Ctype.repr (Ctype.expand_head tenv (clean_copy ty)) in
  match ty.desc with
  | Tconstr (path, _, _) -> path
  | _ -> fatal_error "Parmatch.get_type_path"

(*************************************)
(* Values as patterns pretty printer *)
(*************************************)

open Format

let is_cons = function { cstr_name = "::" } -> true | _ -> false

let pretty_const c =
  match c with
  | Const_int i -> Printf.sprintf "%d" i
  | Const_char c -> Printf.sprintf "%C" c
  | Const_string (s, _) -> Printf.sprintf "%S" s
  | Const_float f -> Printf.sprintf "%s" f
  | Const_int32 i -> Printf.sprintf "%ldl" i
  | Const_int64 i -> Printf.sprintf "%LdL" i
  | Const_nativeint i -> Printf.sprintf "%ndn" i

let rec pretty_val ppf v =
  match v.pat_extra with
  | (cstr, _loc, _attrs) :: rem -> (
      match cstr with
      | Tpat_unpack ->
          fprintf ppf "@[(module %a)@]" pretty_val { v with pat_extra = rem }
      | Tpat_constraint ctyp ->
          fprintf ppf "@[(%a : _)@]" pretty_val { v with pat_extra = rem }
      | Tpat_type _ ->
          fprintf ppf "@[(# %a)@]" pretty_val { v with pat_extra = rem })
  | [] -> (
      match v.pat_desc with
      | Tpat_any -> fprintf ppf "_"
      | Tpat_var (x, _) -> Ident.print ppf x
      | Tpat_constant c -> fprintf ppf "%s" (pretty_const c)
      | Tpat_tuple vs -> fprintf ppf "@[(%a)@]" (pretty_vals ",") vs
      | Tpat_construct (_, cstr, []) -> fprintf ppf "%s" cstr.cstr_name
      | Tpat_construct (_, cstr, [ w ]) ->
          fprintf ppf "@[<2>%s@ %a@]" cstr.cstr_name pretty_arg w
      | Tpat_construct (_, cstr, vs) -> (
          let name = cstr.cstr_name in
          match (name, vs) with
          | "::", [ v1; v2 ] ->
              fprintf ppf "@[%a::@,%a@]" pretty_car v1 pretty_cdr v2
          | _ -> fprintf ppf "@[<2>%s@ @[(%a)@]@]" name (pretty_vals ",") vs)
      | Tpat_variant (l, None, _) -> fprintf ppf "`%s" l
      | Tpat_variant (l, Some w, _) ->
          fprintf ppf "@[<2>`%s@ %a@]" l pretty_arg w
      | Tpat_record (lvs, _) ->
          fprintf ppf "@[{%a}@]" pretty_lvals
            (List.filter
               (function
                 | _, _, { pat_desc = Tpat_any } ->
                     false (* do not show lbl=_ *)
                 | _ -> true)
               lvs)
      | Tpat_array vs -> fprintf ppf "@[[| %a |]@]" (pretty_vals " ;") vs
      | Tpat_lazy v -> fprintf ppf "@[<2>lazy@ %a@]" pretty_arg v
      | Tpat_alias (v, x, _) ->
          fprintf ppf "@[(%a@ as %a)@]" pretty_val v Ident.print x
      | Tpat_or (v, w, _) -> fprintf ppf "@[(%a|@,%a)@]" pretty_or v pretty_or w
      )

and pretty_car ppf v =
  match v.pat_desc with
  | Tpat_construct (_, cstr, [ _; _ ]) when is_cons cstr ->
      fprintf ppf "(%a)" pretty_val v
  | _ -> pretty_val ppf v

and pretty_cdr ppf v =
  match v.pat_desc with
  | Tpat_construct (_, cstr, [ v1; v2 ]) when is_cons cstr ->
      fprintf ppf "%a::@,%a" pretty_car v1 pretty_cdr v2
  | _ -> pretty_val ppf v

and pretty_arg ppf v =
  match v.pat_desc with
  | Tpat_construct (_, _, _ :: _) | Tpat_variant (_, Some _, _) ->
      fprintf ppf "(%a)" pretty_val v
  | _ -> pretty_val ppf v

and pretty_or ppf v =
  match v.pat_desc with
  | Tpat_or (v, w, _) -> fprintf ppf "%a|@,%a" pretty_or v pretty_or w
  | _ -> pretty_val ppf v

and pretty_vals sep ppf = function
  | [] -> ()
  | [ v ] -> pretty_val ppf v
  | v :: vs -> fprintf ppf "%a%s@ %a" pretty_val v sep (pretty_vals sep) vs

and pretty_lvals ppf = function
  | [] -> ()
  | [ (_, lbl, v) ] -> fprintf ppf "%s=%a" lbl.lbl_name pretty_val v
  | (_, lbl, v) :: rest ->
      fprintf ppf "%s=%a;@ %a" lbl.lbl_name pretty_val v pretty_lvals rest

let top_pretty ppf v = fprintf ppf "@[%a@]@?" pretty_val v

let pretty_pat p =
  top_pretty Format.str_formatter p;
  prerr_string (Format.flush_str_formatter ())

type matrix = pattern list list

let pretty_line ps =
  List.iter
    (fun p ->
      top_pretty Format.str_formatter p;
      prerr_string " <";
      prerr_string (Format.flush_str_formatter ());
      prerr_string ">")
    ps

let pretty_matrix (pss : matrix) =
  prerr_endline "begin matrix";
  List.iter
    (fun ps ->
      pretty_line ps;
      prerr_endline "")
    pss;
  prerr_endline "end matrix"

(****************************)
(* Utilities for matching   *)
(****************************)

(* Check top matching *)
let simple_match p1 p2 =
  match (p1.pat_desc, p2.pat_desc) with
  | Tpat_construct (_, c1, _), Tpat_construct (_, c2, _) ->
      c1.cstr_tag = c2.cstr_tag
  | Tpat_variant (l1, _, _), Tpat_variant (l2, _, _) -> l1 = l2
  | Tpat_constant c1, Tpat_constant c2 -> const_compare c1 c2 = 0
  | Tpat_tuple _, Tpat_tuple _ -> true
  | Tpat_lazy _, Tpat_lazy _ -> true
  | Tpat_record _, Tpat_record _ -> true
  | Tpat_array p1s, Tpat_array p2s -> List.length p1s = List.length p2s
  | _, (Tpat_any | Tpat_var _) -> true
  | _, _ -> false

(* extract record fields as a whole *)
let record_arg p =
  match p.pat_desc with
  | Tpat_any -> []
  | Tpat_record (args, _) -> args
  | _ -> fatal_error "Parmatch.as_record"

(* Raise Not_found when pos is not present in arg *)
let get_field pos arg =
  let _, _, p = List.find (fun (_, lbl, _) -> pos = lbl.lbl_pos) arg in
  p

let extract_fields omegas arg =
  List.map
    (fun (_, lbl, _) -> try get_field lbl.lbl_pos arg with Not_found -> omega)
    omegas

let all_record_args lbls =
  match lbls with
  | (_, { lbl_all }, _) :: _ ->
      let t =
        Array.map
          (fun lbl -> (mknoloc (Longident.Lident "?temp?"), lbl, omega))
          lbl_all
      in
      List.iter (fun ((_, lbl, _) as x) -> t.(lbl.lbl_pos) <- x) lbls;
      Array.to_list t
  | _ -> fatal_error "Parmatch.all_record_args"

(* Build argument list when p2 >= p1, where p1 is a simple pattern *)
let rec simple_match_args p1 p2 =
  match p2.pat_desc with
  | Tpat_alias (p2, _, _) -> simple_match_args p1 p2
  | Tpat_construct (_, cstr, args) -> args
  | Tpat_variant (lab, Some arg, _) -> [ arg ]
  | Tpat_tuple args -> args
  | Tpat_record (args, _) -> extract_fields (record_arg p1) args
  | Tpat_array args -> args
  | Tpat_lazy arg -> [ arg ]
  | Tpat_any | Tpat_var _ -> (
      match p1.pat_desc with
      | Tpat_construct (_, _, args) -> omega_list args
      | Tpat_variant (_, Some _, _) -> [ omega ]
      | Tpat_tuple args -> omega_list args
      | Tpat_record (args, _) -> omega_list args
      | Tpat_array args -> omega_list args
      | Tpat_lazy _ -> [ omega ]
      | _ -> [])
  | _ -> []

(*
  Normalize a pattern ->
   all arguments are omega (simple pattern) and no more variables
*)

let rec normalize_pat q =
  match q.pat_desc with
  | Tpat_any | Tpat_constant _ -> q
  | Tpat_var _ -> make_pat Tpat_any q.pat_type q.pat_env
  | Tpat_alias (p, _, _) -> normalize_pat p
  | Tpat_tuple args ->
      make_pat (Tpat_tuple (omega_list args)) q.pat_type q.pat_env
  | Tpat_construct (lid, c, args) ->
      make_pat (Tpat_construct (lid, c, omega_list args)) q.pat_type q.pat_env
  | Tpat_variant (l, arg, row) ->
      make_pat
        (Tpat_variant (l, may_map (fun _ -> omega) arg, row))
        q.pat_type q.pat_env
  | Tpat_array args ->
      make_pat (Tpat_array (omega_list args)) q.pat_type q.pat_env
  | Tpat_record (largs, closed) ->
      make_pat
        (Tpat_record
           (List.map (fun (lid, lbl, _) -> (lid, lbl, omega)) largs, closed))
        q.pat_type q.pat_env
  | Tpat_lazy _ -> make_pat (Tpat_lazy omega) q.pat_type q.pat_env
  | Tpat_or _ -> fatal_error "Parmatch.normalize_pat"

(*
  Build normalized (cf. supra) discriminating pattern,
  in the non-data type case
*)

let discr_pat q pss =
  let rec acc_pat acc pss =
    match pss with
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
        acc_pat acc ((p :: ps) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
        acc_pat acc ((p1 :: ps) :: (p2 :: ps) :: pss)
    | ({ pat_desc = Tpat_any | Tpat_var _ } :: _) :: pss -> acc_pat acc pss
    | (({ pat_desc = Tpat_tuple _ } as p) :: _) :: _ -> normalize_pat p
    | (({ pat_desc = Tpat_lazy _ } as p) :: _) :: _ -> normalize_pat p
    | (({ pat_desc = Tpat_record (largs, closed) } as p) :: _) :: pss ->
        let new_omegas =
          List.fold_right
            (fun (lid, lbl, _) r ->
              try
                let _ = get_field lbl.lbl_pos r in
                r
              with Not_found -> (lid, lbl, omega) :: r)
            largs (record_arg acc)
        in
        acc_pat
          (make_pat (Tpat_record (new_omegas, closed)) p.pat_type p.pat_env)
          pss
    | _ -> acc
  in

  match normalize_pat q with
  | { pat_desc = Tpat_any | Tpat_record _ } as q -> acc_pat q pss
  | q -> q

(*
   In case a matching value is found, set actual arguments
   of the matching pattern.
*)

let rec read_args xs r =
  match (xs, r) with
  | [], _ -> ([], r)
  | _ :: xs, arg :: rest ->
      let args, rest = read_args xs rest in
      (arg :: args, rest)
  | _, _ -> fatal_error "Parmatch.read_args"

let do_set_args erase_mutable q r =
  match q with
  | { pat_desc = Tpat_tuple omegas } ->
      let args, rest = read_args omegas r in
      make_pat (Tpat_tuple args) q.pat_type q.pat_env :: rest
  | { pat_desc = Tpat_record (omegas, closed) } ->
      let args, rest = read_args omegas r in
      make_pat
        (Tpat_record
           ( List.map2
               (fun (lid, lbl, _) arg ->
                 if
                   erase_mutable
                   &&
                   match lbl.lbl_mut with Mutable -> true | Immutable -> false
                 then (lid, lbl, omega)
                 else (lid, lbl, arg))
               omegas args,
             closed ))
        q.pat_type q.pat_env
      :: rest
  | { pat_desc = Tpat_construct (lid, c, omegas) } ->
      let args, rest = read_args omegas r in
      make_pat (Tpat_construct (lid, c, args)) q.pat_type q.pat_env :: rest
  | { pat_desc = Tpat_variant (l, omega, row) } ->
      let arg, rest =
        match (omega, r) with
        | Some _, a :: r -> (Some a, r)
        | None, r -> (None, r)
        | _ -> assert false
      in
      make_pat (Tpat_variant (l, arg, row)) q.pat_type q.pat_env :: rest
  | { pat_desc = Tpat_lazy omega } -> (
      match r with
      | arg :: rest -> make_pat (Tpat_lazy arg) q.pat_type q.pat_env :: rest
      | _ -> fatal_error "Parmatch.do_set_args (lazy)")
  | { pat_desc = Tpat_array omegas } ->
      let args, rest = read_args omegas r in
      make_pat (Tpat_array args) q.pat_type q.pat_env :: rest
  | { pat_desc = Tpat_constant _ | Tpat_any } ->
      q :: r (* case any is used in matching.ml *)
  | _ -> fatal_error "Parmatch.set_args"

let set_args q r = do_set_args false q r
and set_args_erase_mutable q r = do_set_args true q r

(* filter pss acording to pattern q *)
let filter_one q pss =
  let rec filter_rec = function
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
        filter_rec ((p :: ps) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
        filter_rec ((p1 :: ps) :: (p2 :: ps) :: pss)
    | (p :: ps) :: pss ->
        if simple_match q p then (simple_match_args q p @ ps) :: filter_rec pss
        else filter_rec pss
    | _ -> []
  in
  filter_rec pss

(*
  Filter pss in the ``extra case''. This applies :
  - According to an extra constructor (datatype case, non-complete signature).
  - Acordinng to anything (all-variables case).
*)
let filter_extra pss =
  let rec filter_rec = function
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
        filter_rec ((p :: ps) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
        filter_rec ((p1 :: ps) :: (p2 :: ps) :: pss)
    | ({ pat_desc = Tpat_any | Tpat_var _ } :: qs) :: pss ->
        qs :: filter_rec pss
    | _ :: pss -> filter_rec pss
    | [] -> []
  in
  filter_rec pss

(*
  Pattern p0 is the discriminating pattern,
  returns [(q0,pss0) ; ... ; (qn,pssn)]
  where the qi's are simple patterns and the pssi's are
  matched matrices.

  NOTES
   * (qi,[]) is impossible.
   * In the case when matching is useless (all-variable case),
     returns []
*)

let filter_all pat0 pss =
  let rec insert q qs env =
    match env with
    | [] ->
        let q0 = normalize_pat q in
        [ (q0, [ simple_match_args q0 q @ qs ]) ]
    | ((q0, pss) as c) :: env ->
        if simple_match q0 q then
          (q0, (simple_match_args q0 q @ qs) :: pss) :: env
        else c :: insert q qs env
  in

  let rec filter_rec env = function
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
        filter_rec env ((p :: ps) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
        filter_rec env ((p1 :: ps) :: (p2 :: ps) :: pss)
    | ({ pat_desc = Tpat_any | Tpat_var _ } :: _) :: pss -> filter_rec env pss
    | (p :: ps) :: pss -> filter_rec (insert p ps env) pss
    | _ -> env
  and filter_omega env = function
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
        filter_omega env ((p :: ps) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
        filter_omega env ((p1 :: ps) :: (p2 :: ps) :: pss)
    | ({ pat_desc = Tpat_any | Tpat_var _ } :: ps) :: pss ->
        filter_omega
          (List.map
             (fun (q, qss) -> (q, (simple_match_args q omega @ ps) :: qss))
             env)
          pss
    | _ :: pss -> filter_omega env pss
    | [] -> env
  in

  filter_omega
    (filter_rec
       (match pat0.pat_desc with
       | Tpat_record _ | Tpat_tuple _ | Tpat_lazy _ -> [ (pat0, []) ]
       | _ -> [])
       pss)
    pss

(* Variant related functions *)

let rec set_last a = function
  | [] -> []
  | [ _ ] -> [ a ]
  | x :: l -> x :: set_last a l

(* mark constructor lines for failure when they are incomplete *)
let rec mark_partial = function
  | ({ pat_desc = Tpat_alias (p, _, _) } :: ps) :: pss ->
      mark_partial ((p :: ps) :: pss)
  | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps) :: pss ->
      mark_partial ((p1 :: ps) :: (p2 :: ps) :: pss)
  | ({ pat_desc = Tpat_any | Tpat_var _ } :: _ as ps) :: pss ->
      ps :: mark_partial pss
  | ps :: pss -> set_last zero ps :: mark_partial pss
  | [] -> []

let close_variant env row =
  let row = Btype.row_repr row in
  let nm =
    List.fold_left
      (fun nm (tag, f) ->
        match Btype.row_field_repr f with
        | Reither (_, _, false, e) ->
            (* m=false means that this tag is not explicitly matched *)
            Btype.set_row_field e Rabsent;
            None
        | Rabsent | Reither (_, _, true, _) | Rpresent _ -> nm)
      row.row_name row.row_fields
  in
  if (not row.row_closed) || nm != row.row_name then
    (* this unification cannot fail *)
    Ctype.unify env row.row_more
      (Btype.newgenty
         (Tvariant
            {
              row with
              row_fields = [];
              row_more = Btype.newgenvar ();
              row_closed = true;
              row_name = nm;
            }))

let row_of_pat pat =
  match Ctype.expand_head pat.pat_env pat.pat_type with
  | { desc = Tvariant row } -> Btype.row_repr row
  | _ -> assert false

(*
  Check whether the first column of env makes up a complete signature or
  not.
*)

let generalized_constructor x =
  match x with
  | { pat_desc = Tpat_construct (_, c, _); pat_env = env }, _ ->
      c.cstr_generalized
  | _ -> assert false

let clean_env env =
  let rec loop = function
    | [] -> []
    | x :: xs -> if generalized_constructor x then loop xs else x :: loop xs
  in
  loop env

let full_match closing env =
  match env with
  | ({ pat_desc = Tpat_construct (_, c, _); pat_type = typ }, _) :: _ ->
      if c.cstr_consts < 0 then false (* extensions *)
      else List.length env = c.cstr_consts + c.cstr_nonconsts
  | (({ pat_desc = Tpat_variant _ } as p), _) :: _ ->
      let fields =
        List.map
          (function
            | { pat_desc = Tpat_variant (tag, _, _) }, _ -> tag
            | _ -> assert false)
          env
      in
      let row = row_of_pat p in
      if closing && not (Btype.row_fixed row) then
        (* closing=true, we are considering the variant as closed *)
        List.for_all
          (fun (tag, f) ->
            match Btype.row_field_repr f with
            | Rabsent | Reither (_, _, false, _) -> true
            | Reither (_, _, true, _)
            (* m=true, do not discard matched tags, rather warn *)
            | Rpresent _ ->
                List.mem tag fields)
          row.row_fields
      else
        row.row_closed
        && List.for_all
             (fun (tag, f) ->
               Btype.row_field_repr f = Rabsent || List.mem tag fields)
             row.row_fields
  | ({ pat_desc = Tpat_constant (Const_char _) }, _) :: _ ->
      List.length env = 256
  | ({ pat_desc = Tpat_constant _ }, _) :: _ -> false
  | ({ pat_desc = Tpat_tuple _ }, _) :: _ -> true
  | ({ pat_desc = Tpat_record _ }, _) :: _ -> true
  | ({ pat_desc = Tpat_array _ }, _) :: _ -> false
  | ({ pat_desc = Tpat_lazy _ }, _) :: _ -> true
  | _ -> fatal_error "Parmatch.full_match"

let should_extend ext env =
  match ext with
  | None -> false
  | Some ext -> (
      match env with
      | ( ({
             pat_desc =
               Tpat_construct
                 (_, { cstr_tag = Cstr_constant _ | Cstr_block _ }, _);
           } as p),
          _ )
        :: _ ->
          let path = get_type_path p.pat_type p.pat_env in
          Path.same path ext
      | _ -> false)

(* complement constructor tags *)
let complete_tags nconsts nconstrs tags =
  let seen_const = Array.make nconsts false
  and seen_constr = Array.make nconstrs false in
  List.iter
    (function
      | Cstr_constant i -> seen_const.(i) <- true
      | Cstr_block i -> seen_constr.(i) <- true
      | _ -> assert false)
    tags;
  let r = ref [] in
  for i = 0 to nconsts - 1 do
    if not seen_const.(i) then r := Cstr_constant i :: !r
  done;
  for i = 0 to nconstrs - 1 do
    if not seen_constr.(i) then r := Cstr_block i :: !r
  done;
  !r

(* build a pattern from a constructor list *)
let pat_of_constr ex_pat cstr =
  {
    ex_pat with
    pat_desc =
      Tpat_construct
        ( mknoloc (Longident.Lident "?pat_of_constr?"),
          cstr,
          omegas cstr.cstr_arity );
  }

let orify x y = make_pat (Tpat_or (x, y, None)) x.pat_type x.pat_env

let rec orify_many = function
  | [] -> assert false
  | [ x ] -> x
  | x :: xs -> orify x (orify_many xs)

let pat_of_constrs ex_pat cstrs =
  if cstrs = [] then raise Empty
  else orify_many (List.map (pat_of_constr ex_pat) cstrs)

let pats_of_type ?(always = false) env ty =
  let ty' = Ctype.expand_head env ty in
  match ty'.desc with
  | Tconstr (path, _, _) -> (
      try
        match (Env.find_type path env).type_kind with
        | Type_variant cl
          when always
               || List.length cl = 1
               || List.for_all (fun cd -> cd.Types.cd_res <> None) cl ->
            let cstrs = fst (Env.find_type_descrs path env) in
            List.map (pat_of_constr (make_pat Tpat_any ty env)) cstrs
        | Type_record (ldl, _) ->
            let labels = snd (Env.find_type_descrs path env) in
            let fields =
              List.map
                (fun ld ->
                  (mknoloc (Longident.Lident "?pat_of_label?"), ld, omega))
                labels
            in
            [ make_pat (Tpat_record (fields, Closed)) ty env ]
        | _ -> [ omega ]
      with Not_found -> [ omega ])
  | Ttuple tl -> [ make_pat (Tpat_tuple (omegas (List.length tl))) ty env ]
  | _ -> [ omega ]

let rec get_variant_constructors env ty =
  match (Ctype.repr ty).desc with
  | Tconstr (path, _, _) -> (
      try
        match Env.find_type path env with
        | { type_kind = Type_variant _ } -> fst (Env.find_type_descrs path env)
        | { type_manifest = Some _ } ->
            get_variant_constructors env
              (Ctype.expand_head_once env (clean_copy ty))
        | _ -> fatal_error "Parmatch.get_variant_constructors"
      with Not_found -> fatal_error "Parmatch.get_variant_constructors")
  | _ -> fatal_error "Parmatch.get_variant_constructors"

let rec map_filter f = function
  | [] -> []
  | x :: xs -> (
      match f x with None -> map_filter f xs | Some y -> y :: map_filter f xs)

(* Sends back a pattern that complements constructor tags all_tag *)
let complete_constrs p all_tags =
  let c =
    match p.pat_desc with Tpat_construct (_, c, _) -> c | _ -> assert false
  in
  let not_tags = complete_tags c.cstr_consts c.cstr_nonconsts all_tags in
  let constrs = get_variant_constructors p.pat_env c.cstr_res in
  let others =
    List.filter (fun cnstr -> List.mem cnstr.cstr_tag not_tags) constrs
  in
  let const, nonconst =
    List.partition (fun cnstr -> cnstr.cstr_arity = 0) others
  in
  const @ nonconst

let build_other_constrs env p =
  match p.pat_desc with
  | Tpat_construct (_, { cstr_tag = Cstr_constant _ | Cstr_block _ }, _) ->
      let get_tag = function
        | { pat_desc = Tpat_construct (_, c, _) } -> c.cstr_tag
        | _ -> fatal_error "Parmatch.get_tag"
      in
      let all_tags = List.map (fun (p, _) -> get_tag p) env in
      pat_of_constrs p (complete_constrs p all_tags)
  | _ -> extra_pat

(* Auxiliary for build_other *)

let build_other_constant proj make first next p env =
  let all = List.map (fun (p, _) -> proj p.pat_desc) env in
  let rec try_const i =
    if List.mem i all then try_const (next i)
    else make_pat (make i) p.pat_type p.pat_env
  in
  try_const first

(*
  Builds a pattern that is incompatible with all patterns in
  in the first column of env
*)

let build_other ext env =
  match env with
  | ( {
        pat_desc =
          Tpat_construct (lid, ({ cstr_tag = Cstr_extension _ } as c), _);
      },
      _ )
    :: _ ->
      let c = { c with cstr_name = "*extension*" } in
      make_pat (Tpat_construct (lid, c, [])) Ctype.none Env.empty
  | (({ pat_desc = Tpat_construct (_, cd, _) } as p), _) :: _ -> (
      match ext with
      | Some ext when Path.same ext (get_type_path p.pat_type p.pat_env) ->
          extra_pat
      | _ -> build_other_constrs env p)
  | (({ pat_desc = Tpat_variant (_, _, r) } as p), _) :: _ -> (
      let tags =
        List.map
          (function
            | { pat_desc = Tpat_variant (tag, _, _) }, _ -> tag
            | _ -> assert false)
          env
      in
      let row = row_of_pat p in
      let make_other_pat tag const =
        let arg = if const then None else Some omega in
        make_pat (Tpat_variant (tag, arg, r)) p.pat_type p.pat_env
      in
      match
        List.fold_left
          (fun others (tag, f) ->
            if List.mem tag tags then others
            else
              match Btype.row_field_repr f with
              | Rabsent (* | Reither _ *) -> others
              (* This one is called after erasing pattern info *)
              | Reither (c, _, _, _) -> make_other_pat tag c :: others
              | Rpresent arg -> make_other_pat tag (arg = None) :: others)
          [] row.row_fields
      with
      | [] -> make_other_pat "AnyExtraTag" true
      | pat :: other_pats ->
          List.fold_left
            (fun p_res pat ->
              make_pat (Tpat_or (pat, p_res, None)) p.pat_type p.pat_env)
            pat other_pats)
  | (({ pat_desc = Tpat_constant (Const_char _) } as p), _) :: _ ->
      let all_chars =
        List.map
          (fun (p, _) ->
            match p.pat_desc with
            | Tpat_constant (Const_char c) -> c
            | _ -> assert false)
          env
      in

      let rec find_other i imax =
        if i > imax then raise Not_found
        else
          let ci = Char.chr i in
          if List.mem ci all_chars then find_other (i + 1) imax
          else make_pat (Tpat_constant (Const_char ci)) p.pat_type p.pat_env
      in
      let rec try_chars = function
        | [] -> omega
        | (c1, c2) :: rest -> (
            try find_other (Char.code c1) (Char.code c2)
            with Not_found -> try_chars rest)
      in

      try_chars
        [
          ('a', 'z');
          ('A', 'Z');
          ('0', '9');
          (' ', '~');
          (Char.chr 0, Char.chr 255);
        ]
  | (({ pat_desc = Tpat_constant (Const_int _) } as p), _) :: _ ->
      build_other_constant
        (function Tpat_constant (Const_int i) -> i | _ -> assert false)
        (function i -> Tpat_constant (Const_int i))
        0 succ p env
  | (({ pat_desc = Tpat_constant (Const_int32 _) } as p), _) :: _ ->
      build_other_constant
        (function Tpat_constant (Const_int32 i) -> i | _ -> assert false)
        (function i -> Tpat_constant (Const_int32 i))
        0l Int32.succ p env
  | (({ pat_desc = Tpat_constant (Const_int64 _) } as p), _) :: _ ->
      build_other_constant
        (function Tpat_constant (Const_int64 i) -> i | _ -> assert false)
        (function i -> Tpat_constant (Const_int64 i))
        0L Int64.succ p env
  | (({ pat_desc = Tpat_constant (Const_nativeint _) } as p), _) :: _ ->
      build_other_constant
        (function Tpat_constant (Const_nativeint i) -> i | _ -> assert false)
        (function i -> Tpat_constant (Const_nativeint i))
        0n Nativeint.succ p env
  | (({ pat_desc = Tpat_constant (Const_string _) } as p), _) :: _ ->
      build_other_constant
        (function
          | Tpat_constant (Const_string (s, _)) -> String.length s
          | _ -> assert false)
        (function i -> Tpat_constant (Const_string (String.make i '*', None)))
        0 succ p env
  | (({ pat_desc = Tpat_constant (Const_float _) } as p), _) :: _ ->
      build_other_constant
        (function
          | Tpat_constant (Const_float f) -> float_of_string f
          | _ -> assert false)
        (function f -> Tpat_constant (Const_float (string_of_float f)))
        0.0
        (fun f -> f +. 1.0)
        p env
  | (({ pat_desc = Tpat_array args } as p), _) :: _ ->
      let all_lengths =
        List.map
          (fun (p, _) ->
            match p.pat_desc with
            | Tpat_array args -> List.length args
            | _ -> assert false)
          env
      in
      let rec try_arrays l =
        if List.mem l all_lengths then try_arrays (l + 1)
        else make_pat (Tpat_array (omegas l)) p.pat_type p.pat_env
      in
      try_arrays 0
  | [] -> omega
  | _ -> omega

(*
  Core function :
  Is the last row of pattern matrix pss + qs satisfiable ?
  That is :
    Does there exists at least one value vector, es such that :
     1- for all ps in pss ps # es (ps and es are not compatible)
     2- qs <= es                  (es matches qs)
*)

let rec has_instance p =
  match p.pat_desc with
  | Tpat_variant (l, _, r) when is_absent l r -> false
  | Tpat_any | Tpat_var _ | Tpat_constant _ | Tpat_variant (_, None, _) -> true
  | Tpat_alias (p, _, _) | Tpat_variant (_, Some p, _) -> has_instance p
  | Tpat_or (p1, p2, _) -> has_instance p1 || has_instance p2
  | Tpat_construct (_, _, ps) | Tpat_tuple ps | Tpat_array ps ->
      has_instances ps
  | Tpat_record (lps, _) -> has_instances (List.map (fun (_, _, x) -> x) lps)
  | Tpat_lazy p -> has_instance p

and has_instances = function
  | [] -> true
  | q :: rem -> has_instance q && has_instances rem

let rec satisfiable pss qs =
  match pss with
  | [] -> has_instances qs
  | _ -> (
      match qs with
      | [] -> false
      | { pat_desc = Tpat_or (q1, q2, _) } :: qs ->
          satisfiable pss (q1 :: qs) || satisfiable pss (q2 :: qs)
      | { pat_desc = Tpat_alias (q, _, _) } :: qs -> satisfiable pss (q :: qs)
      | { pat_desc = Tpat_any | Tpat_var _ } :: qs -> (
          let q0 = discr_pat omega pss in
          match filter_all q0 pss with
          (* first column of pss is made of variables only *)
          | [] -> satisfiable (filter_extra pss) qs
          | constrs ->
              if full_match false constrs then
                List.exists
                  (fun (p, pss) ->
                    (not (is_absent_pat p))
                    && satisfiable pss (simple_match_args p omega @ qs))
                  constrs
              else satisfiable (filter_extra pss) qs)
      | { pat_desc = Tpat_variant (l, _, r) } :: _ when is_absent l r -> false
      | q :: qs ->
          let q0 = discr_pat q pss in
          satisfiable (filter_one q0 pss) (simple_match_args q0 q @ qs))

(* Also return the remaining cases, to enable GADT handling *)
let rec satisfiables pss qs =
  match pss with
  | [] -> if has_instances qs then [ qs ] else []
  | _ -> (
      match qs with
      | [] -> []
      | { pat_desc = Tpat_or (q1, q2, _) } :: qs ->
          satisfiables pss (q1 :: qs) @ satisfiables pss (q2 :: qs)
      | { pat_desc = Tpat_alias (q, _, _) } :: qs -> satisfiables pss (q :: qs)
      | { pat_desc = Tpat_any | Tpat_var _ } :: qs -> (
          let q0 = discr_pat omega pss in
          let wild p =
            List.map (fun qs -> p :: qs) (satisfiables (filter_extra pss) qs)
          in
          match filter_all q0 pss with
          (* first column of pss is made of variables only *)
          | [] -> wild omega
          | (p, _) :: _ as constrs -> (
              let for_constrs () =
                List.flatten
                  (List.map
                     (fun (p, pss) ->
                       if is_absent_pat p then []
                       else
                         List.map (set_args p)
                           (satisfiables pss (simple_match_args p omega @ qs)))
                     constrs)
              in
              if full_match false constrs then for_constrs ()
              else
                match p.pat_desc with
                | Tpat_construct _ ->
                    (* activate this code for checking non-gadt constructors *)
                    wild (build_other_constrs constrs p) @ for_constrs ()
                | _ -> wild omega))
      | { pat_desc = Tpat_variant (l, _, r) } :: _ when is_absent l r -> []
      | q :: qs ->
          let q0 = discr_pat q pss in
          List.map (set_args q0)
            (satisfiables (filter_one q0 pss) (simple_match_args q0 q @ qs)))

(*
  Now another satisfiable function that additionally
  supplies an example of a matching value.

  This function should be called for exhaustiveness check only.
*)

type 'a result =
  | Rnone (* No matching value *)
  | Rsome of 'a (* This matching value *)

let rec try_many f = function
  | [] -> Rnone
  | (p, pss) :: rest -> (
      match f (p, pss) with Rnone -> try_many f rest | r -> r)

let rappend r1 r2 =
  match (r1, r2) with
  | Rnone, _ -> r2
  | _, Rnone -> r1
  | Rsome l1, Rsome l2 -> Rsome (l1 @ l2)

let rec try_many_gadt f = function
  | [] -> Rnone
  | (p, pss) :: rest -> rappend (f (p, pss)) (try_many_gadt f rest)

(*
let rec exhaust ext pss n = match pss with
| []    ->  Rsome (omegas n)
| []::_ ->  Rnone
| pss   ->
    let q0 = discr_pat omega pss in
    begin match filter_all q0 pss with
          (* first column of pss is made of variables only *)
    | [] ->
        begin match exhaust ext (filter_extra pss) (n-1) with
        | Rsome r -> Rsome (q0::r)
        | r -> r
      end
    | constrs ->
        let try_non_omega (p,pss) =
          if is_absent_pat p then
            Rnone
          else
            match
              exhaust
                ext pss (List.length (simple_match_args p omega) + n - 1)
            with
            | Rsome r -> Rsome (set_args p r)
            | r       -> r in
        if
          full_match true false constrs && not (should_extend ext constrs)
        then
          try_many try_non_omega constrs
        else
          (*
             D = filter_extra pss is the default matrix
             as it is included in pss, one can avoid
             recursive calls on specialized matrices,
             Essentially :
             * D exhaustive => pss exhaustive
             * D non-exhaustive => we have a non-filtered value
          *)
          let r =  exhaust ext (filter_extra pss) (n-1) in
          match r with
          | Rnone -> Rnone
          | Rsome r ->
              try
                Rsome (build_other ext constrs::r)
              with
      (* cannot occur, since constructors don't make a full signature *)
              | Empty -> fatal_error "Parmatch.exhaust"
    end

let combinations f lst lst' =
  let rec iter2 x =
    function
        [] -> []
      | y :: ys ->
          f x y :: iter2 x ys
  in
  let rec iter =
    function
        [] -> []
      | x :: xs -> iter2 x lst' @ iter xs
  in
  iter lst
*)
(*
let print_pat pat =
  let rec string_of_pat pat =
    match pat.pat_desc with
        Tpat_var _ -> "v"
      | Tpat_any -> "_"
      | Tpat_alias (p, x) -> Printf.sprintf "(%s) as ?"  (string_of_pat p)
      | Tpat_constant n -> "0"
      | Tpat_construct (_, lid, _) ->
        Printf.sprintf "%s" (String.concat "." (Longident.flatten lid.txt))
      | Tpat_lazy p ->
        Printf.sprintf "(lazy %s)" (string_of_pat p)
      | Tpat_or (p1,p2,_) ->
        Printf.sprintf "(%s | %s)" (string_of_pat p1) (string_of_pat p2)
      | Tpat_tuple list ->
        Printf.sprintf "(%s)" (String.concat "," (List.map string_of_pat list))
      | Tpat_variant (_, _, _) -> "variant"
      | Tpat_record (_, _) -> "record"
      | Tpat_array _ -> "array"
  in
  Printf.fprintf stderr "PAT[%s]\n%!" (string_of_pat pat)
*)

(* strictly more powerful than exhaust; however, exhaust
   was kept for backwards compatibility *)
let rec exhaust_gadt (ext : Path.t option) pss n =
  match pss with
  | [] -> Rsome [ omegas n ]
  | [] :: _ -> Rnone
  | pss -> (
      let q0 = discr_pat omega pss in
      match filter_all q0 pss with
      (* first column of pss is made of variables only *)
      | [] -> (
          match exhaust_gadt ext (filter_extra pss) (n - 1) with
          | Rsome r -> Rsome (List.map (fun row -> q0 :: row) r)
          | r -> r)
      | constrs -> (
          let try_non_omega (p, pss) =
            if is_absent_pat p then Rnone
            else
              match
                exhaust_gadt ext pss
                  (List.length (simple_match_args p omega) + n - 1)
              with
              | Rsome r -> Rsome (List.map (fun row -> set_args p row) r)
              | r -> r
          in
          let before = try_many_gadt try_non_omega constrs in
          if full_match false constrs && not (should_extend ext constrs) then
            before
          else
            (*
            D = filter_extra pss is the default matrix
            as it is included in pss, one can avoid
            recursive calls on specialized matrices,
            Essentially :
             * D exhaustive => pss exhaustive
             * D non-exhaustive => we have a non-filtered value
             *)
            let r = exhaust_gadt ext (filter_extra pss) (n - 1) in
            match r with
            | Rnone -> before
            | Rsome r -> (
                try
                  let p = build_other ext constrs in
                  let dug = List.map (fun tail -> p :: tail) r in
                  match before with
                  | Rnone -> Rsome dug
                  | Rsome x -> Rsome (x @ dug)
                with
                (* cannot occur, since constructors don't make a full signature *)
                | Empty ->
                  fatal_error "Parmatch.exhaust")))

let exhaust_gadt ext pss n =
  let ret = exhaust_gadt ext pss n in
  match ret with
  | Rnone -> Rnone
  | Rsome lst ->
      (* The following line is needed to compile stdlib/printf.ml *)
      if lst = [] then Rsome (omegas n)
      else
        let singletons =
          List.map (function [ x ] -> x | _ -> assert false) lst
        in
        Rsome [ orify_many singletons ]

(*
   Another exhaustiveness check, enforcing variant typing.
   Note that it does not check exact exhaustiveness, but whether a
   matching could be made exhaustive by closing all variant types.
   When this is true of all other columns, the current column is left
   open (even if it means that the whole matching is not exhaustive as
   a result).
   When this is false for the matrix minus the current column, and the
   current column is composed of variant tags, we close the variant
   (even if it doesn't help in making the matching exhaustive).
*)

let rec pressure_variants tdefs = function
  | [] -> false
  | [] :: _ -> true
  | pss -> (
      let q0 = discr_pat omega pss in
      match filter_all q0 pss with
      | [] -> pressure_variants tdefs (filter_extra pss)
      | constrs ->
          let rec try_non_omega = function
            | (p, pss) :: rem ->
                let ok = pressure_variants tdefs pss in
                try_non_omega rem && ok
            | [] -> true
          in
          if full_match (tdefs = None) constrs then try_non_omega constrs
          else if tdefs = None then pressure_variants None (filter_extra pss)
          else
            let full = full_match true constrs in
            let ok =
              if full then try_non_omega constrs
              else try_non_omega (filter_all q0 (mark_partial pss))
            in
            (match (constrs, tdefs) with
            | (({ pat_desc = Tpat_variant _ } as p), _) :: _, Some env ->
                let row = row_of_pat p in
                if
                  Btype.row_fixed row
                  || pressure_variants None (filter_extra pss)
                then ()
                else close_variant env row
            | _ -> ());
            ok)

(* Yet another satisfiable fonction *)

(*
   This time every_satisfiable pss qs checks the
   utility of every expansion of qs.
   Expansion means expansion of or-patterns inside qs
*)

type answer =
  | Used (* Useful pattern *)
  | Unused (* Useless pattern *)
  | Upartial of Typedtree.pattern list (* Mixed, with list of useless ones *)

(* this row type enable column processing inside the matrix
    - left  ->  elements not to be processed,
    - right ->  elements to be processed
*)
type 'a row = { no_ors : 'a list; ors : 'a list; active : 'a list }

(*
let pretty_row {ors=ors ; no_ors=no_ors; active=active} =
  pretty_line ors ; prerr_string " *" ;
  pretty_line no_ors ; prerr_string " *" ;
  pretty_line active

let pretty_rows rs =
  prerr_endline "begin matrix" ;
  List.iter
    (fun r ->
      pretty_row r ;
      prerr_endline "")
    rs ;
  prerr_endline "end matrix"
*)

(* Initial build *)
let make_row ps = { ors = []; no_ors = []; active = ps }
let make_rows pss = List.map make_row pss

(* Useful to detect and expand  or pats inside as pats *)
let rec unalias p =
  match p.pat_desc with Tpat_alias (p, _, _) -> unalias p | _ -> p

let is_var p =
  match (unalias p).pat_desc with Tpat_any | Tpat_var _ -> true | _ -> false

let is_var_column rs =
  List.for_all
    (fun r -> match r.active with p :: _ -> is_var p | [] -> assert false)
    rs

(* Standard or-args for left-to-right matching *)
let rec or_args p =
  match p.pat_desc with
  | Tpat_or (p1, p2, _) -> (p1, p2)
  | Tpat_alias (p, _, _) -> or_args p
  | _ -> assert false

(* Just remove current column *)
let remove r =
  match r.active with _ :: rem -> { r with active = rem } | [] -> assert false

let remove_column rs = List.map remove rs

(* Current column has been processed *)
let push_no_or r =
  match r.active with
  | p :: rem -> { r with no_ors = p :: r.no_ors; active = rem }
  | [] -> assert false

let push_or r =
  match r.active with
  | p :: rem -> { r with ors = p :: r.ors; active = rem }
  | [] -> assert false

let push_or_column rs = List.map push_or rs
and push_no_or_column rs = List.map push_no_or rs

(* Those are adaptations of the previous homonymous functions that
   work on the current column, instead of the first column
*)

let discr_pat q rs = discr_pat q (List.map (fun r -> r.active) rs)

let filter_one q rs =
  let rec filter_rec rs =
    match rs with
    | [] -> []
    | r :: rem -> (
        match r.active with
        | [] -> assert false
        | { pat_desc = Tpat_alias (p, _, _) } :: ps ->
            filter_rec ({ r with active = p :: ps } :: rem)
        | { pat_desc = Tpat_or (p1, p2, _) } :: ps ->
            filter_rec
              ({ r with active = p1 :: ps }
              :: { r with active = p2 :: ps }
              :: rem)
        | p :: ps ->
            if simple_match q p then
              { r with active = simple_match_args q p @ ps } :: filter_rec rem
            else filter_rec rem)
  in
  filter_rec rs

(* Back to normal matrices *)
let make_vector r = r.no_ors
let make_matrix rs = List.map make_vector rs

(* Standard union on answers *)
let union_res r1 r2 =
  match (r1, r2) with
  | Unused, _ | _, Unused -> Unused
  | Used, _ -> r2
  | _, Used -> r1
  | Upartial u1, Upartial u2 -> Upartial (u1 @ u2)

(* propose or pats for expansion *)
let extract_elements qs =
  let rec do_rec seen = function
    | [] -> []
    | q :: rem ->
        {
          no_ors = List.rev_append seen rem @ qs.no_ors;
          ors = [];
          active = [ q ];
        }
        :: do_rec (q :: seen) rem
  in
  do_rec [] qs.ors

(* idem for matrices *)
let transpose rs =
  match rs with
  | [] -> assert false
  | r :: rem ->
      let i = List.map (fun x -> [ x ]) r in
      List.fold_left (List.map2 (fun r x -> x :: r)) i rem

let extract_columns pss qs =
  match pss with
  | [] -> List.map (fun _ -> []) qs.ors
  | _ ->
      let rows = List.map extract_elements pss in
      transpose rows

(* Core function
   The idea is to first look for or patterns (recursive case), then
   check or-patterns argument usefulness (terminal case)
*)

let rec every_satisfiables pss qs =
  match qs.active with
  | [] -> (
      (* qs is now partitionned,  check usefulness *)
      match qs.ors with
      | [] ->
          (* no or-patterns *)
          if satisfiable (make_matrix pss) (make_vector qs) then Used
          else Unused
      | _ ->
          (* n or-patterns -> 2n expansions *)
          List.fold_right2
            (fun pss qs r ->
              match r with
              | Unused -> Unused
              | _ -> (
                  match qs.active with
                  | [ q ] ->
                      let q1, q2 = or_args q in
                      let r_loc = every_both pss qs q1 q2 in
                      union_res r r_loc
                  | _ -> assert false))
            (extract_columns pss qs) (extract_elements qs) Used)
  | q :: rem -> (
      let uq = unalias q in
      match uq.pat_desc with
      | Tpat_any | Tpat_var _ ->
          if is_var_column pss then
            (* forget about ``all-variable''  columns now *)
            every_satisfiables (remove_column pss) (remove qs)
          else
            (* otherwise this is direct food for satisfiable *)
            every_satisfiables (push_no_or_column pss) (push_no_or qs)
      | Tpat_or (q1, q2, _) ->
          if q1.pat_loc.Location.loc_ghost && q2.pat_loc.Location.loc_ghost then
            (* syntactically generated or-pats should not be expanded *)
            every_satisfiables (push_no_or_column pss) (push_no_or qs)
          else
            (* this is a real or-pattern *)
            every_satisfiables (push_or_column pss) (push_or qs)
      | Tpat_variant (l, _, r) when is_absent l r ->
          (* Ah Jacques... *)
          Unused
      | _ ->
          (* standard case, filter matrix *)
          let q0 = discr_pat q pss in
          every_satisfiables (filter_one q0 pss)
            { qs with active = simple_match_args q0 q @ rem })

(*
  This function ``every_both'' performs the usefulness check
  of or-pat q1|q2.
  The trick is to call every_satisfied twice with
  current active columns restricted to q1 and q2,
  That way,
  - others orpats in qs.ors will not get expanded.
  - all matching work performed on qs.no_ors is not performed again.
  *)
and every_both pss qs q1 q2 =
  let qs1 = { qs with active = [ q1 ] } and qs2 = { qs with active = [ q2 ] } in
  let r1 = every_satisfiables pss qs1
  and r2 = every_satisfiables (if compat q1 q2 then qs1 :: pss else pss) qs2 in
  match r1 with
  | Unused -> (
      match r2 with
      | Unused -> Unused
      | Used -> Upartial [ q1 ]
      | Upartial u2 -> Upartial (q1 :: u2))
  | Used -> ( match r2 with Unused -> Upartial [ q2 ] | _ -> r2)
  | Upartial u1 -> (
      match r2 with
      | Unused -> Upartial (u1 @ [ q2 ])
      | Used -> r1
      | Upartial u2 -> Upartial (u1 @ u2))

(* le_pat p q  means, forall V,  V matches q implies V matches p *)
let rec le_pat p q =
  match (p.pat_desc, q.pat_desc) with
  | (Tpat_var _ | Tpat_any), _ -> true
  | Tpat_alias (p, _, _), _ -> le_pat p q
  | _, Tpat_alias (q, _, _) -> le_pat p q
  | Tpat_constant c1, Tpat_constant c2 -> const_compare c1 c2 = 0
  | Tpat_construct (_, c1, ps), Tpat_construct (_, c2, qs) ->
      c1.cstr_tag = c2.cstr_tag && le_pats ps qs
  | Tpat_variant (l1, Some p1, _), Tpat_variant (l2, Some p2, _) ->
      l1 = l2 && le_pat p1 p2
  | Tpat_variant (l1, None, r1), Tpat_variant (l2, None, _) -> l1 = l2
  | Tpat_variant (_, _, _), Tpat_variant (_, _, _) -> false
  | Tpat_tuple ps, Tpat_tuple qs -> le_pats ps qs
  | Tpat_lazy p, Tpat_lazy q -> le_pat p q
  | Tpat_record (l1, _), Tpat_record (l2, _) ->
      let ps, qs = records_args l1 l2 in
      le_pats ps qs
  | Tpat_array ps, Tpat_array qs ->
      List.length ps = List.length qs && le_pats ps qs
  (* In all other cases, enumeration is performed *)
  | _, _ -> not (satisfiable [ [ p ] ] [ q ])

and le_pats ps qs =
  match (ps, qs) with
  | p :: ps, q :: qs -> le_pat p q && le_pats ps qs
  | _, _ -> true

let get_mins le ps =
  let rec select_rec r = function
    | [] -> r
    | p :: ps ->
        if List.exists (fun p0 -> le p0 p) ps then select_rec r ps
        else select_rec (p :: r) ps
  in
  select_rec [] (select_rec [] ps)

(*
  lub p q is a pattern that matches all values matched by p and q
  may raise Empty, when p and q are not compatible
*)

let rec lub p q =
  match (p.pat_desc, q.pat_desc) with
  | Tpat_alias (p, _, _), _ -> lub p q
  | _, Tpat_alias (q, _, _) -> lub p q
  | (Tpat_any | Tpat_var _), _ -> q
  | _, (Tpat_any | Tpat_var _) -> p
  | Tpat_or (p1, p2, _), _ -> orlub p1 p2 q
  | _, Tpat_or (q1, q2, _) -> orlub q1 q2 p (* Thanks god, lub is commutative *)
  | Tpat_constant c1, Tpat_constant c2 when const_compare c1 c2 = 0 -> p
  | Tpat_tuple ps, Tpat_tuple qs ->
      let rs = lubs ps qs in
      make_pat (Tpat_tuple rs) p.pat_type p.pat_env
  | Tpat_lazy p, Tpat_lazy q ->
      let r = lub p q in
      make_pat (Tpat_lazy r) p.pat_type p.pat_env
  | Tpat_construct (lid, c1, ps1), Tpat_construct (_, c2, ps2)
    when c1.cstr_tag = c2.cstr_tag ->
      let rs = lubs ps1 ps2 in
      make_pat (Tpat_construct (lid, c1, rs)) p.pat_type p.pat_env
  | Tpat_variant (l1, Some p1, row), Tpat_variant (l2, Some p2, _) when l1 = l2
    ->
      let r = lub p1 p2 in
      make_pat (Tpat_variant (l1, Some r, row)) p.pat_type p.pat_env
  | Tpat_variant (l1, None, row), Tpat_variant (l2, None, _) when l1 = l2 -> p
  | Tpat_record (l1, closed), Tpat_record (l2, _) ->
      let rs = record_lubs l1 l2 in
      make_pat (Tpat_record (rs, closed)) p.pat_type p.pat_env
  | Tpat_array ps, Tpat_array qs when List.length ps = List.length qs ->
      let rs = lubs ps qs in
      make_pat (Tpat_array rs) p.pat_type p.pat_env
  | _, _ -> raise Empty

and orlub p1 p2 q =
  try
    let r1 = lub p1 q in
    try { q with pat_desc = Tpat_or (r1, lub p2 q, None) } with Empty -> r1
  with Empty -> lub p2 q

and record_lubs l1 l2 =
  let rec lub_rec l1 l2 =
    match (l1, l2) with
    | [], _ -> l2
    | _, [] -> l1
    | (lid1, lbl1, p1) :: rem1, (lid2, lbl2, p2) :: rem2 ->
        if lbl1.lbl_pos < lbl2.lbl_pos then (lid1, lbl1, p1) :: lub_rec rem1 l2
        else if lbl2.lbl_pos < lbl1.lbl_pos then
          (lid2, lbl2, p2) :: lub_rec l1 rem2
        else (lid1, lbl1, lub p1 p2) :: lub_rec rem1 rem2
  in
  lub_rec l1 l2

and lubs ps qs =
  match (ps, qs) with p :: ps, q :: qs -> lub p q :: lubs ps qs | _, _ -> []

(******************************)
(* Exported variant closing   *)
(******************************)

(* Apply pressure to variants *)

let pressure_variants tdefs patl =
  let pss = List.map (fun p -> [ p; omega ]) patl in
  ignore (pressure_variants (Some tdefs) pss)

(*****************************)
(* Utilities for diagnostics *)
(*****************************)

(*
  Build up a working pattern matrix by forgetting
  about guarded patterns
*)

let rec initial_matrix = function
  | [] -> []
  | { c_guard = Some _ } :: rem -> initial_matrix rem
  | { c_guard = None; c_lhs = p } :: rem -> [ p ] :: initial_matrix rem

(******************************************)
(* Look for a row that matches some value *)
(******************************************)

(*
  Useful for seeing if the example of
  non-matched value can indeed be matched
  (by a guarded clause)
*)

exception NoGuard

let rec initial_all no_guard = function
  | [] -> if no_guard then raise NoGuard else []
  | { c_lhs = pat; c_guard; _ } :: rem ->
      ([ pat ], pat.pat_loc) :: initial_all (no_guard && c_guard = None) rem

let rec do_filter_var = function
  | (_ :: ps, loc) :: rem -> (ps, loc) :: do_filter_var rem
  | _ -> []

let do_filter_one q pss =
  let rec filter_rec = function
    | ({ pat_desc = Tpat_alias (p, _, _) } :: ps, loc) :: pss ->
        filter_rec ((p :: ps, loc) :: pss)
    | ({ pat_desc = Tpat_or (p1, p2, _) } :: ps, loc) :: pss ->
        filter_rec ((p1 :: ps, loc) :: (p2 :: ps, loc) :: pss)
    | (p :: ps, loc) :: pss ->
        if simple_match q p then
          (simple_match_args q p @ ps, loc) :: filter_rec pss
        else filter_rec pss
    | _ -> []
  in
  filter_rec pss

let rec do_match pss qs =
  match qs with
  | [] -> ( match pss with ([], loc) :: _ -> Some loc | _ -> None)
  | q :: qs -> (
      match q with
      | { pat_desc = Tpat_or (q1, q2, _) } -> (
          match do_match pss (q1 :: qs) with
          | None -> do_match pss (q2 :: qs)
          | r -> r)
      | { pat_desc = Tpat_any } -> do_match (do_filter_var pss) qs
      | _ ->
          let q0 = normalize_pat q in
          do_match (do_filter_one q0 pss) (simple_match_args q0 q @ qs))

let check_partial_all v casel =
  try
    let pss = initial_all true casel in
    do_match pss [ v ]
  with NoGuard -> None

(************************)
(* Exhaustiveness check *)
(************************)

(* conversion from Typedtree.pattern to Parsetree.pattern list *)
module Conv = struct
  open Parsetree

  let mkpat desc = Ast_helper.Pat.mk desc
  let name_counter = ref 0

  let fresh name =
    let current = !name_counter in
    name_counter := !name_counter + 1;
    "#$" ^ name ^ string_of_int current

  let conv typed =
    let constrs = Hashtbl.create 7 in
    let labels = Hashtbl.create 7 in
    let rec loop pat =
      match pat.pat_desc with
      | Tpat_or (pa, pb, _) -> mkpat (Ppat_or (loop pa, loop pb))
      | Tpat_any | Tpat_var _ -> mkpat Ppat_any
      | Tpat_constant c -> mkpat (Ppat_constant (Untypeast.constant c))
      | Tpat_alias (p, _, _) -> loop p
      | Tpat_tuple lst -> mkpat (Ppat_tuple (List.map loop lst))
      | Tpat_construct (cstr_lid, cstr, lst) ->
          let id = fresh cstr.cstr_name in
          let lid = { cstr_lid with txt = Longident.Lident id } in
          Hashtbl.add constrs id cstr;
          let arg =
            match List.map loop lst with
            | [] -> None
            | [ p ] -> Some p
            | lst -> Some (mkpat (Ppat_tuple lst))
          in
          mkpat (Ppat_construct (lid, arg))
      | Tpat_variant (label, p_opt, row_desc) ->
          let arg = Misc.may_map loop p_opt in
          mkpat (Ppat_variant (label, arg))
      | Tpat_record (subpatterns, _closed_flag) ->
          let fields =
            List.map
              (fun (_, lbl, p) ->
                let id = fresh lbl.lbl_name in
                Hashtbl.add labels id lbl;
                (mknoloc (Longident.Lident id), loop p))
              subpatterns
          in
          mkpat (Ppat_record (fields, Open))
      | Tpat_array lst -> mkpat (Ppat_array (List.map loop lst))
      | Tpat_lazy p -> mkpat (Ppat_lazy (loop p))
    in
    let ps = loop typed in
    (ps, constrs, labels)
end

(* Whether the counter-example contains an extension pattern *)
let contains_extension pat =
  let r = ref false in
  let rec loop = function
    | { pat_desc = Tpat_construct (_, { cstr_name = "*extension*" }, _) } ->
        r := true
    | p -> Typedtree.iter_pattern_desc loop p.pat_desc
  in
  loop pat;
  !r

(* Build an untyped or-pattern from its expected type *)
let ppat_of_type env ty =
  match pats_of_type env ty with
  | [ { pat_desc = Tpat_any } ] ->
      (Conv.mkpat Parsetree.Ppat_any, Hashtbl.create 0, Hashtbl.create 0)
  | pats -> Conv.conv (orify_many pats)

let do_check_partial ?pred exhaust loc casel pss =
  match pss with
  | [] ->
      (*
          This can occur
          - For empty matches generated by ocamlp4 (no warning)
          - when all patterns have guards (then, casel <> [])
          (specific warning)
          Then match MUST be considered non-exhaustive,
          otherwise compilation of PM is broken.
          *)
      (match casel with
      | [] -> ()
      | _ -> Location.prerr_warning loc Warnings.All_clauses_guarded);
      Partial
  | ps :: _ -> (
      match exhaust None pss (List.length ps) with
      | Rnone -> Total
      | Rsome [ u ] -> (
          let v =
            match pred with
            | Some pred ->
                if false then Some u
                else
                  let pattern, constrs, labels = Conv.conv u in
                  pred constrs labels pattern
            | None -> Some u
          in
          match v with
          | None -> Total
          | Some v ->
              let errmsg =
                try
                  let buf = Buffer.create 16 in
                  let fmt = formatter_of_buffer buf in
                  top_pretty fmt v;
                  (match check_partial_all v casel with
                  | None -> ()
                  | Some _ ->
                      (* This is 'Some loc', where loc is the location of
                         a possibly matching clause.
                         Forget about loc, because printing two locations
                         is a pain in the top-level *)
                      Buffer.add_string buf
                        "\n(However, some guarded clause may match this value.)");
                  if contains_extension v then
                    Buffer.add_string buf
                      "\n\
                       Matching over values of extensible variant types (the \
                       *extension* above)\n\
                       must include a wild card pattern in order to be \
                       exhaustive.";
                  Buffer.contents buf
                with _ -> ""
              in
              Location.prerr_warning loc (Warnings.Partial_match errmsg);
              Partial)
      | _ -> fatal_error "Parmatch.check_partial")

(*
let do_check_partial_normal loc casel pss =
  do_check_partial exhaust loc casel pss
 *)

let do_check_partial_gadt pred loc casel pss =
  do_check_partial ~pred exhaust_gadt loc casel pss

(*****************)
(* Fragile check *)
(*****************)

(* Collect all data types in a pattern *)

let rec add_path path = function
  | [] -> [ path ]
  | x :: rem as paths ->
      if Path.same path x then paths else x :: add_path path rem

let extendable_path path =
  not
    (Path.same path Predef.path_bool
    || Path.same path Predef.path_list
    || Path.same path Predef.path_unit
    || Path.same path Predef.path_option)

let rec collect_paths_from_pat r p =
  match p.pat_desc with
  | Tpat_construct (_, { cstr_tag = Cstr_constant _ | Cstr_block _ }, ps) ->
      let path = get_type_path p.pat_type p.pat_env in
      List.fold_left collect_paths_from_pat
        (if extendable_path path then add_path path r else r)
        ps
  | Tpat_any | Tpat_var _ | Tpat_constant _ | Tpat_variant (_, None, _) -> r
  | Tpat_tuple ps
  | Tpat_array ps
  | Tpat_construct (_, { cstr_tag = Cstr_extension _ }, ps) ->
      List.fold_left collect_paths_from_pat r ps
  | Tpat_record (lps, _) ->
      List.fold_left (fun r (_, _, p) -> collect_paths_from_pat r p) r lps
  | Tpat_variant (_, Some p, _) | Tpat_alias (p, _, _) ->
      collect_paths_from_pat r p
  | Tpat_or (p1, p2, _) ->
      collect_paths_from_pat (collect_paths_from_pat r p1) p2
  | Tpat_lazy p -> collect_paths_from_pat r p

(*
  Actual fragile check
   1. Collect data types in the patterns of the match.
   2. One exhautivity check per datatype, considering that
      the type is extended.
*)

let do_check_fragile_param exhaust loc casel pss =
  let exts =
    List.fold_left (fun r c -> collect_paths_from_pat r c.c_lhs) [] casel
  in
  match exts with
  | [] -> ()
  | _ -> (
      match pss with
      | [] -> ()
      | ps :: _ ->
          List.iter
            (fun ext ->
              match exhaust (Some ext) pss (List.length ps) with
              | Rnone ->
                  Location.prerr_warning loc
                    (Warnings.Fragile_match (Path.name ext))
              | Rsome _ -> ())
            exts)

(*let do_check_fragile_normal = do_check_fragile_param exhaust*)
let do_check_fragile_gadt = do_check_fragile_param exhaust_gadt

(********************************)
(* Exported unused clause check *)
(********************************)

let check_unused pred tdefs casel =
  if
    Warnings.is_active Warnings.Unused_match
    || List.exists (fun c -> c.c_rhs.exp_desc = Texp_unreachable) casel
  then
    let rec do_rec pref = function
      | [] -> ()
      | { c_lhs = q; c_guard; c_rhs } :: rem ->
          let qs = [ q ] in
          (try
             let pss = get_mins le_pats (List.filter (compats qs) pref) in
             (* First look for redundant or partially redundant patterns *)
             let r = every_satisfiables (make_rows pss) (make_row qs) in
             let refute = c_rhs.exp_desc = Texp_unreachable in
             (* Do not warn for unused [pat -> .] *)
             if r = Unused && refute then ()
             else
               let r =
                 (* Do not refine if there are no other lines *)
                 let skip =
                   r = Unused
                   || ((not refute) && pref = [])
                   || not
                        (refute || Warnings.is_active Warnings.Unreachable_case)
                 in
                 if skip then r
                 else
                   (* Then look for empty patterns *)
                   let sfs = satisfiables pss qs in
                   if sfs = [] then Unused
                   else
                     let sfs =
                       List.map (function [ u ] -> u | _ -> assert false) sfs
                     in
                     let u = orify_many sfs in
                     (*Format.eprintf "%a@." pretty_val u;*)
                     let pattern, constrs, labels = Conv.conv u in
                     let pattern =
                       { pattern with Parsetree.ppat_loc = q.pat_loc }
                     in
                     match pred refute constrs labels pattern with
                     | None when not refute ->
                         Location.prerr_warning q.pat_loc
                           Warnings.Unreachable_case;
                         Used
                     | _ -> r
               in
               match r with
               | Unused ->
                   Location.prerr_warning q.pat_loc Warnings.Unused_match
               | Upartial ps ->
                   List.iter
                     (fun p ->
                       Location.prerr_warning p.pat_loc Warnings.Unused_pat)
                     ps
               | Used -> ()
           with Empty | Not_found | NoGuard -> assert false);

          if c_guard <> None then do_rec pref rem
          else do_rec ([ q ] :: pref) rem
    in

    do_rec [] casel

(*********************************)
(* Exported irrefutability tests *)
(*********************************)

let irrefutable pat = le_pat pat omega

(* An inactive pattern is a pattern whose matching needs only
   trivial computations (tag/equality tests).
   Patterns containing (lazy _) subpatterns are active. *)

let rec inactive pat =
  match pat with
  | Tpat_lazy _ -> false
  | Tpat_any | Tpat_var _ | Tpat_constant _ | Tpat_variant (_, None, _) -> true
  | Tpat_tuple ps | Tpat_construct (_, _, ps) | Tpat_array ps ->
      List.for_all (fun p -> inactive p.pat_desc) ps
  | Tpat_alias (p, _, _) | Tpat_variant (_, Some p, _) -> inactive p.pat_desc
  | Tpat_record (ldps, _) ->
      List.exists (fun (_, _, p) -> inactive p.pat_desc) ldps
  | Tpat_or (p, q, _) -> inactive p.pat_desc && inactive q.pat_desc

(* A `fluid' pattern is both irrefutable and inactive *)

let fluid pat = irrefutable pat && inactive pat.pat_desc

(********************************)
(* Exported exhustiveness check *)
(********************************)

(*
   Fragile check is performed when required and
   on exhaustive matches only.
*)

let check_partial_param do_check_partial do_check_fragile loc casel =
  if Warnings.is_active (Warnings.Partial_match "") then (
    let pss = initial_matrix casel in
    let pss = get_mins le_pats pss in
    let total = do_check_partial loc casel pss in
    if total = Total && Warnings.is_active (Warnings.Fragile_match "") then
      do_check_fragile loc casel pss;
    total)
  else Partial

(*let check_partial =
    check_partial_param
      do_check_partial_normal
      do_check_fragile_normal*)

let check_partial_gadt pred loc casel =
  check_partial_param
    (do_check_partial_gadt pred)
    do_check_fragile_gadt loc casel

(*************************************)
(* Ambiguous variable in or-patterns *)
(*************************************)

(* Specification: ambiguous variables in or-patterns.

   The semantics of or-patterns in OCaml is specified with
   a left-to-right bias: a value [v] matches the pattern [p | q] if it
   matches [p] or [q], but if it matches both, the environment
   captured by the match is the environment captured by [p], never the
   one captured by [q].

   While this property is generally well-understood, one specific case
   where users expect a different semantics is when a pattern is
   followed by a when-guard: [| p when g -> e]. Consider for example:

     | ((Const x, _) | (_, Const x)) when is_neutral x -> branch

   The semantics is clear: match the scrutinee against the pattern, if
   it matches, test the guard, and if the guard passes, take the
   branch.

   However, consider the input [(Const a, Const b)], where [a] fails
   the test [is_neutral f], while [b] passes the test [is_neutral
   b]. With the left-to-right semantics, the clause above is *not*
   taken by its input: matching [(Const a, Const b)] against the
   or-pattern succeeds in the left branch, it returns the environment
   [x -> a], and then the guard [is_neutral a] is tested and fails,
   the branch is not taken. Most users, however, intuitively expect
   that any pair that has one side passing the test will take the
   branch. They assume it is equivalent to the following:

     | (Const x, _) when is_neutral x -> branch
     | (_, Const x) when is_neutral x -> branch

   while it is not.

   The code below is dedicated to finding these confusing cases: the
   cases where a guard uses "ambiguous" variables, that are bound to
   different parts of the scrutinees by different sides of
   a or-pattern. In other words, it finds the cases where the
   specified left-to-right semantics is not equivalent to
   a non-deterministic semantics (any branch can be taken) relatively
   to a specific guard.
*)

module IdSet = Set.Make (Ident)

let pattern_vars p = IdSet.of_list (Typedtree.pat_bound_idents p)

(* Row for ambiguous variable search,
   unseen is the traditional pattern row,
   seen   is a list of position bindings *)

type amb_row = { unseen : pattern list; seen : IdSet.t list }

(* Push binding variables now *)

let rec do_push r p ps seen k =
  match p.pat_desc with
  | Tpat_alias (p, x, _) -> do_push (IdSet.add x r) p ps seen k
  | Tpat_var (x, _) ->
      (omega, { unseen = ps; seen = IdSet.add x r :: seen }) :: k
  | Tpat_or (p1, p2, _) -> do_push r p1 ps seen (do_push r p2 ps seen k)
  | _ -> (p, { unseen = ps; seen = r :: seen }) :: k

let rec push_vars = function
  | [] -> []
  | { unseen = [] } :: _ -> assert false
  | { unseen = p :: ps; seen } :: rem ->
      do_push IdSet.empty p ps seen (push_vars rem)

let collect_stable = function
  | [] -> assert false
  | { seen = xss; _ } :: rem ->
      let rec c_rec xss = function
        | [] -> xss
        | { seen = yss; _ } :: rem ->
            let xss = List.map2 IdSet.inter xss yss in
            c_rec xss rem
      in
      let inters = c_rec xss rem in
      List.fold_left IdSet.union IdSet.empty inters

(*********************************************)
(* Filtering utilities for our specific rows *)
(*********************************************)

(* Take a pattern matrix as a list (rows) of lists (columns) of patterns
     | p1, p2, .., pn
     | q1, q2, .., qn
     | r1, r2, .., rn
     | ...

   We split this matrix into a list of sub-matrices, one for each head
   constructor appearing in the leftmost column. For each row whose
   left column starts with a head constructor, remove this head
   column, prepend one column for each argument of the constructor,
   and add the resulting row in the sub-matrix corresponding to this
   head constructor.

   Rows whose left column is omega (the Any pattern _) may match any
   head constructor, so they are added to all groups.

   The list of sub-matrices is represented as a list of pair
     (head constructor, submatrix)
*)

let filter_all =
  (* the head constructor (as a pattern with omega arguments) of
     a pattern *)
  let discr_head pat =
    match pat.pat_desc with
    | Tpat_record (lbls, closed) ->
        (* a partial record pattern { f1 = p1; f2 = p2; _ }
           needs to be expanded, otherwise matching against this head
           would drop the pattern arguments for non-mentioned fields *)
        let lbls = all_record_args lbls in
        normalize_pat { pat with pat_desc = Tpat_record (lbls, closed) }
    | _ -> normalize_pat pat
  in

  (* insert a row of head [p] and rest [r] into the right group *)
  let rec insert p r env =
    match env with
    | [] ->
        (* if no group matched this row, it has a head constructor that
           was never seen before; add a new sub-matrix for this head *)
        let p0 = discr_head p in
        [ (p0, [ { r with unseen = simple_match_args p0 p @ r.unseen } ]) ]
    | ((q0, rs) as bd) :: env ->
        if simple_match q0 p then
          let r = { r with unseen = simple_match_args q0 p @ r.unseen } in
          (q0, r :: rs) :: env
        else bd :: insert p r env
  in

  (* insert a row of head omega into all groups *)
  let insert_omega r env =
    List.map
      (fun (q0, rs) ->
        let r = { r with unseen = simple_match_args q0 omega @ r.unseen } in
        (q0, r :: rs))
      env
  in

  let rec filter_rec env = function
    | [] -> env
    | ({ pat_desc = Tpat_var _ | Tpat_alias _ | Tpat_or _ }, _) :: _ ->
        assert false
    | ({ pat_desc = Tpat_any }, _) :: rs -> filter_rec env rs
    | (p, r) :: rs -> filter_rec (insert p r env) rs
  in

  let rec filter_omega env = function
    | [] -> env
    | ({ pat_desc = Tpat_var _ | Tpat_alias _ | Tpat_or _ }, _) :: _ ->
        assert false
    | ({ pat_desc = Tpat_any }, r) :: rs -> filter_omega (insert_omega r env) rs
    | _ :: rs -> filter_omega env rs
  in

  fun rs ->
    (* first insert the rows with head constructors,
       to get the definitive list of groups *)
    let env = filter_rec [] rs in
    (* then add the omega rows to all groups *)
    filter_omega env rs

(* Compute stable bindings *)

let rec do_stable rs =
  match rs with
  | [] -> assert false (* No empty matrix *)
  | { unseen = []; _ } :: _ -> collect_stable rs
  | _ -> (
      let rs = push_vars rs in
      match filter_all rs with
      | [] -> do_stable (List.map snd rs)
      | (_, rs) :: env ->
          List.fold_left
            (fun xs (_, rs) -> IdSet.inter xs (do_stable rs))
            (do_stable rs) env)

let stable p = do_stable [ { unseen = [ p ]; seen = [] } ]

(* All identifier paths that appear in an expression that occurs
    as a clause right hand side or guard.

   The function is rather complex due to the compilation of
   unpack patterns by introducing code in rhs expressions
   and **guards**.

   For pattern (module M:S)  -> e the code is
   let module M_mod = unpack M .. in e

   Hence M is "free" in e iff M_mod is free in e.

   Not doing so will yield excessive  warning in
   (module (M:S) } ...) when true -> ....
   as M is always present in
   let module M_mod = unpack M .. in true
*)

let all_rhs_idents exp =
  let ids = ref IdSet.empty in
  let module Iterator = TypedtreeIter.MakeIterator (struct
    include TypedtreeIter.DefaultIteratorArgument

    let enter_expression exp =
      match exp.exp_desc with
      | Texp_ident (path, _lid, _descr) ->
          List.iter (fun id -> ids := IdSet.add id !ids) (Path.heads path)
      | _ -> ()

    (* Very hackish, detect unpack pattern  compilation
       and perfom "indirect check for them" *)
    let is_unpack exp =
      List.exists (fun (attr, _) -> attr.txt = "#modulepat") exp.exp_attributes

    let leave_expression exp =
      if is_unpack exp then
        match exp.exp_desc with
        | Texp_letmodule
            ( id_mod,
              _,
              {
                mod_desc =
                  Tmod_unpack
                    ({ exp_desc = Texp_ident (Path.Pident id_exp, _, _) }, _);
              },
              _ ) ->
            assert (IdSet.mem id_exp !ids);
            if not (IdSet.mem id_mod !ids) then ids := IdSet.remove id_exp !ids
        | _ -> assert false
  end) in
  Iterator.iter_expression exp;
  !ids

let check_ambiguous_bindings =
  let open Warnings in
  let warn0 = Ambiguous_pattern [] in
  fun cases ->
    if is_active warn0 then
      List.iter
        (fun case ->
          match case with
          | { c_guard = None; _ } -> ()
          | { c_lhs = p; c_guard = Some g; _ } ->
              let all = IdSet.inter (pattern_vars p) (all_rhs_idents g) in
              if not (IdSet.is_empty all) then
                let st = stable p in
                let ambiguous = IdSet.diff all st in
                if not (IdSet.is_empty ambiguous) then
                  let pps = IdSet.elements ambiguous |> List.map Ident.name in
                  let warn = Ambiguous_pattern pps in
                  Location.prerr_warning p.pat_loc warn)
        cases

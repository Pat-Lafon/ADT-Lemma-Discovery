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

(* typetexp.ml,v 1.34.4.9 2002/01/07 08:39:16 garrigue Exp *)

(* Typechecking of type expressions for the core language *)

open Asttypes
open Misc
open Parsetree
open Typedtree
open Types
open Ctype

exception Already_bound

type error =
  | Unbound_type_variable of string
  | Unbound_type_constructor of Longident.t
  | Unbound_type_constructor_2 of Path.t
  | Type_arity_mismatch of Longident.t * int * int
  | Bound_type_variable of string
  | Recursive_type
  | Unbound_row_variable of Longident.t
  | Type_mismatch of (type_expr * type_expr) list
  | Alias_type_mismatch of (type_expr * type_expr) list
  | Present_has_conjunction of string
  | Present_has_no_type of string
  | Constructor_mismatch of type_expr * type_expr
  | Not_a_variant of type_expr
  | Variant_tags of string * string
  | Invalid_variable_name of string
  | Cannot_quantify of string * type_expr
  | Multiple_constraints_on_type of Longident.t
  | Repeated_method_label of string
  | Unbound_value of Longident.t
  | Unbound_constructor of Longident.t
  | Unbound_label of Longident.t
  | Unbound_module of Longident.t
  | Unbound_class of Longident.t
  | Unbound_modtype of Longident.t
  | Unbound_cltype of Longident.t
  | Ill_typed_functor_application of Longident.t
  | Illegal_reference_to_recursive_module
  | Access_functor_as_structure of Longident.t
  | Apply_structure_as_functor of Longident.t
  | Cannot_scrape_alias of Longident.t * Path.t

exception Error of Location.t * Env.t * error
exception Error_forward of Location.error

type variable_context = int * (string, type_expr) Tbl.t

(* Local definitions *)

let instance_list = Ctype.instance_list Env.empty

(* Narrowing unbound identifier errors. *)

let rec narrow_unbound_lid_error : 'a. _ -> _ -> _ -> _ -> 'a =
 fun env loc lid make_error ->
  let check_module mlid =
    try ignore (Env.lookup_module true mlid env) with
    | Not_found ->
        narrow_unbound_lid_error env loc mlid (fun lid -> Unbound_module lid)
    | Env.Recmodule ->
        raise (Error (loc, env, Illegal_reference_to_recursive_module))
  in
  (match lid with
  | Longident.Lident _ -> ()
  | Longident.Ldot (mlid, _) -> (
      check_module mlid;
      let md = Env.find_module (Env.lookup_module true mlid env) env in
      match Env.scrape_alias env md.md_type with
      | Mty_functor _ ->
          raise (Error (loc, env, Access_functor_as_structure mlid))
      | Mty_alias p -> raise (Error (loc, env, Cannot_scrape_alias (mlid, p)))
      | _ -> ())
  | Longident.Lapply (flid, mlid) -> (
      check_module flid;
      let fmd = Env.find_module (Env.lookup_module true flid env) env in
      (match Env.scrape_alias env fmd.md_type with
      | Mty_signature _ ->
          raise (Error (loc, env, Apply_structure_as_functor flid))
      | Mty_alias p -> raise (Error (loc, env, Cannot_scrape_alias (flid, p)))
      | _ -> ());
      check_module mlid;
      let mmd = Env.find_module (Env.lookup_module true mlid env) env in
      match Env.scrape_alias env mmd.md_type with
      | Mty_alias p -> raise (Error (loc, env, Cannot_scrape_alias (mlid, p)))
      | _ -> raise (Error (loc, env, Ill_typed_functor_application lid))));
  raise (Error (loc, env, make_error lid))

let find_component lookup make_error env loc lid =
  try
    match lid with
    | Longident.Ldot (Longident.Lident "*predef*", s) ->
        lookup ?loc:(Some loc) (Longident.Lident s) Env.initial_safe_string
    | _ -> lookup ?loc:(Some loc) lid env
  with
  | Not_found -> narrow_unbound_lid_error env loc lid make_error
  | Env.Recmodule ->
      raise (Error (loc, env, Illegal_reference_to_recursive_module))

let find_type env loc lid =
  let ((path, decl) as r) =
    find_component Env.lookup_type
      (fun lid -> Unbound_type_constructor lid)
      env loc lid
  in
  Builtin_attributes.check_deprecated loc decl.type_attributes (Path.name path);
  r

let find_constructor =
  find_component Env.lookup_constructor (fun lid -> Unbound_constructor lid)

let find_all_constructors =
  find_component Env.lookup_all_constructors (fun lid ->
      Unbound_constructor lid)

let find_label = find_component Env.lookup_label (fun lid -> Unbound_label lid)

let find_all_labels =
  find_component Env.lookup_all_labels (fun lid -> Unbound_label lid)

let find_class env loc lid =
  let ((path, decl) as r) =
    find_component Env.lookup_class (fun lid -> Unbound_class lid) env loc lid
  in
  Builtin_attributes.check_deprecated loc decl.cty_attributes (Path.name path);
  r

let find_value env loc lid =
  Env.check_value_name (Longident.last lid) loc;
  let ((path, decl) as r) =
    find_component Env.lookup_value (fun lid -> Unbound_value lid) env loc lid
  in
  Builtin_attributes.check_deprecated loc decl.val_attributes (Path.name path);
  r

let lookup_module ?(load = false) env loc lid =
  find_component
    (fun ?loc lid env -> Env.lookup_module ~load ?loc lid env)
    (fun lid -> Unbound_module lid)
    env loc lid

let find_module env loc lid =
  let path = lookup_module ~load:true env loc lid in
  let decl = Env.find_module path env in
  (* No need to check for deprecated here, this is done in Env. *)
  (path, decl)

let find_modtype env loc lid =
  let ((path, decl) as r) =
    find_component Env.lookup_modtype
      (fun lid -> Unbound_modtype lid)
      env loc lid
  in
  Builtin_attributes.check_deprecated loc decl.mtd_attributes (Path.name path);
  r

let find_class_type env loc lid =
  let ((path, decl) as r) =
    find_component Env.lookup_cltype (fun lid -> Unbound_cltype lid) env loc lid
  in
  Builtin_attributes.check_deprecated loc decl.clty_attributes (Path.name path);
  r

let unbound_constructor_error env lid =
  narrow_unbound_lid_error env lid.loc lid.txt (fun lid ->
      Unbound_constructor lid)

let unbound_label_error env lid =
  narrow_unbound_lid_error env lid.loc lid.txt (fun lid -> Unbound_label lid)

(* Support for first-class modules. *)

let transl_modtype_longident = ref (fun _ -> assert false)
let transl_modtype = ref (fun _ -> assert false)

let create_package_mty fake loc env (p, l) =
  let l =
    List.sort
      (fun (s1, t1) (s2, t2) ->
        if s1.txt = s2.txt then
          raise (Error (loc, env, Multiple_constraints_on_type s1.txt));
        compare s1.txt s2.txt)
      l
  in
  ( l,
    List.fold_left
      (fun mty (s, t) ->
        let d =
          {
            ptype_name = mkloc (Longident.last s.txt) s.loc;
            ptype_params = [];
            ptype_cstrs = [];
            ptype_kind = Ptype_abstract;
            ptype_private = Asttypes.Public;
            ptype_manifest = (if fake then None else Some t);
            ptype_attributes = [];
            ptype_loc = loc;
          }
        in
        Ast_helper.Mty.mk ~loc
          (Pmty_with (mty, [ Pwith_type ({ txt = s.txt; loc }, d) ])))
      (Ast_helper.Mty.mk ~loc (Pmty_ident p))
      l )

(* Translation of type expressions *)

let type_variables = ref (Tbl.empty : (string, type_expr) Tbl.t)
let univars = ref ([] : (string * type_expr) list)
let pre_univars = ref ([] : type_expr list)
let used_variables = ref (Tbl.empty : (string, type_expr * Location.t) Tbl.t)

let reset_type_variables () =
  reset_global_level ();
  Ctype.reset_reified_var_counter ();
  type_variables := Tbl.empty

let narrow () = (increase_global_level (), !type_variables)

let widen (gl, tv) =
  restore_global_level gl;
  type_variables := tv

let strict_ident c = c = '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

let validate_name = function
  | None -> None
  | Some name as s -> if name <> "" && strict_ident name.[0] then s else None

let new_global_var ?name () = new_global_var ?name:(validate_name name) ()
let newvar ?name () = newvar ?name:(validate_name name) ()

let type_variable loc name =
  try Tbl.find name !type_variables
  with Not_found ->
    raise (Error (loc, Env.empty, Unbound_type_variable ("'" ^ name)))

let transl_type_param env styp =
  let loc = styp.ptyp_loc in
  match styp.ptyp_desc with
  | Ptyp_any ->
      let ty = new_global_var ~name:"_" () in
      {
        ctyp_desc = Ttyp_any;
        ctyp_type = ty;
        ctyp_env = env;
        ctyp_loc = loc;
        ctyp_attributes = styp.ptyp_attributes;
      }
  | Ptyp_var name ->
      let ty =
        try
          if name <> "" && name.[0] = '_' then
            raise (Error (loc, Env.empty, Invalid_variable_name ("'" ^ name)));
          ignore (Tbl.find name !type_variables);
          raise Already_bound
        with Not_found ->
          let v = new_global_var ~name () in
          type_variables := Tbl.add name v !type_variables;
          v
      in
      {
        ctyp_desc = Ttyp_var name;
        ctyp_type = ty;
        ctyp_env = env;
        ctyp_loc = loc;
        ctyp_attributes = styp.ptyp_attributes;
      }
  | _ -> assert false

let new_pre_univar ?name () =
  let v = newvar ?name () in
  pre_univars := v :: !pre_univars;
  v

let rec swap_list = function x :: y :: l -> y :: x :: swap_list l | l -> l

type policy = Fixed | Extensible | Univars

let rec transl_type env policy styp =
  let loc = styp.ptyp_loc in
  let ctyp ctyp_desc ctyp_type =
    {
      ctyp_desc;
      ctyp_type;
      ctyp_env = env;
      ctyp_loc = loc;
      ctyp_attributes = styp.ptyp_attributes;
    }
  in
  match styp.ptyp_desc with
  | Ptyp_any ->
      let ty =
        if policy = Univars then new_pre_univar ()
        else if policy = Fixed then
          raise (Error (styp.ptyp_loc, env, Unbound_type_variable "_"))
        else newvar ()
      in
      ctyp Ttyp_any ty
  | Ptyp_var name ->
      let ty =
        if name <> "" && name.[0] = '_' then
          raise (Error (styp.ptyp_loc, env, Invalid_variable_name ("'" ^ name)));
        try instance env (List.assoc name !univars)
        with Not_found -> (
          try instance env (fst (Tbl.find name !used_variables))
          with Not_found ->
            let v =
              if policy = Univars then new_pre_univar ~name ()
              else newvar ~name ()
            in
            used_variables := Tbl.add name (v, styp.ptyp_loc) !used_variables;
            v)
      in
      ctyp (Ttyp_var name) ty
  | Ptyp_arrow (l, st1, st2) ->
      let cty1 = transl_type env policy st1 in
      let cty2 = transl_type env policy st2 in
      let ty1 = cty1.ctyp_type in
      let ty1 =
        if Btype.is_optional l then
          newty (Tconstr (Predef.path_option, [ ty1 ], ref Mnil))
        else ty1
      in
      let ty = newty (Tarrow (l, ty1, cty2.ctyp_type, Cok)) in
      ctyp (Ttyp_arrow (l, cty1, cty2)) ty
  | Ptyp_tuple stl ->
      assert (List.length stl >= 2);
      let ctys = List.map (transl_type env policy) stl in
      let ty = newty (Ttuple (List.map (fun ctyp -> ctyp.ctyp_type) ctys)) in
      ctyp (Ttyp_tuple ctys) ty
  | Ptyp_constr (lid, stl) ->
      let path, decl = find_type env styp.ptyp_loc lid.txt in
      let stl =
        match stl with
        | [ ({ ptyp_desc = Ptyp_any } as t) ] when decl.type_arity > 1 ->
            List.map (fun _ -> t) decl.type_params
        | _ -> stl
      in
      if List.length stl <> decl.type_arity then
        raise
          (Error
             ( styp.ptyp_loc,
               env,
               Type_arity_mismatch (lid.txt, decl.type_arity, List.length stl)
             ));
      let args = List.map (transl_type env policy) stl in
      let params = instance_list decl.type_params in
      let unify_param =
        match decl.type_manifest with
        | None -> unify_var
        | Some ty ->
            if (repr ty).level = Btype.generic_level then unify_var else unify
      in
      List.iter2
        (fun (sty, cty) ty' ->
          try unify_param env ty' cty.ctyp_type
          with Unify trace ->
            raise (Error (sty.ptyp_loc, env, Type_mismatch (swap_list trace))))
        (List.combine stl args) params;
      let constr =
        newconstr path (List.map (fun ctyp -> ctyp.ctyp_type) args)
      in
      (try Ctype.enforce_constraints env constr
       with Unify trace ->
         raise (Error (styp.ptyp_loc, env, Type_mismatch trace)));
      ctyp (Ttyp_constr (path, lid, args)) constr
  | Ptyp_object (fields, o) ->
      let fields =
        List.map (fun (s, a, t) -> (s, a, transl_poly_type env policy t)) fields
      in
      let ty = newobj (transl_fields loc env policy [] o fields) in
      ctyp (Ttyp_object (fields, o)) ty
  | Ptyp_class (lid, stl) ->
      let path, decl, is_variant =
        try
          let path, decl = Env.lookup_type lid.txt env in
          let rec check decl =
            match decl.type_manifest with
            | None -> raise Not_found
            | Some ty -> (
                match (repr ty).desc with
                | Tvariant row when Btype.static_row row -> ()
                | Tconstr (path, _, _) -> check (Env.find_type path env)
                | _ -> raise Not_found)
          in
          check decl;
          Location.prerr_warning styp.ptyp_loc
            (Warnings.Deprecated "old syntax for polymorphic variant type");
          (path, decl, true)
        with Not_found -> (
          try
            let lid2 =
              match lid.txt with
              | Longident.Lident s -> Longident.Lident ("#" ^ s)
              | Longident.Ldot (r, s) -> Longident.Ldot (r, "#" ^ s)
              | Longident.Lapply (_, _) -> fatal_error "Typetexp.transl_type"
            in
            let path, decl = Env.lookup_type lid2 env in
            (path, decl, false)
          with Not_found ->
            ignore (find_class env styp.ptyp_loc lid.txt);
            assert false)
      in
      if List.length stl <> decl.type_arity then
        raise
          (Error
             ( styp.ptyp_loc,
               env,
               Type_arity_mismatch (lid.txt, decl.type_arity, List.length stl)
             ));
      let args = List.map (transl_type env policy) stl in
      let params = instance_list decl.type_params in
      List.iter2
        (fun (sty, cty) ty' ->
          try unify_var env ty' cty.ctyp_type
          with Unify trace ->
            raise (Error (sty.ptyp_loc, env, Type_mismatch (swap_list trace))))
        (List.combine stl args) params;
      let ty_args = List.map (fun ctyp -> ctyp.ctyp_type) args in
      let ty =
        try Ctype.expand_head env (newconstr path ty_args)
        with Unify trace ->
          raise (Error (styp.ptyp_loc, env, Type_mismatch trace))
      in
      let ty =
        match ty.desc with
        | Tvariant row ->
            let row = Btype.row_repr row in
            let fields =
              List.map
                (fun (l, f) ->
                  ( l,
                    match Btype.row_field_repr f with
                    | Rpresent (Some ty) ->
                        Reither (false, [ ty ], false, ref None)
                    | Rpresent None -> Reither (true, [], false, ref None)
                    | _ -> f ))
                row.row_fields
            in
            let row =
              {
                row_closed = true;
                row_fields = fields;
                row_bound = ();
                row_name = Some (path, ty_args);
                row_fixed = false;
                row_more = newvar ();
              }
            in
            let static = Btype.static_row row in
            let row =
              if static then { row with row_more = newty Tnil }
              else if policy <> Univars then row
              else { row with row_more = new_pre_univar () }
            in
            newty (Tvariant row)
        | Tobject (fi, _) ->
            let _, tv = flatten_fields fi in
            if policy = Univars then pre_univars := tv :: !pre_univars;
            ty
        | _ -> assert false
      in
      ctyp (Ttyp_class (path, lid, args)) ty
  | Ptyp_alias (st, alias) ->
      let cty =
        try
          let t =
            try List.assoc alias !univars
            with Not_found ->
              instance env (fst (Tbl.find alias !used_variables))
          in
          let ty = transl_type env policy st in
          (try unify_var env t ty.ctyp_type
           with Unify trace ->
             let trace = swap_list trace in
             raise (Error (styp.ptyp_loc, env, Alias_type_mismatch trace)));
          ty
        with Not_found ->
          if !Clflags.principal then begin_def ();
          let t = newvar () in
          used_variables := Tbl.add alias (t, styp.ptyp_loc) !used_variables;
          let ty = transl_type env policy st in
          (try unify_var env t ty.ctyp_type
           with Unify trace ->
             let trace = swap_list trace in
             raise (Error (styp.ptyp_loc, env, Alias_type_mismatch trace)));
          if !Clflags.principal then (
            end_def ();
            generalize_structure t);
          let t = instance env t in
          let px = Btype.proxy t in
          (match px.desc with
          | Tvar None ->
              Btype.log_type px;
              px.desc <- Tvar (Some alias)
          | Tunivar None ->
              Btype.log_type px;
              px.desc <- Tunivar (Some alias)
          | _ -> ());
          { ty with ctyp_type = t }
      in
      ctyp (Ttyp_alias (cty, alias)) cty.ctyp_type
  | Ptyp_variant (fields, closed, present) ->
      let name = ref None in
      let mkfield l f =
        newty
          (Tvariant
             {
               row_fields = [ (l, f) ];
               row_more = newvar ();
               row_bound = ();
               row_closed = true;
               row_fixed = false;
               row_name = None;
             })
      in
      let hfields = Hashtbl.create 17 in
      let add_typed_field loc l f =
        let h = Btype.hash_variant l in
        try
          let l', f' = Hashtbl.find hfields h in
          (* Check for tag conflicts *)
          if l <> l' then
            raise (Error (styp.ptyp_loc, env, Variant_tags (l, l')));
          let ty = mkfield l f and ty' = mkfield l f' in
          if equal env false [ ty ] [ ty' ] then ()
          else
            try unify env ty ty'
            with Unify trace ->
              raise (Error (loc, env, Constructor_mismatch (ty, ty')))
        with Not_found -> Hashtbl.add hfields h (l, f)
      in
      let add_field = function
        | Rtag (l, attrs, c, stl) ->
            name := None;
            let tl = List.map (transl_type env policy) stl in
            let f =
              match present with
              | Some present when not (List.mem l present) ->
                  let ty_tl = List.map (fun cty -> cty.ctyp_type) tl in
                  Reither (c, ty_tl, false, ref None)
              | _ -> (
                  if List.length stl > 1 || (c && stl <> []) then
                    raise
                      (Error (styp.ptyp_loc, env, Present_has_conjunction l));
                  match tl with
                  | [] -> Rpresent None
                  | st :: _ -> Rpresent (Some st.ctyp_type))
            in
            add_typed_field styp.ptyp_loc l f;
            Ttag (l, attrs, c, tl)
        | Rinherit sty ->
            let cty = transl_type env policy sty in
            let ty = cty.ctyp_type in
            let nm =
              match repr cty.ctyp_type with
              | { desc = Tconstr (p, tl, _) } -> Some (p, tl)
              | _ -> None
            in
            (try
               (* Set name if there are no fields yet *)
               Hashtbl.iter (fun _ _ -> raise Exit) hfields;
               name := nm
             with Exit -> (* Unset it otherwise *)
                          name := None);
            let fl =
              match (expand_head env cty.ctyp_type, nm) with
              | { desc = Tvariant row }, _ when Btype.static_row row ->
                  let row = Btype.row_repr row in
                  row.row_fields
              | { desc = Tvar _ }, Some (p, _) ->
                  raise
                    (Error (sty.ptyp_loc, env, Unbound_type_constructor_2 p))
              | _ -> raise (Error (sty.ptyp_loc, env, Not_a_variant ty))
            in
            List.iter
              (fun (l, f) ->
                let f =
                  match present with
                  | Some present when not (List.mem l present) -> (
                      match f with
                      | Rpresent (Some ty) ->
                          Reither (false, [ ty ], false, ref None)
                      | Rpresent None -> Reither (true, [], false, ref None)
                      | _ -> assert false)
                  | _ -> f
                in
                add_typed_field sty.ptyp_loc l f)
              fl;
            Tinherit cty
      in
      let tfields = List.map add_field fields in
      let fields = Hashtbl.fold (fun _ p l -> p :: l) hfields [] in
      (match present with
      | None -> ()
      | Some present ->
          List.iter
            (fun l ->
              if not (List.mem_assoc l fields) then
                raise (Error (styp.ptyp_loc, env, Present_has_no_type l)))
            present);
      let row =
        {
          row_fields = List.rev fields;
          row_more = newvar ();
          row_bound = ();
          row_closed = closed = Closed;
          row_fixed = false;
          row_name = !name;
        }
      in
      let static = Btype.static_row row in
      let row =
        if static then { row with row_more = newty Tnil }
        else if policy <> Univars then row
        else { row with row_more = new_pre_univar () }
      in
      let ty = newty (Tvariant row) in
      ctyp (Ttyp_variant (tfields, closed, present)) ty
  | Ptyp_poly (vars, st) ->
      begin_def ();
      let new_univars = List.map (fun name -> (name, newvar ~name ())) vars in
      let old_univars = !univars in
      univars := new_univars @ !univars;
      let cty = transl_type env policy st in
      let ty = cty.ctyp_type in
      univars := old_univars;
      end_def ();
      generalize ty;
      let ty_list =
        List.fold_left
          (fun tyl (name, ty1) ->
            let v = Btype.proxy ty1 in
            if deep_occur v ty then
              match v.desc with
              | Tvar name when v.level = Btype.generic_level ->
                  v.desc <- Tunivar name;
                  v :: tyl
              | _ ->
                  raise (Error (styp.ptyp_loc, env, Cannot_quantify (name, v)))
            else tyl)
          [] new_univars
      in
      let ty' = Btype.newgenty (Tpoly (ty, List.rev ty_list)) in
      unify_var env (newvar ()) ty';
      ctyp (Ttyp_poly (vars, cty)) ty'
  | Ptyp_package (p, l) ->
      let l, mty = create_package_mty true styp.ptyp_loc env (p, l) in
      let z = narrow () in
      let mty = !transl_modtype env mty in
      widen z;
      let ptys = List.map (fun (s, pty) -> (s, transl_type env policy pty)) l in
      let path = !transl_modtype_longident styp.ptyp_loc env p.txt in
      let ty =
        newty
          (Tpackage
             ( path,
               List.map (fun (s, pty) -> s.txt) l,
               List.map (fun (_, cty) -> cty.ctyp_type) ptys ))
      in
      ctyp
        (Ttyp_package
           {
             pack_path = path;
             pack_type = mty.mty_type;
             pack_fields = ptys;
             pack_txt = p;
           })
        ty
  | Ptyp_extension ext ->
      raise (Error_forward (Builtin_attributes.error_of_extension ext))

and transl_poly_type env policy t =
  transl_type env policy (Ast_helper.Typ.force_poly t)

and transl_fields loc env policy seen o = function
  | [] -> (
      match (o, policy) with
      | Closed, _ -> newty Tnil
      | Open, Univars -> new_pre_univar ()
      | Open, _ -> newvar ())
  | (s, _attrs, ty1) :: l ->
      if List.mem s seen then raise (Error (loc, env, Repeated_method_label s));
      let ty2 = transl_fields loc env policy (s :: seen) o l in
      newty (Tfield (s, Fpresent, ty1.ctyp_type, ty2))

(* Make the rows "fixed" in this type, to make universal check easier *)
let rec make_fixed_univars ty =
  let ty = repr ty in
  if ty.level >= Btype.lowest_level then (
    Btype.mark_type_node ty;
    match ty.desc with
    | Tvariant row ->
        let row = Btype.row_repr row in
        if Btype.is_Tunivar (Btype.row_more row) then
          ty.desc <-
            Tvariant
              {
                row with
                row_fixed = true;
                row_fields =
                  List.map
                    (fun ((s, f) as p) ->
                      match Btype.row_field_repr f with
                      | Reither (c, tl, m, r) -> (s, Reither (c, tl, true, r))
                      | _ -> p)
                    row.row_fields;
              };
        Btype.iter_row make_fixed_univars row
    | _ -> Btype.iter_type_expr make_fixed_univars ty)

let make_fixed_univars ty =
  make_fixed_univars ty;
  Btype.unmark_type ty

let create_package_mty = create_package_mty false

let globalize_used_variables env fixed =
  let r = ref [] in
  Tbl.iter
    (fun name (ty, loc) ->
      let v = new_global_var () in
      let snap = Btype.snapshot () in
      if
        try
          unify env v ty;
          true
        with _ ->
          Btype.backtrack snap;
          false
      then (
        try r := (loc, v, Tbl.find name !type_variables) :: !r
        with Not_found ->
          if fixed && Btype.is_Tvar (repr ty) then
            raise (Error (loc, env, Unbound_type_variable ("'" ^ name)));
          let v2 = new_global_var () in
          r := (loc, v, v2) :: !r;
          type_variables := Tbl.add name v2 !type_variables))
    !used_variables;
  used_variables := Tbl.empty;
  fun () ->
    List.iter
      (function
        | loc, t1, t2 -> (
            try unify env t1 t2
            with Unify trace -> raise (Error (loc, env, Type_mismatch trace))))
      !r

let transl_simple_type env fixed styp =
  univars := [];
  used_variables := Tbl.empty;
  let typ = transl_type env (if fixed then Fixed else Extensible) styp in
  globalize_used_variables env fixed ();
  make_fixed_univars typ.ctyp_type;
  typ

let transl_simple_type_univars env styp =
  univars := [];
  used_variables := Tbl.empty;
  pre_univars := [];
  begin_def ();
  let typ = transl_type env Univars styp in
  (* Only keep already global variables in used_variables *)
  let new_variables = !used_variables in
  used_variables := Tbl.empty;
  Tbl.iter
    (fun name p ->
      if Tbl.mem name !type_variables then
        used_variables := Tbl.add name p !used_variables)
    new_variables;
  globalize_used_variables env false ();
  end_def ();
  generalize typ.ctyp_type;
  let univs =
    List.fold_left
      (fun acc v ->
        let v = repr v in
        match v.desc with
        | Tvar name when v.level = Btype.generic_level ->
            v.desc <- Tunivar name;
            v :: acc
        | _ -> acc)
      [] !pre_univars
  in
  make_fixed_univars typ.ctyp_type;
  {
    typ with
    ctyp_type = instance env (Btype.newgenty (Tpoly (typ.ctyp_type, univs)));
  }

let transl_simple_type_delayed env styp =
  univars := [];
  used_variables := Tbl.empty;
  let typ = transl_type env Extensible styp in
  make_fixed_univars typ.ctyp_type;
  (typ, globalize_used_variables env false)

let transl_type_scheme env styp =
  reset_type_variables ();
  begin_def ();
  let typ = transl_simple_type env false styp in
  end_def ();
  generalize typ.ctyp_type;
  typ

(* Error report *)

open Format
open Printtyp

let spellcheck ppf fold env lid =
  let choices ~path name =
    let env = fold (fun x xs -> x :: xs) path env [] in
    Misc.spellcheck env name
  in
  match lid with
  | Longident.Lapply _ -> ()
  | Longident.Lident s -> Misc.did_you_mean ppf (fun () -> choices ~path:None s)
  | Longident.Ldot (r, s) ->
      Misc.did_you_mean ppf (fun () -> choices ~path:(Some r) s)

let fold_descr fold get_name f = fold (fun descr acc -> f (get_name descr) acc)
let fold_simple fold4 f = fold4 (fun name _path _descr acc -> f name acc)
let fold_values = fold_simple Env.fold_values
let fold_types = fold_simple Env.fold_types
let fold_modules = fold_simple Env.fold_modules
let fold_constructors = fold_descr Env.fold_constructors (fun d -> d.cstr_name)
let fold_labels = fold_descr Env.fold_labels (fun d -> d.lbl_name)
let fold_classs = fold_simple Env.fold_classs
let fold_modtypes = fold_simple Env.fold_modtypes
let fold_cltypes = fold_simple Env.fold_cltypes

let report_error env ppf = function
  | Unbound_type_variable name ->
      (* we don't use "spellcheck" here: the function that raises this
         error seems not to be called anywhere, so it's unclear how it
         should be handled *)
      fprintf ppf "Unbound type parameter %s@." name
  | Unbound_type_constructor lid ->
      fprintf ppf "Unbound type constructor %a" longident lid;
      spellcheck ppf fold_types env lid
  | Unbound_type_constructor_2 p ->
      fprintf ppf "The type constructor@ %a@ is not yet completely defined" path
        p
  | Type_arity_mismatch (lid, expected, provided) ->
      fprintf ppf
        "@[The type constructor %a@ expects %i argument(s),@ but is here \
         applied to %i argument(s)@]"
        longident lid expected provided
  | Bound_type_variable name ->
      fprintf ppf "Already bound type parameter '%s" name
  | Recursive_type -> fprintf ppf "This type is recursive"
  | Unbound_row_variable lid ->
      (* we don't use "spellcheck" here: this error is not raised
         anywhere so it's unclear how it should be handled *)
      fprintf ppf "Unbound row variable in #%a" longident lid
  | Type_mismatch trace ->
      Printtyp.report_unification_error ppf Env.empty trace
        (function ppf -> fprintf ppf "This type")
        (function ppf -> fprintf ppf "should be an instance of type")
  | Alias_type_mismatch trace ->
      Printtyp.report_unification_error ppf Env.empty trace
        (function ppf -> fprintf ppf "This alias is bound to type")
        (function ppf -> fprintf ppf "but is used as an instance of type")
  | Present_has_conjunction l ->
      fprintf ppf "The present constructor %s has a conjunctive type" l
  | Present_has_no_type l ->
      fprintf ppf "The present constructor %s has no type" l
  | Constructor_mismatch (ty, ty') ->
      wrap_printing_env env (fun () ->
          Printtyp.reset_and_mark_loops_list [ ty; ty' ];
          fprintf ppf "@[<hov>%s %a@ %s@ %a@]"
            "This variant type contains a constructor" Printtyp.type_expr ty
            "which should be" Printtyp.type_expr ty')
  | Not_a_variant ty -> (
      Printtyp.reset_and_mark_loops ty;
      fprintf ppf "@[The type %a@ is not a polymorphic variant type@]"
        Printtyp.type_expr ty;
      match ty.desc with
      | Tvar (Some s) ->
          (* PR#7012: help the user that wrote 'Foo instead of `Foo *)
          Misc.did_you_mean ppf (fun () -> [ "`" ^ s ])
      | _ -> ())
  | Variant_tags (lab1, lab2) ->
      fprintf ppf "@[Variant tags `%s@ and `%s have the same hash value.@ %s@]"
        lab1 lab2 "Change one of them."
  | Invalid_variable_name name ->
      fprintf ppf "The type variable name %s is not allowed in programs" name
  | Cannot_quantify (name, v) ->
      fprintf ppf
        "@[<hov>The universal type variable '%s cannot be generalized:@ %s.@]"
        name
        (if Btype.is_Tvar v then "it escapes its scope"
         else if Btype.is_Tunivar v then
           "it is already bound to another variable"
         else "it is not a variable")
  | Multiple_constraints_on_type s ->
      fprintf ppf "Multiple constraints for type %a" longident s
  | Repeated_method_label s ->
      fprintf ppf "@[This is the second method `%s' of this object type.@ %s@]"
        s "Multiple occurences are not allowed."
  | Unbound_value lid ->
      fprintf ppf "Unbound value %a" longident lid;
      spellcheck ppf fold_values env lid
  | Unbound_module lid ->
      fprintf ppf "Unbound module %a" longident lid;
      spellcheck ppf fold_modules env lid
  | Unbound_constructor lid ->
      fprintf ppf "Unbound constructor %a" longident lid;
      spellcheck ppf fold_constructors env lid
  | Unbound_label lid ->
      fprintf ppf "Unbound record field %a" longident lid;
      spellcheck ppf fold_labels env lid
  | Unbound_class lid ->
      fprintf ppf "Unbound class %a" longident lid;
      spellcheck ppf fold_classs env lid
  | Unbound_modtype lid ->
      fprintf ppf "Unbound module type %a" longident lid;
      spellcheck ppf fold_modtypes env lid
  | Unbound_cltype lid ->
      fprintf ppf "Unbound class type %a" longident lid;
      spellcheck ppf fold_cltypes env lid
  | Ill_typed_functor_application lid ->
      fprintf ppf "Ill-typed functor application %a" longident lid
  | Illegal_reference_to_recursive_module ->
      fprintf ppf "Illegal recursive module reference"
  | Access_functor_as_structure lid ->
      fprintf ppf "The module %a is a functor, not a structure" longident lid
  | Apply_structure_as_functor lid ->
      fprintf ppf "The module %a is a structure, not a functor" longident lid
  | Cannot_scrape_alias (lid, p) ->
      fprintf ppf "The module %a is an alias for module %a, which is missing"
        longident lid path p

let () =
  Location.register_error_of_exn (function
    | Error (loc, env, err) ->
        Some (Location.error_of_printer loc (report_error env) err)
    | Error_forward err -> Some err
    | _ -> None)

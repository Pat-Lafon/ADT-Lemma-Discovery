module Lit = Lit.Lit (LitTree.LitTree)
module SimpleExpr = SimpleExpr.SimpleExpr (SimpleExprTree.SimpleExprTree (Lit))
module Epr = Epr.Epr (EprTree.EprTree (SimpleExpr))
module SpecAst = Ast.Ast (AstTree.AstTree (Epr))

module Helper = struct
  open SpecAst
  open Utils
  module SE = E.SE
  module T = Tp.Tp
  module V = Pred.Value

  type prog = {
    name : string;
    intps : T.t list;
    outtps : T.t list;
    prog : V.t list -> V.t list;
  }

  let list_var name = SE.Var (T.IntList, name)
  let tree_var name = SE.Var (T.IntTree, name)
  let treei_var name = SE.Var (T.IntTreeI, name)
  let treeb_var name = SE.Var (T.IntTreeB, name)
  let int_var name = SE.Var (T.Int, name)
  let bool_var name = SE.Var (T.Bool, name)

  let add_spec spectab name args fv body =
    StrMap.add name (args, (fv, body)) spectab

  let add_spec_ret_fun spectab name args fv body =
    ( StrMap.add name (args, (fv, body)) spectab,
      fun args -> SpecApply (name, args) )

  let l0 = list_var "l0"
  let l1 = list_var "l1"
  let l2 = list_var "l2"
  let l3 = list_var "l3"
  let l4 = list_var "l4"
  let l5 = list_var "l5"
  let l6 = list_var "l6"
  let ltmp0 = list_var "ltmp0"
  let t1 = list_var "t1"
  let t2 = list_var "t2"
  let a = int_var "a"
  let b = int_var "b"
  let x = int_var "x"
  let y = int_var "y"
  let z = int_var "z"
  let u = int_var "u"
  let v = int_var "v"
  let w = int_var "w"
  let h1 = int_var "h1"
  let h2 = int_var "h2"
  let bool0 = bool_var "bool0"
  let booltrue = SE.Literal (T.Bool, SE.L.Bool true)
  let boolfalse = SE.Literal (T.Bool, SE.L.Bool false)
  let const0 = SE.Literal (T.Int, SE.L.Int 0)
  let const1 = SE.Literal (T.Int, SE.L.Int 1)
  let int_plus a b = SE.Op (T.Int, "+", [ a; b ])
  let list_once l u = E.Atom (SE.Op (T.Bool, "list_once", [ l; u ]))
  let list_member l u = E.Atom (SE.Op (T.Bool, "list_member", [ l; u ]))
  let tree_member l u = E.Atom (SE.Op (T.Bool, "tree_member", [ l; u ]))
  let treei_member l u = E.Atom (SE.Op (T.Bool, "treei_member", [ l; u ]))
  let treeb_member l u = E.Atom (SE.Op (T.Bool, "treeb_member", [ l; u ]))
  let list_head l u = E.Atom (SE.Op (T.Bool, "list_head", [ l; u ]))
  let tree_once l u = E.Atom (SE.Op (T.Bool, "tree_once", [ l; u ]))
  let tree_head l u = E.Atom (SE.Op (T.Bool, "tree_head", [ l; u ]))
  let treei_head l u = E.Atom (SE.Op (T.Bool, "treei_head", [ l; u ]))
  let treeb_head l u = E.Atom (SE.Op (T.Bool, "treeb_head", [ l; u ]))
  let list_order l u v = E.Atom (SE.Op (T.Bool, "list_order", [ l; u; v ]))
  let list_next l u v = E.Atom (SE.Op (T.Bool, "list_next", [ l; u; v ]))
  let tree_leaf t u = E.Atom (SE.Op (T.Bool, "tree_leaf", [ t; u ]))
  let treel t u v = E.Atom (SE.Op (T.Bool, "tree_left", [ t; u; v ]))
  let treer t u v = E.Atom (SE.Op (T.Bool, "tree_right", [ t; u; v ]))
  let treep t u v = E.Atom (SE.Op (T.Bool, "tree_parallel", [ t; u; v ]))
  let treeil t u v = E.Atom (SE.Op (T.Bool, "treei_left", [ t; u; v ]))
  let treeir t u v = E.Atom (SE.Op (T.Bool, "treei_right", [ t; u; v ]))
  let treeip t u v = E.Atom (SE.Op (T.Bool, "treei_parallel", [ t; u; v ]))
  let treebl t u v = E.Atom (SE.Op (T.Bool, "treeb_left", [ t; u; v ]))
  let treebr t u v = E.Atom (SE.Op (T.Bool, "treeb_right", [ t; u; v ]))
  let treebp t u v = E.Atom (SE.Op (T.Bool, "treeb_parallel", [ t; u; v ]))
  let tree_parent t u v = E.Or [ treel t u v; treer t u v ]
  let tree_any_order t u v = E.Or [ treel t u v; treer t u v; treep t u v ]
  let treei_any_order t u v = E.Or [ treeil t u v; treeir t u v; treeip t u v ]
  let treeb_any_order t u v = E.Or [ treebl t u v; treebr t u v; treebp t u v ]

  let tree_ancestor t u v =
    E.Atom (SE.Op (T.Bool, "tree_ancestor", [ t; u; v ]))

  let treei_ancestor t u v =
    E.Atom (SE.Op (T.Bool, "treei_ancestor", [ t; u; v ]))

  let treeb_ancestor t u v =
    E.Atom (SE.Op (T.Bool, "treeb_ancestor", [ t; u; v ]))

  let int_ge a b = E.Atom (SE.Op (T.Bool, ">=", [ a; b ]))
  let int_le a b = E.Atom (SE.Op (T.Bool, "<=", [ a; b ]))
  let int_lt a b = E.Atom (SE.Op (T.Bool, "<", [ a; b ]))
  let int_gt a b = E.Atom (SE.Op (T.Bool, ">", [ a; b ]))
  let int_eq a b = E.Atom (SE.Op (T.Bool, "==", [ a; b ]))
  let le args = SpecApply ("le", args)
  let lt args = SpecApply ("lt", args)
  let gt args = SpecApply ("gt", args)
  let intadd args = SpecApply ("intadd", args)
  let inteq args = SpecApply ("inteq", args)
  let poly_eq args = SpecApply ("equal", args)

  let predefined_spec_tab =
    let spec_tab = StrMap.empty in
    let spec_tab =
      add_spec spec_tab "Plus"
        [ (T.Int, "x"); (T.Int, "y"); (T.Int, "z") ]
        []
        (int_eq (int_plus x y) z)
    in
    let spec_tab =
      add_spec spec_tab "Le" [ (T.Int, "x"); (T.Int, "y") ] [] (int_le x y)
    in
    let spec_tab =
      add_spec spec_tab "le"
        [ (T.Int, "x"); (T.Int, "y"); (T.Bool, "bool0") ]
        []
        (int_eq (SE.Op (T.Bool, "<=", [ x; y ])) bool0)
    in
    let spec_tab =
      add_spec spec_tab "lt"
        [ (T.Int, "x"); (T.Int, "y"); (T.Bool, "bool0") ]
        []
        (int_eq (SE.Op (T.Bool, "<", [ x; y ])) bool0)
    in
    let spec_tab =
      add_spec spec_tab "gt"
        [ (T.Int, "x"); (T.Int, "y"); (T.Bool, "bool0") ]
        []
        (int_eq (SE.Op (T.Bool, ">", [ x; y ])) bool0)
    in
    let spec_tab =
      add_spec spec_tab "intadd"
        [ (T.Int, "x"); (T.Int, "y"); (T.Int, "z") ]
        []
        (int_eq (SE.Op (T.Bool, "+", [ x; y ])) z)
    in
    let spec_tab =
      add_spec spec_tab "inteq"
        [ (T.Int, "x"); (T.Int, "y"); (T.Bool, "bool0") ]
        []
        (int_eq (SE.Op (T.Bool, "==", [ x; y ])) bool0)
    in
    let spec_tab =
      add_spec spec_tab "equal" [ (T.Int, "x"); (T.Int, "y") ] [] (int_eq x y)
    in
    let spec_tab =
      add_spec spec_tab "is_true" [ (T.Bool, "x") ] [] (int_eq x booltrue)
    in
    let spec_tab =
      add_spec spec_tab "is_false" [ (T.Bool, "x") ] [] (int_eq x boolfalse)
    in
    spec_tab

  let is_true b = SpecApply ("is_true", [ b ])
  let is_false b = SpecApply ("is_false", [ b ])

  type hole = { name : string; args : T.tpedvar list }

  open Yojson.Basic

  let encode_hole hole =
    `Assoc
      [
        ("name", `String hole.name);
        ("args", `List (List.map T.tpedvar_encode hole.args));
      ]

  let decode_hole json =
    let open Util in
    {
      name = json |> member "name" |> to_string;
      args = json |> member "args" |> decode_list "decode_hole" T.tpedvar_decode;
    }
end

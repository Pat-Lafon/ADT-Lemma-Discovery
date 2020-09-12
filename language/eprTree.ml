module type EprTree = sig
  module B: Bexpr.Bexpr
  type t =
    | True
    | Atom of B.t
    | Implies of t * t
    | Ite of t * t * t
    | Not of t
    | And of t list
    | Or of t list
    | Iff of t * t
  type free_variable = string
  type forallformula = free_variable list * t
  val layout: t -> string
  val layout_forallformula: forallformula -> string
  val subst: t -> string list -> B.t list -> t
  val subst_forallformula: forallformula -> string list -> B.t list -> forallformula
end

module EprTree(B: Bexpr.Bexpr) : EprTree
  with type B.L.t = B.L.t
  with type B.tp = B.tp
  with type B.t = B.t = struct
  module B = B
  open Utils

  type t =
    | True
    | Atom of B.t
    | Implies of t * t
    | Ite of t * t * t
    | Not of t
    | And of t list
    | Or of t list
    | Iff of t * t
  type free_variable = string
  type forallformula = free_variable list * t

  let rec layout = function
    | True -> "true"
    | Atom bexpr -> Printf.sprintf "(%s)" (B.layout bexpr)
    | Implies (p1, p2) -> Printf.sprintf "(%s => %s)" (layout p1) (layout p2)
    | And ps -> List.inner_layout (List.map layout ps) "/\\" "true"
    | Or ps -> List.inner_layout (List.map layout ps) "\\/" "true"
    | Not p -> "~"^(layout p)
    | Iff (p1, p2) -> Printf.sprintf "(%s <=> %s)" (layout p1) (layout p2)
    | Ite (p1, p2, p3) ->
      Printf.sprintf "(ite %s %s %s)" (layout p1) (layout p2) (layout p3)

  let layout_forallformula (forallvars, body) =
    if (List.length forallvars) == 0 then layout body else
      Printf.sprintf "forall %s,%s" (List.inner_layout forallvars " " "") (layout body)

  let subst body args argsvalue =
    let rec aux = function
      | True -> True
      | Atom bexpr -> Atom (B.subst bexpr args argsvalue)
      | Implies (p1, p2) -> Implies (aux p1, aux p2)
      | And ps -> And (List.map aux ps)
      | Or ps -> Or (List.map aux ps)
      | Not p -> Not (aux p)
      | Iff (p1, p2) -> Iff (aux p1, aux p2)
      | Ite (p1, p2, p3) -> Ite (aux p1, aux p2, aux p3)
    in
    aux body

  let subst_forallformula (fv, body) args argsvalue =
   fv, subst body args argsvalue
end

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

(***********************************************************************)
(**                                                                   **)

(**               WARNING WARNING WARNING                             **)

(**                                                                   **)

(** When you change this file, you must make the parallel change      **)

(** in config.mlbuild                                                 **)

(**                                                                   **)
(***********************************************************************)

(* The main OCaml version string has moved to ../VERSION *)
let version = Sys.ocaml_version
let standard_library_default = "/usr/local/lib/ocaml"

let standard_library =
  try Sys.getenv "OCAMLLIB"
  with Not_found -> (
    try Sys.getenv "CAMLLIB" with Not_found -> standard_library_default)

let standard_runtime = "/usr/local/bin/ocamlrun"
let ccomp_type = "cc"

let bytecomp_c_compiler =
  "gcc -O2 -fno-strict-aliasing -fwrapv -Wall -D_FILE_OFFSET_BITS=64 \
   -D_REENTRANT "

let bytecomp_c_libraries = "-lcurses -lpthread                  "

let native_c_compiler =
  "gcc -O2 -fno-strict-aliasing -fwrapv -Wall -D_FILE_OFFSET_BITS=64 \
   -D_REENTRANT"

let native_c_libraries = ""
let native_pack_linker = "ld -r -arch x86_64  -o "
let ranlib = "ranlib"
let ar = "ar"
let cc_profile = "-pg"

let mkdll, mkexe, mkmaindll =
  (* @@DRA Cygwin - but only if shared libraries are enabled, which we
     should be able to detect? *)
  if Sys.os_type = "Win32" then
    try
      let flexlink =
        let flexlink = Sys.getenv "OCAML_FLEXLINK" in
        let f i =
          let c = flexlink.[i] in
          if c = '/' then '\\' else c
        in
        String.init (String.length flexlink) f ^ " %%FLEXLINK_FLAGS%%"
      in
      (flexlink, flexlink ^ " -exe", flexlink ^ " -maindll")
    with Not_found ->
      ( "gcc -bundle -flat_namespace -undefined suppress                    \
         -Wl,-no_compact_unwind",
        "gcc -Wl,-no_compact_unwind",
        "gcc -bundle -flat_namespace -undefined suppress                    \
         -Wl,-no_compact_unwind" )
  else
    ( "gcc -bundle -flat_namespace -undefined suppress                    \
       -Wl,-no_compact_unwind",
      "gcc -Wl,-no_compact_unwind",
      "gcc -bundle -flat_namespace -undefined suppress                    \
       -Wl,-no_compact_unwind" )

let flambda = false

let exec_magic_number = "Caml1999X011"
and cmi_magic_number = "Caml1999I020"
and cmo_magic_number = "Caml1999O011"
and cma_magic_number = "Caml1999A012"
and cmx_magic_number = if flambda then "Caml1999Y016" else "Caml1999Y015"
and cmxa_magic_number = if flambda then "Caml1999Z015" else "Caml1999Z014"
and ast_impl_magic_number = "Caml1999M019"
and ast_intf_magic_number = "Caml1999N018"
and cmxs_magic_number = "Caml2007D002"
and cmt_magic_number = "Caml2012T007"

let load_path = ref ([] : string list)
let interface_suffix = ref ".mli"
let max_tag = 245

(* This is normally the same as in obj.ml, but we have to define it
   separately because it can differ when we're in the middle of a
   bootstrapping phase. *)
let lazy_tag = 246
let max_young_wosize = 256
let stack_threshold = 256 (* see byterun/config.h *)
let stack_safety_margin = 60
let architecture = "amd64"
let model = "default"
let system = "macosx"
let asm = "clang -arch x86_64 -c"
let asm_cfi_supported = true
let with_frame_pointers = false
let ext_obj = ".o"
let ext_asm = ".s"
let ext_lib = ".a"
let ext_dll = ".so"
let host = "x86_64-apple-darwin18.7.0"
let target = "x86_64-apple-darwin18.7.0"

let default_executable_name =
  match Sys.os_type with
  | "Unix" -> "a.out"
  | "Win32" | "Cygwin" -> "camlprog.exe"
  | _ -> "camlprog"

let systhread_supported = true

let print_config oc =
  let p name valu = Printf.fprintf oc "%s: %s\n" name valu in
  let p_bool name valu = Printf.fprintf oc "%s: %B\n" name valu in
  p "version" version;
  p "standard_library_default" standard_library_default;
  p "standard_library" standard_library;
  p "standard_runtime" standard_runtime;
  p "ccomp_type" ccomp_type;
  p "bytecomp_c_compiler" bytecomp_c_compiler;
  p "bytecomp_c_libraries" bytecomp_c_libraries;
  p "native_c_compiler" native_c_compiler;
  p "native_c_libraries" native_c_libraries;
  p "native_pack_linker" native_pack_linker;
  p "ranlib" ranlib;
  p "cc_profile" cc_profile;
  p "architecture" architecture;
  p "model" model;
  p "system" system;
  p "asm" asm;
  p_bool "asm_cfi_supported" asm_cfi_supported;
  p_bool "with_frame_pointers" with_frame_pointers;
  p "ext_obj" ext_obj;
  p "ext_asm" ext_asm;
  p "ext_lib" ext_lib;
  p "ext_dll" ext_dll;
  p "os_type" Sys.os_type;
  p "default_executable_name" default_executable_name;
  p_bool "systhread_supported" systhread_supported;
  p "host" host;
  p "target" target;
  p_bool "flambda" flambda;

  (* print the magic number *)
  p "exec_magic_number" exec_magic_number;
  p "cmi_magic_number" cmi_magic_number;
  p "cmo_magic_number" cmo_magic_number;
  p "cma_magic_number" cma_magic_number;
  p "cmx_magic_number" cmx_magic_number;
  p "cmxa_magic_number" cmxa_magic_number;
  p "ast_impl_magic_number" ast_impl_magic_number;
  p "ast_intf_magic_number" ast_intf_magic_number;
  p "cmxs_magic_number" cmxs_magic_number;
  p "cmt_magic_number" cmt_magic_number;

  flush oc

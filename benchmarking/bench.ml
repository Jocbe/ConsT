open Lwt

(* This is a tool designed to test the performance of authbuider. It will take a file as input 
   and dispatch connections to the hosts specified in the input file. All destinations on a
   single line of the input file will be dispatched simultaneously and the next line will be
   dispatched once the previous one has completed either successfully or with an error. *)

let _LOGLEVEL = 0
let d l m =
  if l <= _LOGLEVEL then
    Lwt_io.printf "level %i: %s" l m
  else
    return ()

(* Set variables required for test *)
let ts_ca = "../certs/demoCA.crt"
let ts_host = Sys.argv.(1)
let ts_port = int_of_string Sys.argv.(2)

let test_file = Sys.argv.(3)
let mode = int_of_string Sys.argv.(4)
lwt output_file =
  if Array.length Sys.argv > 5 then
    Lwt_io.(open_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL] ~mode:Output Sys.argv.(5))
  else
    return Lwt_io.stdout


let parse_url url = 
  let len = String.length url in
  let (slash_pos, path) = 
    if String.contains url '/' then
      let pos = String.index url '/' in
      let path = String.sub url pos (len - pos) in
      (pos, path)
    else 
      (len, "/")
  in

  let (colon_pos, port) =
    if String.contains url ':' then
      let pos = String.index url ':' in
      let port = int_of_string (String.sub url (pos + 1) (slash_pos - pos - 1)) in
      (pos, port)
    else
      (slash_pos, 443)
  in

  let host = String.sub url 0 colon_pos in
  let filename =
    if String.contains url '/' then
      let pos = String.rindex url '/' in
      if pos + 1 < len then
	String.sub url (pos + 1) (len - pos - 1)
      else
	"index.html"
    else
      "index.html"
  in
  (host, port, path, filename)

let load_from_file path = 
  lwt ic = Lwt_io.open_file ~flags:[Unix.O_RDONLY] ~mode:Lwt_io.Input test_file in
  lwt str_in = Lwt_io.read ic in
  let lines = Str.(split (regexp "[\n\r]+") str_in) in
  lwt urls = Lwt_list.map_p (fun s -> return Str.(split (regexp "[ \t]+") s)) lines in
  let parse_list urls = Lwt_list.map_p (fun s -> return (parse_url s)) urls in
  Lwt_list.map_p parse_list urls

let make_req host path = 
  String.concat "\r\n" [
    "GET " ^ path ^ " HTTP/1.1" ; "Host: " ^ host ; "Connection: close" ; "" ; ""
  ]  

let run_bench confun urls =
  let do_get (host, port, path, filename) =
begin

try_lwt
    let req = make_req host path in
    let starttime = Unix.gettimeofday () in
    (*lwt (ic, oc) = client#connect (host, port) in*)
    lwt () = d 8 ("Connecting to " ^ host ^ ":" ^ string_of_int port ^ "...\n") in
    lwt (ic, oc) = confun (host, port) in
    let conntime = Unix.gettimeofday () in
    lwt () = d 8 "Sending request...\n" in
    (*lwt () = Lwt_io.flush_all () in*)
    lwt data = Lwt_io.(write oc req >> read ic) in
    let resptime = Unix.gettimeofday () in
    lwt () = Lwt_io.(close ic; close oc) in
    return (starttime, conntime, resptime)
with | _ ->
    lwt () = d 4 ("Error while trying to connect to " ^ host ^ ":" ^ string_of_int port ^ "\n") in
    return (0.0,0.0,0.0)
end
  in

  let x = ref 0 in
  let get_all list =
    lwt () = Lwt_io.printf "Getting %i\n" !x in
    let () = x := !x + 1 in
    let starttime = Unix.gettimeofday () in
    lwt res = Lwt_list.map_p do_get list in
    let endtime = Unix.gettimeofday () in
    return ((starttime, endtime), res)
  in
  let starttime = Unix.gettimeofday () in
  lwt res = Lwt_list.map_s get_all urls in
  let endtime = Unix.gettimeofday () in
  return ((starttime, endtime), res)

lwt () = 
  lwt () = Tls_lwt.rng_init () in
  lwt urls = load_from_file test_file in

  (* By choosing this function, the traditional authenticator is used for authentication *)
  let benchmark_traditional () =
    lwt () = Lwt_io.print "Running benchmark with traditional authenticator\n" in
    let confun = fun (host, port) ->
      (*lwt auth = X509_lwt.authenticator (`Ca_file "../certs/rootCA_jocbe_2015.crt") in*)
      lwt auth = X509_lwt.authenticator (`Ca_file "../certs/demoCA.crt") in
      Tls_lwt.connect auth (host, port)
    in
    run_bench confun urls
  in

  (* By choosing this function, ConTrust (authbuilder) is used for authentication *)
  let benchmark_project () =
    lwt () = Lwt_io.print "Running benchmark with project authenticator\n" in
    let conf = Abuilder.Conf.of_authlet (Abuilder.Authlet.ca_file ts_ca) in
    lwt client = Trust_client.of_ts_info ((ts_host, ts_port), conf) in
    lwt () = d 10 ("Attempting to connect to TS " ^ ts_host ^ ":" ^ string_of_int ts_port ^ "...\n") in
    let confun = fun (host, port) -> 
      lwt () = d 10 ("Using client object to connect to " ^ host ^ ":" ^ string_of_int port ^ "...\n") in
      lwt ret = client#connect (host, port) in
      lwt () = d 10 ("Connected to " ^ host ^ ":" ^ string_of_int port ^ ", returning.") in
      return ret
    in
    lwt () = d 10 ("Running benchmark...\n") in
    run_bench confun urls
  in

  lwt ((starttime, endtime), res) = 
    if mode = 0 then
      benchmark_traditional ()
    else if mode = 1 then
      benchmark_project ()
    else
      raise (Invalid_argument "Mode must be 0 or 1")
  in

  lwt () = Lwt_list.iter_s (fun x -> Lwt_io.print "--------\n" >> Lwt_list.iter_p (fun (h, po, pa, f) -> Lwt_io.printf "%s:%i%s -> %s\n" h po pa f) x) urls in
  let offset = 0.0 in
  let printtime prest (st, ct, rt) =
    lwt () = Lwt_io.fprintf output_file "%s%f;%f;%f\n" prest (st -. offset) (ct -. offset) (rt -. offset) in
    return ()
  in
  let printtimes prest ((st, et), ts) =
    lwt () = Lwt_io.(fprintf output_file "%s%f;%f\n" prest (st -. offset) (et -. offset) >> Lwt_list.iter_s (printtime (prest ^ ";;")) ts) in
    return ()
  in
  lwt () = Lwt_io.(fprintf output_file "%f;%f\n" (starttime -. offset) (endtime -. offset) >> Lwt_list.iter_s (printtimes ";;") res) in
  return ()

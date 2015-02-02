open Lwt

let ts_ca = "/home/jocbe/sdev/ConsT/certs/demoCA.crt"

let ts_host = Sys.argv.(1)
let ts_port = int_of_string Sys.argv.(2)
(*let r_host = Sys.argv.(3)
let r_port = int_of_string Sys.argv.(4)
let r_path = Sys.argv.(5)*)

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

let rec write_file ?num filename data =
  let filename_postfix = match num with
    | None -> filename
    | Some n -> 
      if String.contains filename '.' then
	let pos = String.rindex filename '.' in
	(String.sub filename 0 pos) ^ "_(" ^ (string_of_int n) ^ ")" ^ (String.sub filename pos ((String.length filename) - pos))
      else
	filename ^ "_(" ^ string_of_int n ^ ")"
  in
  begin try_lwt
    lwt oc = Lwt_io.open_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL] ~mode:Lwt_io.Output filename_postfix in
    Lwt_io.(write oc data >> close oc)
  with
  | Unix.Unix_error _ -> match num with
    | None -> write_file ~num:1 filename data
    | Some n -> write_file ~num:(n + 1) filename data
  end  

let rec get_all client i =
  if Array.length Sys.argv > i then
    let (host, port, path, filename) = parse_url Sys.argv.(i) in
    lwt () = Lwt_io.printf "#################\nGetting #%i: %s:%i%s...\n" i host port path in
    lwt () = begin try_lwt
      lwt (ic, oc) = client#connect (host, port) in
      let req = String.concat "\r\n" [
	"GET " ^ path ^ " HTTP/1.1" ; "Host: " ^ host ; "Connection: close" ; "" ; ""
      ] in
      (*lwt () = Lwt_io.(write oc req >> read ic >>= printf "Got this for #%i:\n%s\n" i) in*)
      lwt () = Lwt_io.(write oc req >> read ic >>= write_file ("downloads/" ^ filename) >> print "Yay\n\n") in
      Lwt_io.(close oc >> close ic);
      (*get_all client (i + 1)*)
    with
    | Tls_lwt.Tls_failure _ ->
        Lwt_io.print "TLS failure! Not connecting.\n";
        (*get_all client (i + 1)*)
    | Invalid_argument m ->
        Lwt_io.printf "Invalid Argument: %s\n" m;
        (*get_all client (i + 1)*)
    end in
    lwt () = Lwt_io.printf "END: %i\n" i in
    get_all client (i + 1)
  else return ()

let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  let conf = Abuilder.Conf.from_authlet (Abuilder.Authlet.ca_file ts_ca) in
  lwt client = Trust_client.from_ts_info ((ts_host, ts_port), conf) in
  get_all client 3
  (*lwt (ic, oc) = client#connect (r_host, r_port) in
  let req = String.concat "\r\n" [
    "GET " ^ r_path ^ " HTTP/1.1" ; "Host: " ^ r_host ; "Connection: close" ; "" ; ""
  ] in
  Lwt_io.(write oc req >> read ic >>= printf "Got this:\n%s\n")*)
end


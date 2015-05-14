open Lwt

(* This application is a simple wget-like tool that will send HTTPS requests 
   to retrieve the file(s) from url(s) given as arguments. It uses ConTrust
   (the authbuilder library) for authentication. This tool only works via
   TLS and will not work for plain HTTP! *)

let ts_ca = "../certs/demoCA.crt"
let ts_host = Sys.argv.(1)
let ts_port = int_of_string Sys.argv.(2)

(* Some logic to extract the host, port and path from a URL of
   the form: <host>[:port][/path] *)
let parse_url url = 
  let len = String.length url in
  
  (* Find the start of the path (first slash - we do not handle
     urls starting with "http://" or "https://" at the moment *)
  let (slash_pos, path) = 
    if String.contains url '/' then
      let pos = String.index url '/' in
      let path = String.sub url pos (len - pos) in
      (pos, path)
    else 
      (len, "/")
  in

  (* Find where the port number is *)
  let (colon_pos, port) =
    if String.contains url ':' then
      let pos = String.index url ':' in
      let port = int_of_string (String.sub url (pos + 1) (slash_pos - pos - 1)) in
      (pos, port)
    else
      (slash_pos, 443)
  in

  let host = String.sub url 0 colon_pos in

  (* Attempt to determine the file name. If it isn't given by the
     path, then default to index.html *)
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

(* A function to write the file we received to disk. *)
let rec write_file ?num filename data =

  (* Some logic for renaming a file if a file with the same name already
     exists. Say file xyz.ext already exists. The file is then renamed
     to xyz_(N).ext where N is the minimun positive integer such that a
     file with that name does not already exist. *)
  let filename_postfix = match num with
    | None -> filename
    | Some n -> 
      if String.contains filename '.' then
	let pos = String.rindex filename '.' in
	(String.sub filename 0 pos) ^ "_(" ^ (string_of_int n) ^ ")" ^ (String.sub filename pos ((String.length filename) - pos))
      else
	filename ^ "_(" ^ string_of_int n ^ ")"
  in
  
  (* Finally, attepmt to write the file to disk *)
  begin try_lwt
    lwt oc = Lwt_io.open_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL] ~mode:Lwt_io.Output filename_postfix in
    Lwt_io.(write oc data >> close oc >> printf "Wrote to file '%s'\n" filename_postfix)
    with
      | Unix.Unix_error _ -> match num with
      | None -> write_file ~num:1 filename data
      | Some n -> write_file ~num:(n + 1) filename data
  end  

(* Function to retrieve the data from all given urls sequentially *)
let rec get_all client i =
  if Array.length Sys.argv > i then
    let (host, port, path, filename) = parse_url Sys.argv.(i) in
    lwt () = Lwt_io.printf "#################\nGetting #%i: %s:%i%s...\n" (i-2) host port path in

    lwt () = begin try_lwt
      lwt (ic, oc) = client#connect (host, port) in

      let req = String.concat "\r\n" [
	"GET " ^ path ^ " HTTP/1.1" ; "Host: " ^ host ; "Connection: close" ; "" ; ""
      ] in

      (* This application is for demonstration purposes. Hence, to keep our
	 directory clean, we will download everything to ./downloads/ *)
      lwt () = Lwt_io.(write oc req >> read ic >>= write_file ("downloads/" ^ filename)) in
      Lwt_io.(close oc >> close ic);

    with
      | Tls_lwt.Tls_failure _ ->
          Lwt_io.print "TLS failure! Not connecting.\n";
      | Invalid_argument m ->
          Lwt_io.printf "Invalid Argument: %s\n" m;
    end in

    lwt () = Lwt_io.printf "END: %i\n" i in

    (* Get next url *)
    get_all client (i + 1)
  else return ()

let () = Lwt_main.run begin
  (* Make sure the random generator is seeded *)
  lwt () = Tls_lwt.rng_init () in
		      
  (* Retrieve a configuration from the trust server... *)
  let conf = Abuilder.Conf.of_authlet (Abuilder.Authlet.ca_file ts_ca) in
  (* ...and create a client with it. *)
  lwt client = Trust_client.of_ts_info ((ts_host, ts_port), conf) in

  (* The '3' here simply indicates that the first url to get will be
     argument number 3. *)
  get_all client 3

end


open Lwt
open Unix

let host = Sys.argv.(1)
let port = 
  if Array.length Sys.argv > 2 then
    int_of_string Sys.argv.(2)
  else
    443;;
let path = Sys.argv.(3)
let ts_host = "localhost"
let ts_port = 8080;;

let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  
  let authlet_r = Abuilder.Authlet.remote ~port:ts_port ts_host in
  let authlet_l = Abuilder.Authlet.logger "test.log" in
  let cnf = Abuilder.Conf.add (Abuilder.Conf.from_authlet authlet_r) authlet_l in
  
  lwt auth = Abuilder.Conf.build cnf in
  lwt (ic, oc) = Tls_lwt.connect auth (host, port) in
  
  let req = String.concat "\r\n" [
    "GET " ^ path ^ " HTTP/1.1" ; "Host: " ^ host  ; "Connection: close" ; "" ; ""
  ] in 
  Lwt_io.(write oc req >> read ic >>= printf "Got this:\n%s\n")

 (* let ts_addr = Unix.ADDR_INET ((gethostbyname ts_host).h_addr_list.(0), ts_port) in
  lwt () = Tls_lwt.rng_init ()in
  let authenticator = X509.Authenticator.remote ts_addr (host, port) in
(*  and ts_authenticator = X509_lwt.authenticator (`Ca_file "/home/jocbe/sdev/ConsT/certs/demoCA.crt") in*)
  lwt (ic, oc) = Tls_lwt.connect authenticator (host, port) in
(*  lwt (ts_ic, ts_oc) = Tls_lwt.connect ts_authenticator (ts_host, ts_port) in*)
  Lwt_io.(close ic >> close oc)
  (*let ts_req = "Trying to get trust info for host " ^ host ^ " on port " ^ (string_of_int port) ^ "." in*)
  (*let ts_req = ((host, port), None) in
  Lwt_io.(write_value ts_oc ts_req >> (*print "Received:\n" >>*) read ts_ic >>= print >> print "\nDone.\n")*)
 *)
end

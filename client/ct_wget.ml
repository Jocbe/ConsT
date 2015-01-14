open Lwt
open Unix

let host = Sys.argv.(1)
let port = 
  if Array.length Sys.argv > 2 then
    int_of_string Sys.argv.(2)
  else
    443;;
let ts_host = "localhost"
let ts_port = 8080;;

Lwt_main.run begin
  let ts_addr = Unix.ADDR_INET ((gethostbyname ts_host).h_addr_list.(0), ts_port) in
  lwt () = Tls_lwt.rng_init ()in
  let authenticator = X509.Authenticator.remote ts_addr (host, port) in
(*  and ts_authenticator = X509_lwt.authenticator (`Ca_file "/home/jocbe/sdev/ConsT/certs/demoCA.crt") in*)
  lwt (ic, oc) = Tls_lwt.connect authenticator (host, port) in
(*  lwt (ts_ic, ts_oc) = Tls_lwt.connect ts_authenticator (ts_host, ts_port) in*)
  Lwt_io.(close ic >> close oc)
  (*let ts_req = "Trying to get trust info for host " ^ host ^ " on port " ^ (string_of_int port) ^ "." in*)
  (*let ts_req = ((host, port), None) in
  Lwt_io.(write_value ts_oc ts_req >> (*print "Received:\n" >>*) read ts_ic >>= print >> print "\nDone.\n")*)
  
end

open Lwt

(* This application is a simple demonstration of how to create a trust server.
   It contains a number of authlets/authenticators that may be used. *)

(* Some trusted certificates that will be used *)
let server_cert_file = "../certs/ubtest02.crt"
let server_pk_file = "../certs/ubtest02.key"
let trusted_cas = "../certs/trusted_cas"
let trusted_rcert = "~/Desktop/www-google-co-uk_cert.crt"
let ts_ca = "../certs/demoCA.crt"
let max_con = 16
let port = int_of_string Sys.argv.(1)

(* Select the authlets to be enabled/disabled *)
(* Authlets that will be contained in the client policy *)
let c_cafile = true  (* A simple whitelist CA file (trusted_cas) *)
let c_logger = false (* A logger authlet. Note: will not actually authenticate certs *)
let c_remote = true  (* Will contact the TS on every handshake *)
let c_cache = true   (* Enable/disable the client-side cache *)
let c_cert = false   (* Trust only specific certificates *)

(* Authlets that will be contained in the server config *)
let s_cafile = true  (* Same as above but on server *)
let s_logger = false (* Same as above but on server *)
let s_notary = false (* Trust server acts as a notary *)
let s_cert = false   (* Same as above but on server *)


let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  (* Display which authlets we have enabled *)
  lwt () = Lwt_io.printf "Starting server: %s%s, %s, %s (%s%s, %s, %s) | %s..."
      (if c_cafile then "ca_file" else "-")
      (if c_cert then "/cert" else "")
      (if c_logger then "logger" else "-")
      (if c_remote then "remote" else "-")
      (if s_cafile then "ca_file" else "-")
      (if s_cert then "/cert" else "")
      (if s_logger then "logger" else "-")
      (if s_notary then "notary" else "-")
      (if c_cache then "cache" else "-")
  in
  
  (* The address we will be listening on - here any address *)
  let addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "0.0.0.0", port) in
  lwt cert_key_pair = X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file in

  (* Defining the various authlets that are available in this set-up *)
  let logger = Abuilder.Authlet.logger "test.log" in
  let ca_file = Abuilder.Authlet.ca_file trusted_cas in
  let rh_file = Abuilder.Authlet.certs trusted_rcert in
  let remote = Abuilder.Authlet.remote_ca_file ts_ca ~port:port "ubtest02" in
  let cache = Abuilder.Cache.simple 60.0 in
  let notary = Abuilder.Authlet.notary in

  (* Creating the server config. Do this by selecting the authlets corresponding to the user settings above.
     Once a list has been compiled, this list can be converted to authlets. *)
  let server_list = List.append (if s_cert then [rh_file] else []) (
                    List.append (if s_cafile then [ca_file] else []) (
		    List.append (if s_logger then [logger] else [])
                                (if s_notary then [notary] else [])))
  in
  lwt server_conf = Abuilder.Conf.of_a_list server_list in
  (*let client_conf = Abuilder.Conf.new_conf [(*(`Single logger, 0); (`Single ca_file, 3);*) (`Single remote, 10)] [(*(cache, 5)*)] in*)
  (*lwt client_conf = Abuilder.Conf.of_a_list [logger; ca_file; remote] in*)

  (* Now do the same for the client config (a different method used for illustrative purposes *)
  let client_conf = Abuilder.Conf.new_conf 
    (List.append (if c_cert then [(`Single rh_file, 6)] else [])  (List.append (if c_cafile then [(`Single ca_file, 3)] else [])
	(List.append (if c_logger then [(`Single logger, 0)] else []) (if c_remote then [(`Single remote, 10)] else []))
    ))
    (if c_cache then [(cache, 5)] else [])
  in

  (* Make sure the configuration does not refer to external resources, such that it can be sent to clients safely *)
  lwt self_contained = Abuilder.Conf.contain client_conf in
  (*let client_conf = Abuilder.Conf.add_cache client_conf ~priority:5 cache in*)
  lwt ts_conf = Abuilder.Conf.contain (Abuilder.Conf.of_authlet (Abuilder.Authlet.ca_file ts_ca)) in

  let client_policy = Trust_client.client_policy ~ver:1 (*~use_time:(Unix.gettimeofday () +. 60.0)*) ~new_c:(("ubtest02", port), ts_conf) self_contained in
  let server = Trust_server.create ~server_conf:server_conf ~client_policy:client_policy addr max_con cert_key_pair in
  
  (* We could have the server auto-update its configuration. Currently not enabled. *)
  (*server#set_auto_update (
    fun p -> let now = Unix.gettimeofday () in
    Lwt_io.printf "UPDATE (now - expires): %f - %f\n" now (now +. 600.0) ;
    Some (Trust_client.replace_field ~use_time:(now +. 600.0) p)) 10.0 15.0;
  server#auto_update_mode `Lazy;*)
  (*Lwt.async (fun () -> return server#start_auto_update);*)
  
  lwt () = Lwt_io.printf " Started.\n" in
  
  (* Finally, start the server *)
  server#run;
end

open Lwt

let server_cert_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.crt"
let server_pk_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.key"
let trusted_cas = "/home/jocbe/sdev/ConsT/certs/rootCA_jocbe_2015.crt"
let ts_ca = "/home/jocbe/sdev/ConsT/certs/demoCA.crt"
let max_con = 16
let port = int_of_string Sys.argv.(1)

let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  let addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", port) in
  lwt cert_key_pair = X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file in
  let logger = Abuilder.Authlet.logger "test.log" in
  let ca_file = Abuilder.Authlet.ca_file trusted_cas in
  let remote = Abuilder.Authlet.remote_ca_file ts_ca ~port:port "localhost" in
  lwt server_conf = Abuilder.Conf.from_a_list [logger; ca_file] in
  lwt client_conf = Abuilder.Conf.from_a_list [(*logger; ca_file;*) remote] in
  lwt self_contained = Abuilder.Conf.contain client_conf in
  lwt ts_conf = Abuilder.Conf.contain (Abuilder.Conf.from_authlet (Abuilder.Authlet.ca_file ts_ca)) in
  let client_policy = Trust_client.client_policy ~ver:1 ~use_time:(Unix.gettimeofday () +. 60.0) ~new_c:(("localhost", port), ts_conf) self_contained in
  let server = Trust_server.create ~server_conf:server_conf ~client_policy:client_policy addr max_con cert_key_pair in
  server#set_auto_update (
    fun p -> let now = Unix.gettimeofday () in
    Lwt_io.printf "UPDATE (now - expires): %f - %f\n" now (now +. 60.0) ;
    Some (Trust_client.replace_field ~use_time:(now +. 60.0) p)) 10 15.0;
  server#auto_update_mode `Lazy;
  (*Lwt.async (fun () -> return server#start_auto_update);*)
  server#run
end

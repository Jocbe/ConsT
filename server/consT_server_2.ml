open Lwt

(* ##################################################################### *)
(* This application is obsolete! Please refer to consT_server_3 instead! *)
(* ##################################################################### *)

let server_cert_file = "../certs/demo-localhost.crt"
let server_pk_file = "../certs/demo-localhost.key"
let trusted_cas = "../certs/rootCA_jocbe_2015.crt"
let ts_ca = "../certs/demoCA.crt"
let max_con = 16
let port = int_of_string Sys.argv.(1)

let () = Lwt_main.run begin
  let addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", port) in
  lwt cert_key_pair = X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file in
  let logger = Abuilder.Authlet.logger "test.log" in
  let ca_file = Abuilder.Authlet.ca_file trusted_cas in
  let remote = Abuilder.Authlet.remote_ca_file ts_ca ~port:8080 "localhost" in
  (*let remote = Abuilder.Authlet.remote ~port:8080 "localhost" in*)
  (*let policy = Abuilder.Conf.from_authlet logger in
  let policy = Abuilder.Conf.add_authlet policy ca_file in*)
  lwt server_conf = Abuilder.Conf.from_a_list [logger; ca_file] in
  lwt client_conf = Abuilder.Conf.from_a_list [(*logger; ca_file;*) remote] in
  lwt self_contained = Abuilder.Conf.contain client_conf in
  lwt ts_conf = Abuilder.Conf.contain (Abuilder.Conf.from_authlet (Abuilder.Authlet.ca_file ts_ca)) in
  let client_policy = Trust_client.client_policy ~ver:1 ~use_time:(Unix.gettimeofday () +. 600.0) ~new_c:(("localhost", port), ts_conf) self_contained in
  Trust_server.run_server ~server_conf:server_conf ~client_policy:client_policy addr 16 cert_key_pair
end

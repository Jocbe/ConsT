open Lwt

let server_cert_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.crt"
let server_pk_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.key"
let trusted_cas = "/home/jocbe/sdev/ConsT/certs/rootCA_jocbe_2015.crt"
let max_con = 16
let myport = int_of_string Sys.argv.(1);;

let worker ic oc sockaddr () =
  (*lwt ((host, port), cert) = Lwt_io.read_value ic in
  let info = ref None in
  let authenticator = X509.Authenticator.dummy info in
  lwt (ic, oc) = Tsl_lwt.connect authenticator (host, port) in
  Lwt_io.(close ic >> close oc);
  let (m_host, (m_cert, m_stack)) = match info with
    | Some (h, (c, s)) -> (h, (c, s))
    (*| None ->*)*)
  
  lwt ((r_host, r_port), ((c, stack), host)) = Lwt_io.read_value ic in
  let host_str = match host with
    | None -> "UNKNOWN HOST"
    | Some (`Wildcard h) -> h
    | Some (`Strict h) -> h
  in
  lwt authenticator = X509_lwt.authenticator (`Ca_file trusted_cas) in
  Lwt_io.(printf "Host %s, port %i\n" r_host r_port);
  lwt res = X509.Authenticator.authenticate authenticator ?host:host (c, stack) in
  Lwt_io.(write_value oc res >> close oc >> close ic);;

let rec listener (server_certs, pk) server_socket =
  lwt ((ic, oc), sockaddr) = Tls_lwt.accept (server_certs, pk) server_socket in
  Lwt.async (worker ic oc sockaddr);
  listener (server_certs, pk) server_socket;;

let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  lwt (server_certs, pk) = X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file in
  let server_socket = Lwt_unix.socket Lwt_unix.PF_INET Lwt_unix.SOCK_STREAM 0 in
  let myaddr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", myport) in
  Lwt_unix.bind server_socket myaddr;
  Lwt_unix.listen server_socket max_con;
  listener (server_certs, pk) server_socket
  
end

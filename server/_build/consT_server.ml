open Lwt

let host = "DEFAULT HOST"
let port = -1
let server_cert_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.crt"
let server_pk_file = "/home/jocbe/sdev/ConsT/certs/demo-localhost.key"
let max_con = 16
let myport = int_of_string Sys.argv.(1);;

let worker socket sockaddr () =
  let ic = Lwt_io.of_fd ~mode:Lwt_io.input socket in
  let oc = Lwt_io.of_fd ~mode:Lwt_io.output socket in
(*  lwt ((host, port), cert) = Lwt_io.read_value ic in*)
  Lwt_io.(printf "Host %s, port %i\n" host port >> write_value oc "Gotcha!") >> Lwt_unix.close socket;;

let rec listener (server_certs, pk) server_socket =
  (*lwt ((ic, oc), sockaddr) = Tls_lwt.accept (server_certs, pk) server_socket in*)
  lwt (sock, sockaddr) = Lwt_unix.accept server_socket in
  (*let ic = Lwt_io.of_fd ~mode:Lwt_io.input sock in
  let oc = Lwt_io.of_fd ~mode:Lwt_io.output sock in
  Lwt.async (worker ic oc sockaddr);*)
  Lwt.async (worker sock sockaddr);
  listener (server_certs, pk) server_socket;;

let () = Lwt_main.run begin
  lwt () = Tls_lwt.rng_init () in
  lwt (server_certs, pk) = X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file in
  (*let (server_certs, pk) = Lwt_main.run(X509_lwt.private_of_pems ~cert:server_cert_file ~priv_key:server_pk_file) in*)
  let server_socket = Lwt_unix.socket Lwt_unix.PF_INET Lwt_unix.SOCK_STREAM 0 in
  let myaddr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", myport) in
  Lwt_unix.bind server_socket myaddr;
  Lwt_unix.listen server_socket max_con;
  listener (server_certs, pk) server_socket
  
  (*let ((ic, oc), sockaddr) = Lwt_main.run(Tls_lwt.accept (server_certs, pk) server_socket) in*)
  (*let received = Bytes.create 4096 in
  lwt num_rec = Lwt_io.read_into ic received 0 (Bytes.length received) in
  Lwt_io.(printf "Received %i bytes:\n%s\n" num_rec received >> Lwt_io.close ic >> Lwt_io.close oc)*)
end

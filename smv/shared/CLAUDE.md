# Network

Everything this machine sends goes through a proxy on the user's Mac that logs each request. Only HTTP and HTTPS get through: use HTTPS git remotes, not SSH.

Docker containers get the proxy's CA from a runc wrapper (`/opt/smv/docker-runc`): `SSL_CERT_FILE` and similar variables point at `/dev/smv-egress-ca.pem`, and the machine's Java keystore is mounted read-only over the image's. So `keytool -importcert` fails in containers and `RUN` steps, and programs that ignore those variables (apt over HTTPS, anything run under `sudo`) don't trust the proxy.

`GH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN` hold placeholders; the proxy adds the real tokens on the way out.

A 403 whose body starts with "Blocked by the smv egress proxy" means the request contained the user's personal information (their email, name and the like). Don't send it again in another form or encoding. Tell the user what you were trying to send.

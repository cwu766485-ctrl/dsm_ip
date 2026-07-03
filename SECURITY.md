# Security Policy

Do not commit secrets, passwords, license files, private server addresses,
personal account data, or private keys to this repository.

If sensitive data is accidentally committed:

1. Remove it from the current tree.
2. Rotate the exposed credential immediately.
3. Rewrite repository history before publishing, if the data was committed.

Server, VNC, SSH, and license-server details must be stored outside the
repository.

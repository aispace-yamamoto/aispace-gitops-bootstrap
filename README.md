# aispace-gitops-bootstrap (public)

Public loader for the AiSpace GitOps agent. Contains **no secrets and no host data**. It only:
shows the host state (`check`), sets up the authenticator code for GO (`totp-setup`), creates a read-only deploy key, and installs the agent from the
private repository after you confirm the commit. See the private repo `docs/62_bootstrap.md`.

Verify before running: `sha256sum i.sh` must equal
`3eca1b8bc16d25776b153ae5fd9e7c6bb2a7879ab1b14900508ac044f4cd715c` (also announced in the Claude chat).

# aispace-gitops-bootstrap (public)

Public loader for the AiSpace GitOps agent. Contains **no secrets and no host data**. It only:
shows the host state (`check`), creates a read-only deploy key, and installs the agent from the
private repository after you confirm the commit. See the private repo `docs/62_bootstrap.md`.

Verify before running: `sha256sum i.sh` must equal
`9ca20dee7753ddd27591b34dc8392728b33875d4f52fdebc0817b66050c14896` (also announced in the Claude chat).

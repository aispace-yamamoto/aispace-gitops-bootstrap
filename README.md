# aispace-gitops-bootstrap (public)

Public loader for the AiSpace GitOps agent. Contains **no secrets and no host data**. It only:
shows the host state (`check`), creates a read-only deploy key, and installs the agent from the
private repository after you confirm the commit. See the private repo `docs/62_bootstrap.md`.

Verify before running: `sha256sum i.sh` must equal
`e93b82088240777b112263df7dbc7d7566be013c8e42d769fb4e2e6381b226cd` (also announced in the Claude chat).

# aispace-gitops-bootstrap (public)

Public loader for the AiSpace GitOps agent. Contains **no secrets and no host data**. It only:
shows the host state (`check`), creates a read-only deploy key, and installs the agent from the
private repository after you confirm the commit. See the private repo `docs/62_bootstrap.md`.

Verify before running: `sha256sum i.sh` must equal
`4480d5298e105fef8c23538dd892621d59c8977a175156e3f251bf8a76b67c9e` (also announced in the Claude chat).

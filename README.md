# aispace-gitops-bootstrap (public)

Public loader for the AiSpace GitOps agent. Contains **no secrets and no host data**. It only:
shows the host state (`check`), creates a read-only deploy key, and installs the agent from the
private repository after you confirm the commit. See the private repo `docs/62_bootstrap.md`.

Verify before running: `sha256sum i.sh` must equal
`21a62772c2fd5f83d31158f02d84694a0bb0a426e30bef86d2f57951dbe492bf` (also announced in the Claude chat).

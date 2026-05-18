# devenv repro

This repo contains a minimal reproduction under [mre/repro.sh](/home/uzr/work/devenv_repro/mre/repro.sh) for a stale `devenv tasks list` result when `devenv.nix` changes during evaluation.

## Version override mechanism

The repro script supports pinning devenv via env vars

```bash
# Default (pinned): devenv v2.1 tag commit
./mre/repro.sh

# Run against an arbitrary devenv revision/tag/commit
DEVENV_REV=<rev> ./mre/repro.sh

# Run against a specific devenv binary
DEVENV_BIN=/path/to/devenv ./mre/repro.sh
```

The default pin is `DEVENV_REV=2cf62a010000b70f15c78a72761fad7c9e6fb47a` (devenv v2.1.0).

## Findings (this checkout)

Pinned devenv v2.1.0 (`2cf62a010000b70f15c78a72761fad7c9e6fb47a`, `devenv 2.1.0+2cf62a0`):

- `DELAY=0.1`, `0.5`, `1.0`, `1.5`, `2.0`: not reproduced (second `tasks list` contained `demo:show`)
- `DELAY=3.0`, `5.0`: reproduced (second `tasks list` did not contain `demo:show` until `.devenv/nix-eval-cache.db*` was removed)

Current devenv HEAD as tested (`5a8d9c99ef04fe03aa7d8a4918640ab4dd4a6055`, `devenv 2.1.3+5a8d9c9`):

- `DELAY=0.1`: not reproduced
- `DELAY=3.0`, `5.0`: reproduced

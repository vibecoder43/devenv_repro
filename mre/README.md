# devenv task cache MRE

This reproduces a stale task list with only one `devenv` process running at a time.

## Steps

Run:

```bash
./mre/repro.sh
```

Expected behavior after the config change:

- `devenv tasks list` should include `demo:show`.

Observed behavior on `devenv 2.0.6`:

- if `devenv.nix` changes while a `devenv tasks list` run is still evaluating, the completed run can write stale task state
- the next `devenv tasks list` can still print the old default tasks and miss `demo:show`
- removing only `.devenv/task-names.txt` is not enough
- removing only `.devenv/state/tasks.db*` is not enough in the clean race repro
- removing `.devenv/nix-eval-cache.db*` makes `demo:show` appear

The script uses this repo's `devenv.lock` and `devenv.yaml`, creates a fresh temp directory, and then:

1. starts from the default template-like config with no custom tasks
2. starts one `devenv tasks list`
3. rewrites `devenv.nix` to contain only one custom task, `demo:show`, before that run finishes
4. waits for the first run to finish
5. runs `devenv tasks list` again and observes the stale result
6. removes only `.devenv/task-names.txt` and observes that this is still stale
7. removes `.devenv/state/tasks.db*` and observes that this is still stale
8. removes `.devenv/nix-eval-cache.db*`
9. runs `devenv tasks list` again and observes `demo:show`

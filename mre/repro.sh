#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d /tmp/devenv-task-cache-mre.XXXXXX)"
delay="${DELAY:-2.0}"
trap 'rm -rf "$tmp_dir"' EXIT

DEVENV_REV="${DEVENV_REV:-2cf62a010000b70f15c78a72761fad7c9e6fb47a}" # devenv v2.1 tag

if [ -n "${DEVENV_BIN:-}" ]; then
  devenv_cmd=("$DEVENV_BIN")
elif [ -n "${DEVENV_REV}" ]; then
  devenv_cmd=(nix --accept-flake-config run "github:cachix/devenv/${DEVENV_REV}" --)
else
  devenv_cmd=(devenv)
fi

run_devenv() {
  "${devenv_cmd[@]}" --no-tui "$@"
}

print_devenv_version() {
  # Some devenv versions support `--version`, others require the `version`
  # subcommand. Prefer `--version` so older versions still work.
  local out status
  set +e
  out="$(run_devenv --version 2>&1)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    printf '%s\n' "$out"
    return 0
  fi

  # `version` prints to stdout and is stable across versions.
  "${devenv_cmd[@]}" version
}

write_v1() {
  cat >"$tmp_dir/devenv.nix" <<'EOF'
{ pkgs, lib, config, inputs, ... }:

{
  env.GREET = "devenv";

  packages = [ pkgs.git ];

  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    hello
    git --version
  '';

  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
EOF
}

write_v2() {
  cat >"$tmp_dir/devenv.nix" <<'EOF'
{ ... }:

{
  tasks = {
    "demo:show".exec = "echo version-1";
  };
}
EOF
}

write_v1
cp "$root_dir/devenv.yaml" "$tmp_dir/devenv.yaml"
cp "$root_dir/devenv.lock" "$tmp_dir/devenv.lock"

echo "Using devenv: ${devenv_cmd[*]}"
print_devenv_version
echo

echo "== start one tasks evaluation on v1 =="
(cd "$tmp_dir" && run_devenv tasks list >first.out 2>&1) &
devenv_pid=$!

sleep "$delay"
write_v2
echo "rewrote devenv.nix to v2 after ${delay}s while the first devenv process was still running"

wait "$devenv_pid"

echo
echo "== output from the first run =="
sed -n '1,120p' "$tmp_dir/first.out"

echo
echo "== current devenv.nix =="
sed -n '1,40p' "$tmp_dir/devenv.nix"

echo
echo "== second tasks list after the first run finished =="
second_out="$(cd "$tmp_dir" && run_devenv tasks list)"
printf '%s\n' "$second_out"

echo
echo "== after removing only .devenv/task-names.txt =="
rm -f "$tmp_dir/.devenv/task-names.txt"
task_names_out="$(cd "$tmp_dir" && run_devenv tasks list)"
printf '%s\n' "$task_names_out"

echo
echo "== after removing only .devenv/state/tasks.db* =="
rm -f "$tmp_dir/.devenv/state/tasks.db" \
  "$tmp_dir/.devenv/state/tasks.db-shm" \
  "$tmp_dir/.devenv/state/tasks.db-wal"
tasks_db_out="$(cd "$tmp_dir" && run_devenv tasks list)"
printf '%s\n' "$tasks_db_out"

echo
echo "== after removing only .devenv/nix-eval-cache.db* =="
rm -f "$tmp_dir/.devenv/nix-eval-cache.db" \
  "$tmp_dir/.devenv/nix-eval-cache.db-shm" \
  "$tmp_dir/.devenv/nix-eval-cache.db-wal"
eval_cache_out="$(cd "$tmp_dir" && run_devenv tasks list)"
printf '%s\n' "$eval_cache_out"

echo
if grep -Fq "demo:show" <<<"$second_out"; then
  echo "SUMMARY: second tasks list contained demo:show"
else
  echo "SUMMARY: second tasks list DID NOT contain demo:show"
fi

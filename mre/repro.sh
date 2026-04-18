#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d /tmp/devenv-task-cache-mre.XXXXXX)"
delay="${DELAY:-2.0}"
trap 'rm -rf "$tmp_dir"' EXIT

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

echo "== start one tasks evaluation on v1 =="
(cd "$tmp_dir" && devenv tasks list >first.out 2>&1) &
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
(cd "$tmp_dir" && devenv tasks list)

echo
echo "== after removing only .devenv/task-names.txt =="
rm -f "$tmp_dir/.devenv/task-names.txt"
(cd "$tmp_dir" && devenv tasks list)

echo
echo "== after removing only .devenv/state/tasks.db* =="
rm -f "$tmp_dir/.devenv/state/tasks.db" \
  "$tmp_dir/.devenv/state/tasks.db-shm" \
  "$tmp_dir/.devenv/state/tasks.db-wal"
(cd "$tmp_dir" && devenv tasks list)

echo
echo "== after removing only .devenv/nix-eval-cache.db* =="
rm -f "$tmp_dir/.devenv/nix-eval-cache.db" \
  "$tmp_dir/.devenv/nix-eval-cache.db-shm" \
  "$tmp_dir/.devenv/nix-eval-cache.db-wal"
(cd "$tmp_dir" && devenv tasks list)

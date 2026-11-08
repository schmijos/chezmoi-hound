#!/bin/sh
# chezmoi-hound-act commit: a target holding a secret must not be captured.
#
# chezmoi scans what `add` captures, but by default only warns and adds anyway,
# and the act script throws chezmoi's output away - so the warning nobody saw
# was followed by a commit and, one press later, a push. A fake `chezmoi` stands
# in for the real one and behaves like it: it refuses a secret only when asked
# to with `--secrets error`.
set -u

ACT=${ACT:-$(cd "$(dirname "$0")/.." && pwd)/bin/chezmoi-hound-act}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hound-commit-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM
SRC="$WORK/src"
git init -q "$SRC" || exit 1

mkdir -p "$WORK/bin"
cat > "$WORK/bin/chezmoi" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CALLS"
case "$*" in
    *' status'*)
        printf 'MM .token-file\nMM .plain-file\n'
        exit 0 ;;
    *' source-path '*)
        printf '%s/dot_file\n' "$SRC"
        exit 0 ;;
    *' add --secrets error '*token-file*)
        printf 'chezmoi: %s:1: Uncovered a GitHub Personal Access Token\n' "$HOME/.token-file" >&2
        exit 1 ;;
    *' add '*token-file*)
        printf 'chezmoi: %s:1: Uncovered a GitHub Personal Access Token\n' "$HOME/.token-file" >&2
        exit 0 ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/chezmoi"
export CALLS="$WORK/calls" SRC
PATH="$WORK/bin:$PATH"
export PATH

pass=0
fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "chezmoi-hound-act commit, against a fake chezmoi:"
echo

: > "$CALLS"
out=$(sh "$ACT" commit --source "$SRC" --message "test" 2>&1)
echo "$out" | sed 's/^/     /'

if grep ' add ' "$CALLS" | grep -qv -- ' add --secrets error '; then
    no "every add scans for secrets and refuses them (got: $(grep ' add ' "$CALLS"))"
else
    ok "every add scans for secrets and refuses them"
fi
case "$out" in *'captured: .token-file'*) no "a target holding a secret is not captured" ;; *) ok "a target holding a secret is not captured" ;; esac
case "$out" in *'could not capture: .token-file'*'Personal Access Token'*) ok "the refusal names the path and chezmoi's reason" ;; *) no "the refusal names the path and chezmoi's reason" ;; esac
case "$out" in *'captured: .plain-file'*) ok "a target without a secret is still captured" ;; *) no "a target without a secret is still captured" ;; esac

echo
printf '%s ok, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

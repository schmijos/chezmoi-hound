#!/bin/sh
# chezmoi-hound-act ignore: only a literal path may reach .chezmoiignore.
#
# chezmoi reads .chezmoiignore as a template, and every line in it as a glob.
# A drifted path holding `{{ ... }}` would be executed by chezmoi on every check
# after it was written, and one holding `*`, `?` or `[` would stop managing more
# than the file the button was pressed against. Such a path is refused and
# reported, never written; a plain path next to it still goes in.
set -u

ACT=${ACT:-$(cd "$(dirname "$0")/.." && pwd)/bin/chezmoi-hound-act}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hound-ignore-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM
SRC="$WORK/src"
git init -q "$SRC" || exit 1

mkdir -p "$WORK/bin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/chezmoi"
chmod +x "$WORK/bin/chezmoi"
PATH="$WORK/bin:$PATH"
export PATH

pass=0
fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "chezmoi-hound-act ignore, into a scratch source:"
echo

out=$(sh "$ACT" ignore --source "$SRC" \
    --path '.config/plain/file.conf' \
    --path '.config/{{ output "id" }}' \
    --path '.cache/*' \
    --path '.config/a?b' \
    --path '.config/[ab]' \
    --path '!.config/negated' \
    --path '#comment' \
    --path '.config/back\slash' 2>&1); rc=$?
echo "$out" | sed 's/^/     /'
ignorefile="$SRC/.chezmoiignore"

if grep -qxF '.config/plain/file.conf' "$ignorefile" 2>/dev/null; then ok "a plain path is written"; else no "a plain path is written"; fi
for bad in '{{' '*' '?' '[' '!.config' '#comment' 'back\slash'; do
    if grep -qF -- "$bad" "$ignorefile" 2>/dev/null; then
        no "nothing holding '$bad' is written"
    else
        ok "nothing holding '$bad' is written"
    fi
done
case "$out" in *'not a literal path, left alone: .config/{{ output "id" }}'*) ok "a refused path is reported by name" ;; *) no "a refused path is reported by name" ;; esac
[ "$rc" -eq 1 ] && ok "a refused path makes the action exit 1" || no "a refused path makes the action exit 1 (got $rc)"

echo
printf '%s ok, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

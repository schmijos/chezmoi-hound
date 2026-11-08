#!/bin/sh
# chezmoi-hound-check --skel: which chezmoi-managed files differ from the
# defaults a new account is created with (Omarchy ships them in /etc/skel).
#
# A difference from the defaults is customisation, not drift, so it is listed
# and counted on its own and never added to the total the badge shows. A fake
# `chezmoi` names the managed files; $HOME and the skel are scratch trees.
set -u

CHECK=${CHECK:-$(cd "$(dirname "$0")/.." && pwd)/bin/chezmoi-hound-check}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hound-skel-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM
SRC="$WORK/src"
git init -q "$SRC" || exit 1
SKEL="$WORK/skel"
HOME="$WORK/home"
export HOME
mkdir -p "$SKEL/.config" "$HOME/.config"

printf 'same\n'      > "$SKEL/.config/same.conf";       printf 'same\n'      > "$HOME/.config/same.conf"
printf 'default\n'   > "$SKEL/.config/differs.conf";    printf 'mine\n'      > "$HOME/.config/differs.conf"
printf 'default\n'   > "$SKEL/.config/with space.conf"; printf 'mine\n'      > "$HOME/.config/with space.conf"
printf 'default\n'   > "$SKEL/.bashrc";                 printf 'mine\n'      > "$HOME/.bashrc"
printf 'default\n'   > "$SKEL/.config/missing-here.conf"
                                                        printf 'only mine\n' > "$HOME/.config/not-in-skel.conf"
printf 'default\n'   > "$SKEL/.config/unmanaged.conf";  printf 'mine\n'      > "$HOME/.config/unmanaged.conf"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/chezmoi" <<'EOF'
#!/bin/sh
case "$*" in
    *' managed'*)
        printf '%s\n' .bashrc .config/differs.conf .config/missing-here.conf \
            .config/not-in-skel.conf .config/same.conf '.config/with space.conf'
        exit 0 ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/chezmoi"
PATH="$WORK/bin:$PATH"
export PATH

pass=0
fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
has() { printf '%s\n' "$out" | grep -qxF -- "$1"; }

echo "chezmoi-hound-check --skel, against a fake chezmoi:"
echo

out=$(sh "$CHECK" --source "$SRC" --skel "$SKEL" 2>&1)
echo "$out" | sed 's/^/     /'
tab=$(printf '\t')

if has "skel${tab}3"; then ok "three managed files differ from the skel"; else no "three managed files differ from the skel"; fi
if has "skeldir${tab}$SKEL"; then ok "the reading names the skel it compared against"; else no "the reading names the skel it compared against"; fi
for p in .bashrc .config/differs.conf '.config/with space.conf'; do
    if has "skelfile${tab}$p"; then ok "listed: $p"; else no "listed: $p"; fi
done
for p in .config/same.conf .config/not-in-skel.conf .config/missing-here.conf .config/unmanaged.conf; do
    if printf '%s\n' "$out" | grep -qF -- "$p"; then no "not listed: $p"; else ok "not listed: $p"; fi
done
if has "total${tab}0"; then ok "skel differences are not added to the total"; else no "skel differences are not added to the total"; fi

out=$(sh "$CHECK" --source "$SRC" --skel "" 2>&1)
if printf '%s\n' "$out" | grep -q '^skel'; then no "an empty --skel turns the comparison off"; else ok "an empty --skel turns the comparison off"; fi

out=$(sh "$CHECK" --source "$SRC" --skel "$WORK/nowhere" 2>&1); rc=$?
if printf '%s\n' "$out" | grep -q '^skel'; then no "a skel that is not there is not compared"; else ok "a skel that is not there is not compared"; fi
[ "$rc" -eq 0 ] && ok "a skel that is not there does not fail the reading" || no "a skel that is not there does not fail the reading (got $rc)"

out=$(sh "$CHECK" --source "$SRC" --skel "$SKEL" --render 2>&1)
case "$out" in *"Differs from $SKEL (3)"*) ok "the rendered reading has a skel section" ;; *) no "the rendered reading has a skel section" ;; esac
case "$out" in *'-default'*'+mine'*) ok "the rendered reading shows the diff against the skel" ;; *) no "the rendered reading shows the diff against the skel" ;; esac

echo
printf '%s ok, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

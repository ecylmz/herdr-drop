#!/bin/sh
# Installs the herdr-drop plugin and binds it to a free key.
#
#   curl -fsSL https://raw.githubusercontent.com/ecylmz/herdr-drop/main/install.sh | sh
#
# uninstall.sh is a symlink to this file and undoes both steps. Over a pipe
# there is no argv[0] to read, so that route needs the flag:
#
#   curl -fsSL https://raw.githubusercontent.com/ecylmz/herdr-drop/main/install.sh | sh -s -- --uninstall
set -eu

REPO=ecylmz/herdr-drop
PLUGIN=herdr-drop
ACTION=herdr-drop.upload
CONFIG=${HERDR_CONFIG:-$HOME/.config/herdr/config.toml}
BEGIN="# herdr-drop: added by install.sh"
END="# herdr-drop: end"
# Tried in order; the first one nothing else claims wins.
CANDIDATE_KEYS="prefix+u prefix+shift+u prefix+b prefix+shift+b prefix+shift+y"

die() { echo "herdr-drop: $*" >&2; exit 1; }
say() { echo "herdr-drop: $*"; }

mode() {
    case "${0##*/}" in uninstall*) echo uninstall; return ;; esac
    for arg in "$@"; do
        case "$arg" in --uninstall | -u) echo uninstall; return ;; esac
    done
    echo install
}

require_herdr() {
    command -v herdr >/dev/null 2>&1 || die "herdr is not on PATH, see https://herdr.dev"
    command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH"
    version=$(herdr --version 2>/dev/null | awk '{print $NF}')
    case "$version" in
        0.[0-8].* | 0.[0-8]) die "needs Herdr 0.9.0 or newer, found $version" ;;
    esac
}

# Every key Herdr reserves by default, plus whatever this config already binds.
key_is_taken() {
    { herdr --default-config 2>/dev/null; cat "$CONFIG" 2>/dev/null; } |
        grep -q "\"$1\""
}

reload() {
    herdr server reload-config >/dev/null 2>&1 ||
        say "could not reload the config; restart Herdr to pick up the change"
}

bind_key() {
    if grep -q "$ACTION" "$CONFIG" 2>/dev/null; then
        say "already bound to a key in $CONFIG, leaving it alone"
        return
    fi
    key=""
    for candidate in $CANDIDATE_KEYS; do
        if ! key_is_taken "$candidate"; then
            key=$candidate
            break
        fi
    done
    if [ -z "$key" ]; then
        say "no free key found; bind $ACTION yourself in $CONFIG"
        return
    fi

    mkdir -p "$(dirname "$CONFIG")"
    [ -f "$CONFIG" ] && cp "$CONFIG" "$CONFIG.herdr-drop.bak"
    # A [[keys.command]] table opens its own section, so appending is safe
    # wherever the file currently ends.
    cat >>"$CONFIG" <<EOF

$BEGIN
[[keys.command]]
key = "$key"
type = "plugin_action"
command = "$ACTION"
description = "Upload dropped file"
$END
EOF
    say "bound to $key"
}

unbind_key() {
    [ -f "$CONFIG" ] || return 0
    grep -q "$BEGIN" "$CONFIG" || {
        say "no binding added by this script in $CONFIG; leaving it alone"
        return 0
    }
    cp "$CONFIG" "$CONFIG.herdr-drop.bak"
    awk -v b="$BEGIN" -v e="$END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip
    ' "$CONFIG.herdr-drop.bak" >"$CONFIG"
    say "removed the key binding (previous config kept at $CONFIG.herdr-drop.bak)"
}

require_herdr

case $(mode "$@") in
    install)
        say "installing from $REPO"
        herdr plugin install "$REPO" -y
        bind_key
        reload
        say "done. Drop a file on a pane, then press the key above, or:"
        say "  herdr plugin action invoke $ACTION"
        ;;
    uninstall)
        unbind_key
        herdr plugin uninstall "$PLUGIN" 2>/dev/null ||
            herdr plugin unlink "$PLUGIN" 2>/dev/null ||
            say "plugin was not installed"
        reload
        say "removed. Nothing else was touched. The plugin keeps no state."
        ;;
esac

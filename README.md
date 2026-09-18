# herdr-drop

Drag a file onto a [Herdr](https://herdr.dev) pane, press a key, and it lands in
that pane's current directory — on the machine the pane is on. An ssh session
needs nothing installed at the other end.

<img src="docs/progress.svg" alt="The upload popup: a progress bar during transfer, a verified result after" width="600">

Your terminal already pastes the dropped file's path into the pane. This plugin
reads that path, clears the line, and streams the file through the same pty into
`base64 -d` on the other side. No extra ssh connection, no agent on the server,
no replacement for `ssh`.

## Install

Requires Herdr ≥ 0.9.0 and Python 3. Linux and macOS.

```bash
curl -fsSL https://raw.githubusercontent.com/ecylmz/herdr-drop/main/install.sh | sh
```

That installs the plugin and binds it to the first free key it finds —
`prefix+u` on a stock config. It never overwrites an existing binding,
and it backs up `config.toml` before touching it.

Prefer to see what runs first? `curl -fsSL …/install.sh | less`, or do it by
hand:

```bash
herdr plugin install ecylmz/herdr-drop
```

There is nothing to build: the plugin is one Python script.

<details>
<summary>Binding the key yourself</summary>

Add this to `~/.config/herdr/config.toml` and run `herdr server reload-config`:

```toml
[[keys.command]]
key = "prefix+u"
type = "plugin_action"
command = "herdr-drop.upload"
description = "Upload dropped file"
```

Check the key is free first — `herdr --default-config` lists Herdr's own
bindings. `prefix+d` is detach, and `prefix+shift+d` is close_workspace, so the
mnemonic key for a drop is only yours to take if you have moved that one.

</details>

<details>
<summary>From source, for development</summary>

```bash
git clone https://github.com/ecylmz/herdr-drop
cd herdr-drop
herdr plugin link "$PWD"
```

`./herdr-drop --test` runs the self-checks. A linked plugin cannot be installed
over — `herdr plugin unlink herdr-drop` first.

</details>

## Use

1. Drag the file onto the pane. Your terminal pastes its path at the prompt.
2. Press the key. A popup shows the transfer; the prompt line is cleared for you.
3. The file is in that pane's working directory.

Works the same whether the pane is a local shell, an `ssh` session, or a
`herdr machine` pane. The remote side needs only `base64`, `cksum` and `stty` —
POSIX tools that ship with every Linux and macOS.

The pane is left with one line of evidence, which is also what does the work:

```
emrecan@research:/srv/app$ stty -echo; base64 -d > mid.bin; stty echo; cksum mid.bin
3803138497 3000000 mid.bin
```

## Verification

The ✓ is not optimistic. When the last chunk has been handed over, the plugin
waits for that `cksum` line and compares it with the local `cksum` of the file —
POSIX `cksum` gives the same CRC on Linux and macOS. Only a match prints ✓.

Anything else is a failure, with both checksums shown:

```
  ✗ not verified · local 3945516409 200000 · remote no answer
  the file may be truncated or corrupt: big.bin
```

The wait has a budget of `max(30 s, size / 50 KB/s)`, and the popup counts up to
it while the pty buffer drains.

## Limits

Everything travels through the terminal, so throughput is the pty's, around
200 KB/s. That is fine for a config file, a patch, a certificate, a small
archive. **Above ~5 MB, use `scp`** — this plugin is for the file you are
holding, not for a backup.

The progress bar counts bytes handed to Herdr, which can run ahead of the pty by
a few hundred KB. The checksum at the end is the part that tells the truth.

Binary-safe: the file is base64-encoded before it enters the terminal, so
control characters never reach the remote line discipline.

<details>
<summary>Why a key and not the drop itself</summary>

Herdr has no hook for a paste or a drop, and its link handlers only match
http(s) URLs — a dropped path never becomes a clickable link. So the drop
puts the path on the prompt, and the key turns it into a transfer.

</details>

## Update

Herdr has no `plugin update`; reinstalling refreshes the managed checkout.
Rerun the installer, or:

```bash
herdr plugin install ecylmz/herdr-drop
```

Your key binding is left in place. For a linked checkout, `git pull` instead.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ecylmz/herdr-drop/main/install.sh | sh -s -- --uninstall
```

From a checkout, `./uninstall.sh` does the same — it is a symlink to
`install.sh`, which reads its own name. (Over a pipe there is no name to read,
hence the flag.)

This removes the plugin and the key binding the installer added, and nothing
else. The plugin keeps no state of its own.

## License

MIT

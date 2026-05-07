# TAFFISH shell completion

This directory contains static shell completion scripts for `taf` and
`taffish`.

## Bash

```sh
source /path/to/taffish/completion/bash/taf
source /path/to/taffish/completion/bash/taffish
```

For a system install, copy them to a directory loaded by bash completion,
for example:

```sh
install -m 0644 completion/bash/taf /etc/bash_completion.d/taf
install -m 0644 completion/bash/taffish /etc/bash_completion.d/taffish
```

## Zsh

Add the zsh completion directory to `fpath` before `compinit`:

```sh
fpath=(/path/to/taffish/completion/zsh $fpath)
autoload -Uz compinit
compinit
```

## Fish

```sh
mkdir -p ~/.config/fish/completions
cp completion/fish/taf.fish ~/.config/fish/completions/
cp completion/fish/taffish.fish ~/.config/fish/completions/
```

These scripts are intentionally conservative and avoid network calls.

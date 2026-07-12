# TAFFISH shell completion

This directory contains static shell completion scripts for `taf` and
`taffish`. The installer copies these files into
`$TAFFISH_HOME/share/completions`, but it does not edit shell startup files.

Default installed roots are:

```text
user   = ~/.local/share/taffish/share/completions
system = /opt/taffish/share/completions
```

## Bash

```sh
source ~/.local/share/taffish/share/completions/bash/taf
source ~/.local/share/taffish/share/completions/bash/taffish
```

For a system install with `bash-completion`, copy the installed files to a
directory loaded by Bash, for example:

```sh
sudo install -m 0644 /opt/taffish/share/completions/bash/taf /etc/bash_completion.d/taf
sudo install -m 0644 /opt/taffish/share/completions/bash/taffish /etc/bash_completion.d/taffish
```

Alternatively, source both installed files from the global interactive Bash
startup file:

```sh
source /opt/taffish/share/completions/bash/taf
source /opt/taffish/share/completions/bash/taffish
```

Common global files are `/etc/bash.bashrc` on Debian-family systems and
`/etc/bashrc` on Red Hat-family systems.

## Zsh

Add the zsh completion directory to `fpath` before `compinit`:

```sh
fpath=(~/.local/share/taffish/share/completions/zsh $fpath)
autoload -Uz compinit
compinit
```

For a system install, add `/opt/taffish/share/completions/zsh` to `fpath`
before the site's `compinit`, or copy `_taf` and `_taffish` into the local
system `site-functions` directory. Common global startup files include
`/etc/zshrc` and `/etc/zsh/zshrc`; site-function paths vary by operating
system and package manager.

## Fish

```sh
mkdir -p ~/.config/fish/completions
cp ~/.local/share/taffish/share/completions/fish/taf.fish ~/.config/fish/completions/
cp ~/.local/share/taffish/share/completions/fish/taffish.fish ~/.config/fish/completions/
```

For a system install, copy the two files into a Fish vendor completion
directory such as `/usr/share/fish/vendor_completions.d` or
`/usr/local/share/fish/vendor_completions.d`. Use
`fish -c 'string join \n $fish_complete_path'` to inspect the directories on
the target machine before choosing one.

These scripts are intentionally conservative and avoid network calls.

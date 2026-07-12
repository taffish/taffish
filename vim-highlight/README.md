# TAFFISH Vim syntax files

This directory contains file detection and syntax highlighting for `.taf`
files. The TAFFISH installer copies these files into
`$TAFFISH_HOME/share/vim`, but it does not edit Vim or Neovim configuration.

Default installed roots are:

```text
user   = ~/.local/share/taffish/share/vim
system = /opt/taffish/share/vim
```

## User installation

Vim:

```sh
mkdir -p ~/.vim/syntax ~/.vim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.vim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.vim/ftdetect/
```

Neovim:

```sh
mkdir -p ~/.config/nvim/syntax ~/.config/nvim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.config/nvim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.config/nvim/ftdetect/
```

## System installation

An administrator can copy `syntax/taf.vim` and `ftdetect/taf.vim` into the
site-wide Vim runtime directory, or add the installed root to the global Vim
configuration:

```vim
set runtimepath+=/opt/taffish/share/vim
```

Common global Vim configuration files include `/etc/vim/vimrc.local` and
`/etc/vimrc`. Common site runtimes include `/usr/share/vim/vimfiles` and
`/usr/local/share/vim/vimfiles`. Neovim commonly uses an XDG configuration
under `/etc/xdg/nvim`. These paths vary by operating system, so inspect the
target editor's `runtimepath` before installing files globally.

After activation, opening a `.taf` file should set `filetype=taf`.

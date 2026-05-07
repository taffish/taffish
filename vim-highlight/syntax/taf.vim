if exists("b:current_syntax")
  finish
endif

syntax case match

" Comments.
syntax match TafComment "#.*$" contains=NONE

" ::arg::
syntax match TafVar "::\([^:]\|:[^:]\)*::"

" Top-level or block tags: <shell>, <container:...>, <taf-app:...>, <taffish>.
syntax match TafTag "^\s*<.\{-}>" contains=TafTagDelimiter,TafTagName,TafVar
syntax match TafTagDelimiter "[<>]" contained
syntax match TafTagName "\v(shell|container|docker|podman|apptainer|taf-app|taffish)" contained

" [[taf: ...]]
syntax match TafCmd "\[\[taf:\_.\{-}\]\]" contains=TafVar

" ARGS / RUN block markers.
syntax match TafArgsLine "^\s*ARGS\s*$"
syntax match TafRunLine "^\s*RUN\s*$"

highlight default TafVar ctermfg=Magenta guifg=#C678DD
highlight default TafCmd ctermfg=Cyan guifg=#56B6C2
highlight default TafComment ctermfg=DarkGray guifg=#7F848E
highlight default TafTag ctermfg=Blue guifg=#61AFEF
highlight default TafTagDelimiter ctermfg=Blue guifg=#61AFEF
highlight default TafTagName ctermfg=Blue guifg=#61AFEF gui=bold cterm=bold
highlight default TafArgsLine ctermfg=Yellow guifg=#E5C07B gui=bold cterm=bold
highlight default TafRunLine ctermfg=Green guifg=#98C379 gui=bold cterm=bold

let b:current_syntax = "taf"

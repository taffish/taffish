" 定义一个语法组，这里命名为 MyDSLVar，Args 优先替换，所有不包含 $$Cmd$$
syntax match MyDSLVar "::\([^:]\|:[^:]\)*::"
highlight link MyDSLVar Identifier

" 定义一个语法组，这里命名为 MyDSLCmd
syntax match MyDSLCmd "\$\$.*\$\$" contains=MyDSLVar
highlight MyDSLCmd ctermfg=Green guifg=Green

" 定义注释的匹配规则
syntax match MyDSLComment "#.*$" contains=NONE
highlight link MyDSLComment Comment

" 定义 +TOOL: 开头的行
syntax match MyDSLToolLine "^\s*+TOOL:\(\S*\)\(\s\|$\)\@=" contains=MyDSLComment
highlight MyDSLToolLine ctermfg=Brown guifg=Brown

" 定义 +FLOW: 开头的行
syntax match MyDSLFlowLine "^\s*+FLOW:\(\S*\)\(\s\|$\)\@=" contains=MyDSLComment
highlight MyDSLFlowLine ctermfg=Brown guifg=Brown

" 定义 ARGS 开头的行
syntax match MyDSLArgsLine "^\s*ARGS\(\S*\)\(\s\|$\)\@=" contains=MyDSLComment
highlight MyDSLArgsLine ctermfg=Red guifg=Red

" 定义 RUN 开头的行
syntax match MyDSLRunLine "^\s*RUN\(\S*\)\(\s\|$\)\@=" contains=MyDSLComment
highlight MyDSLRunLine ctermfg=Yellow guifg=Yellow

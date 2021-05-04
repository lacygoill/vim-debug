vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import {
    Catch,
    IsVim9,
} from 'lg.vim'

import WinScratch from 'lg/window.vim'

var all_values: bool

# Interface {{{1
def debug#capture#setup(arg_all_values: bool): string #{{{2
    all_values = arg_all_values
    &opfunc = expand('<SID>') .. 'Variable'
    return 'g@l'
enddef

def debug#capture#dump() #{{{2
    var vars: list<string> = getcompletion('d_*', 'var')
    if empty(vars)
        echo 'there are no debugging variables'
        return
    endif
    vars->map((_, v: string): string =>
                v .. ' = ' .. eval('g:' .. v)->string())
    try
        WinScratch(vars)
    catch /^Vim\%((\a\+)\)\=:E994:/
        Catch()
        return
    endtry
    wincmd P
    if !&l:pvw
        return
    endif
    nno <buffer><nowait> DD <cmd>call <sid>UnletVariableUnderCursor()<cr>
enddef
# }}}1
# Core {{{1
def Variable(_) #{{{2
    var pat: string =
        # this part is optional because, in Vim9 script, there might be no assignment command
           '\%(\%(let\|var\|const\=\)\s\+\)\='
        .. '\([bwtglsav]:\)\=\(\h\w*\)\s*[+-.*]\{,2}[=:].*'
    #                                                 ^
    #                                                 for Vim9 variables which are only declared, not assigned
    if getline('.')->match(pat) == -1
        echo 'No variable to capture on this line'
        return
    endif
    copy .
    var cmd: string = IsVim9() ? '' : 'let '
    var rep: string = all_values
        ? cmd .. 'g:d_\2 = get(g:, ''d_\2'', []) + [deepcopy(\1\2)]'
        : cmd .. 'g:d_\2 = deepcopy(\1\2)'
    exe 'sil keepj keepp s/' .. pat .. '/' .. rep .. '/e'
enddef
#}}}1
# Utilities {{{1
def UnletVariableUnderCursor() #{{{2
    exe 'unlet! g:' .. getline('.')->matchstr('^d_\S\+')
    keepj d _
    sil update
    echom 'the variable has been removed'
enddef


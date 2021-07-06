vim9script noclear

import Catch from 'lg.vim'

import WinScratch from 'lg/window.vim'

var all_values: bool

# Interface {{{1
def debug#capture#setup(arg_all_values: bool): string #{{{2
    all_values = arg_all_values
    &operatorfunc = expand('<SID>') .. 'Variable'
    return 'g@l'
enddef

def debug#capture#dump() #{{{2
    var vars: list<string> = getcompletion('d_*', 'var')
    if empty(vars)
        echo 'there are no debugging variables'
        return
    endif
    vars->map((_, v: string) =>
                v .. ' = ' .. eval('g:' .. v)->string())
    try
        WinScratch(vars)
    catch /^Vim\%((\a\+)\)\=:E994:/
        Catch()
        return
    endtry
    wincmd P
    if !&l:previewwindow
        return
    endif
    nnoremap <buffer><nowait> DD <Cmd>call <SID>UnletVariableUnderCursor()<CR>
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
    var rep: string = all_values
        ? 'g:d_\2 = get(g:, ''d_\2'', []) + [deepcopy(\1\2)]'
        : 'g:d_\2 = deepcopy(\1\2)'
    execute 'silent keepjumps keeppatterns substitute/' .. pat .. '/' .. rep .. '/e'
enddef
#}}}1
# Utilities {{{1
def UnletVariableUnderCursor() #{{{2
    execute 'unlet! g:' .. getline('.')->matchstr('^d_\S\+')
    keepjumps delete _
    silent update
    echomsg 'the variable has been removed'
enddef


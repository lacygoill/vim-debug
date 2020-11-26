import {Catch, IsVim9} from 'lg.vim'
import WinScratch from 'lg/window.vim'

" Interface {{{1
fu debug#capture#setup(verbose) abort "{{{2
    let s:verbose = a:verbose
    let &opfunc = 'debug#capture#variable'
    return 'g@l'
endfu

fu debug#capture#variable(_) abort "{{{2
    let pat =
        "\ this part is optional because, in Vim9 script, there might be no assignment command
        \    '\%(\%(let\|var\|const\=\)\s\+\)\='
        \ .. '\([bwtglsav]:\)\=\(\h\w*\)\s*[+-.*]\{,2}[=:].*'
    "                                                   ^
    "                                                   for Vim9 variables which are only declared, not assigned
    if getline('.')->match(pat) == -1
        echo 'No variable to capture on this line'
        return
    endif
    t.
    let cmd = s:IsVim9() ? '' : 'let '
    let rep = s:verbose
        \ ? cmd .. 'g:d_\2 = get(g:, ''d_\2'', []) + [deepcopy(\1\2)]'
        \ : cmd .. 'g:d_\2 = deepcopy(\1\2)'
    sil exe 'keepj keepp s/' .. pat .. '/' .. rep .. '/e'
endfu

fu debug#capture#dump() abort "{{{2
    let vars = getcompletion('d_*', 'var')
    if empty(vars) | echo 'there are no debugging variables' | return | endif
    call map(vars, {_, v -> v .. ' = ' .. string(g:{v})})
    try
        call s:WinScratch(vars)
    catch /^Vim\%((\a\+)\)\=:E994:/
        return s:Catch()
    endtry
    wincmd P
    if !&l:pvw | return | endif
    nno <buffer><nowait> DD <cmd>call <sid>unlet_variable_under_cursor()<cr>
endfu
" }}}1
" Utilities {{{1
fu s:unlet_variable_under_cursor() abort "{{{2
    exe 'unlet! g:' .. getline('.')->matchstr('^d_\S\+')
    keepj d_ | sil update
    echom 'the variable has been removed'
endfu


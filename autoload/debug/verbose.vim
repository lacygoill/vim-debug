if exists('g:autoloaded_debug#verbose')
    finish
endif
let g:autoloaded_debug#verbose = 1

import Catch from 'lg.vim'
const s:OPTIONS_DOC = readfile($VIMRUNTIME .. '/doc/options.txt')

" Interface {{{1
fu debug#verbose#option(opt) abort "{{{2
    try
        " Why not just `a-z`?  To support terminal options.
        let opt = execute('set ' .. a:opt .. '?')->matchstr('[a-z0-9<>_-]\+')
    " many errors are possible when you write nonsense (E518, E846, E488, ...)
    catch
        return s:Catch()
    endtry
    " necessary for a reset boolean option (like 'paste')
    let opt = substitute(opt, '^no', '', '')

    let msg = s:get_current_value(opt)
    if exists('b:orig_' .. opt)
        let msg += s:get_original_value(opt)
    endif

    call s:display(msg)
endfu
"}}}1
" Core {{{1
fu s:get_current_value(opt) abort "{{{2
    let vlocal = execute('verb setl ' .. a:opt .. '?')->matchstr('\_s*\zs\S.*')
    let vglobal = execute('verb setg ' .. a:opt .. '?')->matchstr('\_s*\zs\S.*')
    if a:opt[:1] is# 't_' || a:opt[0] .. a:opt[-1:-1] is# '<>'
        let type = 'terminal'
    else
        let type = join(s:OPTIONS_DOC, "\n")
            \ ->matchstr('\n''' .. a:opt .. '''\s\+\%(''[a-z]\{2,}''\s\+\)\=\%(boolean\|number\|string\)'
            \ .. '\_.\{-}\zs\%(global\ze\n\|\%(global or \)\=local to \%(buffer\|window\)\)')
    endif
    if type =~# '^\%(global\|terminal\)$'
        let msg = [type .. ':  ' .. vglobal]
    else
        let msg =<< trim END
            local:   %s
            global:  %s
            type:    %s
        END
        call map(msg, {i, v -> substitute(v, '%s', escape([vlocal, vglobal, type][i], '&\'), 'g')})
    endif
    return msg
endfu

fu s:get_original_value(opt) abort "{{{2
    let curval = execute('setl ' .. a:opt .. '?')->matchstr('=\zs.*')
    let origval = b:orig_{a:opt}
    let is_boolean = empty(curval)
    if is_boolean
        let curval = execute('setl ' .. a:opt .. '?')[1:]
        let origval = s:bool2name(origval, curval)
    endif
    if curval isnot# origval
        return ['original value: ' .. origval]
    endif
    return []
endfu

fu s:display(msg) abort "{{{2
    let msg = join(a:msg, "\n\n")
    " a horizontal rule makes the output easier to read when we execute several `:Vo` consecutively
    let horizontal_rule = substitute(msg, '.*\n', '', '')
    let horizontal_rule = substitute(horizontal_rule, '^\t', '\=repeat(" ", &l:ts)', '')
    let horizontal_rule = substitute(horizontal_rule, '.', '-', 'g')
    echo msg .. (msg =~# "\n" ? "\n" .. horizontal_rule : '')
endfu
"}}}1
" Util {{{1
fu s:bool2name(origval, curval) abort "{{{2
    let is_set = a:curval !~# '^no'
    if is_set
        return a:origval ? a:curval : 'no' .. a:curval
    else
        return a:origval ? substitute(a:curval, '^no', '', '') : a:curval
    endif
endfu


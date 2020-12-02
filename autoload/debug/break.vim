if exists('g:autoloaded_debug#break')
    finish
endif
let g:autoloaded_debug#break = 1

import FuncComplete from 'lg.vim'

" We can't use `getcompletion('breakadd ', 'cmdline')`.{{{
"
" Because `:breakadd` – contrary to `:profile` – doesn't provide any completion.
"}}}
const s:ADD_ARGUMENTS =<< trim END
    expr
    file
    func
END
const s:DEL_ARGUMENTS =<< trim END
    *
    file
    func
END

fu debug#break#completion(arglead, cmdline, _p) abort
    if a:cmdline =~# '^\CBreak\%(add\|del\) func\s\+\%(\d\+\s\+\)\='
    \ && a:cmdline !~# '^\CBreak\%(add\|del\) func\s\+\%(\%(\d\+\s\+\)\=\)\@>\S\+\s\+'
        return s:FuncComplete(a:arglead, '', 0)
    elseif a:cmdline =~# '^\CBreak\%(add\|del\) file\s\+'
    \ && a:cmdline !~# '^\CBreak\%(add\|del\) file\s\+\S\+\s\+'
        if a:arglead =~# '$\h\w*$'
            return getcompletion(a:arglead[1:], 'environment')
                \ ->map({_, v -> '$' .. v})
        else
            return getcompletion(a:arglead, 'file')
        endif
    elseif a:cmdline =~# '^\CBreakadd \%(' .. join(s:ADD_ARGUMENTS, '\|') .. '\)'
    \ || a:cmdline =~# '^\CBreakdel \%('
    \     .. mapnew(s:DEL_ARGUMENTS, {_, v -> escape(v, '*')})
    \     ->join('\|') .. '\)'
        return []
    else
        return copy(a:cmdline =~# '^\CBreakadd\s' ? s:ADD_ARGUMENTS : s:DEL_ARGUMENTS)
            \ ->filter({_, v -> stridx(v, a:arglead) == 0})
    endif
    return []
endfu

fu debug#break#wrapper(suffix, arguments) abort
    try
        exe 'break' .. a:suffix .. ' ' .. a:arguments
    catch
        echohl ErrorMsg
        echom v:exception
        echohl NONE
    endtry
endfu


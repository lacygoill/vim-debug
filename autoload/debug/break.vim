vim9script noclear

import FuncComplete from 'lg.vim'

# We can't use `getcompletion('breakadd ', 'cmdline')`.{{{
#
# Because `:breakadd` – contrary to `:profile` – doesn't provide any completion.
#}}}
const ADD_ARGUMENTS: list<string> =<< trim END
    expr
    file
    func
END
const DEL_ARGUMENTS: list<string> =<< trim END
    *
    file
    func
END

def debug#break#completion(
    arglead: string,
    cmdline: string,
    _
): list<string>

    if cmdline =~ '^\CBreak\%(add\|del\) func\s\+\%(\d\+\s\+\)\='
    && cmdline !~ '^\CBreak\%(add\|del\) func\s\+\%(\%(\d\+\s\+\)\=\)\@>\S\+\s\+'
        return FuncComplete(arglead, '', 0)
    elseif cmdline =~ '^\CBreak\%(add\|del\) file\s\+'
        && cmdline !~ '^\CBreak\%(add\|del\) file\s\+\S\+\s\+'
        if arglead =~ '$\h\w*$'
            return getcompletion(arglead[1 :], 'environment')
                ->map((_, v: string) => '$' .. v)
        else
            return getcompletion(arglead, 'file')
        endif
    elseif cmdline =~ '^\CBreakadd \%(' .. ADD_ARGUMENTS->join('\|') .. '\)'
        || cmdline =~ '^\CBreakdel \%('
            .. mapnew(DEL_ARGUMENTS, (_, v: string) => escape(v, '*'))
                ->join('\|')
            .. '\)'
        return []
    else
        return copy(cmdline =~ '^\CBreakadd\s' ? ADD_ARGUMENTS : DEL_ARGUMENTS)
            ->filter((_, v: string): bool => stridx(v, arglead) == 0)
    endif
enddef

def debug#break#wrapper(suffix: string, args: string)
    try
        g:debugging = true
        execute 'break' .. suffix .. ' ' .. args
    catch
        g:debugging = false | redrawtabline
        echohl ErrorMsg
        echomsg v:exception
        echohl NONE
    endtry
    if suffix == 'del'
        g:debugging = false | redrawtabline
    endif
enddef


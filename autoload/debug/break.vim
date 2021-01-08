vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import FuncComplete from 'lg.vim'

# We can't use `getcompletion('breakadd ', 'cmdline')`.{{{
#
# Because `:breakadd` – contrary to `:profile` – doesn't provide any completion.
#}}}
const ADD_ARGUMENTS =<< trim END
    expr
    file
    func
END
const DEL_ARGUMENTS =<< trim END
    *
    file
    func
END

def debug#break#completion(arglead: string, cmdline: string, _p: any): list<string>
    if cmdline =~ '^\CBreak\%(add\|del\) func\s\+\%(\d\+\s\+\)\='
    && cmdline !~ '^\CBreak\%(add\|del\) func\s\+\%(\%(\d\+\s\+\)\=\)\@>\S\+\s\+'
        return FuncComplete(arglead, '', 0)
    elseif cmdline =~ '^\CBreak\%(add\|del\) file\s\+'
        && cmdline !~ '^\CBreak\%(add\|del\) file\s\+\S\+\s\+'
        if arglead =~ '$\h\w*$'
            return getcompletion(arglead[1 :], 'environment')
                ->map((_, v) => '$' .. v)
        else
            return getcompletion(arglead, 'file')
        endif
    elseif cmdline =~ '^\CBreakadd \%(' .. join(ADD_ARGUMENTS, '\|') .. '\)'
        || cmdline =~ '^\CBreakdel \%('
        .. mapnew(DEL_ARGUMENTS, (_, v) => escape(v, '*'))
        ->join('\|') .. '\)'
        return []
    else
        return copy(cmdline =~ '^\CBreakadd\s' ? ADD_ARGUMENTS : DEL_ARGUMENTS)
            ->filter((_, v) => stridx(v, arglead) == 0)
    endif
    return []
enddef

def debug#break#wrapper(suffix: string, args: string)
    try
        exe 'break' .. suffix .. ' ' .. args
    catch
        echohl ErrorMsg
        echom v:exception
        echohl NONE
    endtry
enddef


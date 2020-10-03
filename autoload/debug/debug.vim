if exists('g:autoloaded_debug#debug')
    finish
endif
let g:autoloaded_debug#debug = 1

import FuncComplete from 'lg.vim'

fu debug#debug#completion(arglead, cmdline, _p) abort
    return getcompletion('', 'command')
        \ ->copy()
        \ ->filter({_, v -> stridx(v, a:arglead) == 0})
        \ + s:FuncComplete(a:arglead, '', 0)
endfu

fu debug#debug#wrapper(cmd) abort
    try
        ToggleEditingCommands 0
        au! my_granular_undo
        exe 'debug ' .. a:cmd
    catch
        return s:Catch()
    finally
        unlet! g:autoloaded_readline
        ru autoload/readline.vim
        ToggleEditingCommands 1
    endtry
endfu


vim9script noclear

import {
    Catch,
    FuncComplete,
} from 'lg.vim'

def debug#debug#completion(arglead: string, _, _): list<string>
    return getcompletion('', 'command')
        ->copy()
        ->filter((_, v: string): bool => stridx(v, arglead) == 0)
        + FuncComplete(arglead, '', 0)
enddef

def debug#debug#wrapper(cmd: string)
    try
        g:debugging = true
        execute 'debug ' .. cmd
    catch
        Catch()
        return
    finally
        g:debugging = false | redrawtabline
    endtry
enddef


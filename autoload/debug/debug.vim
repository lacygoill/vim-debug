vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

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
        ToggleEditingCommands 0
        if exists('#MyGranularUndo')
            au! MyGranularUndo
        endif
        exe 'debug ' .. cmd
    catch
        Catch()
        return
    finally
        ToggleEditingCommands 1
    endtry
enddef


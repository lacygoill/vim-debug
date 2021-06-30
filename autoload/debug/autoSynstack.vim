vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

const MINIVIMRC: string = (getenv('XDG_RUNTIME_VIM') ?? '/tmp') .. '/debug_syntax_plugin.vim'

def debug#autoSynstack#main() #{{{1
    augroup DebugSyntax | autocmd!
        autocmd CursorMoved <buffer> EchoSynstack()
        autocmd BufEnter <buffer> execute 'source ' .. MINIVIMRC
    augroup END

    # open a new file to write our mini syntax plugin
    execute 'new ' .. MINIVIMRC
    'syntax clear'->setline(1)
enddef

def EchoSynstack()
    echo synstack('.', col('.'))
        ->mapnew((_, v: number): string => synIDattr(v, 'name'))
        ->reverse()
        ->join()
enddef


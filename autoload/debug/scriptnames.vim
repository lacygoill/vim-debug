vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#scriptnames#main()
    var lines: list<string> = execute('scriptnames')->split('\n')
    setqflist([], ' ', {
        lines: lines,
        efm: '%m: %f',
        title: ':Scriptnames',
        quickfixtextfunc: (_) => [],
    })
    doautocmd <nomodeline> QuickFixCmdPost cwindow
enddef


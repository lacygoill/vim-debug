vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#scriptnames#main()
    var lines = execute('scriptnames')->split('\n')
    setqflist([], ' ', {
        lines: lines,
        efm: '%m: %f',
        title: ':Scriptnames',
        quickfixtextfunc: () => [],
        })
    do <nomodeline> QuickFixCmdPost cwindow
enddef


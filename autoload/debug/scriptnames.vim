vim9script noclear

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


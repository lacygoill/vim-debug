fu debug#scriptnames#main() abort
    let lines = execute('scriptnames')->split('\n')
    call setqflist([], ' ', {
        \ 'lines': lines,
        \ 'efm': '%m: %f',
        \ 'title': ':Scriptnames',
        \ 'quickfixtextfunc': {-> []},
        \ })
    do <nomodeline> QuickFixCmdPost cwindow
endfu


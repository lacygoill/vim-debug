if exists('g:autoloaded_debug#scriptnames')
    finish
endif
let g:autoloaded_debug#scriptnames = 1

" Init {{{1

fu s:SID() abort
    return expand('<sfile>')->matchstr('<SNR>\zs\d\+\ze_SID$')->str2nr()
endfu
const s:SID = s:SID()->printf('<SNR>%d_')
delfu s:SID

fu debug#scriptnames#main() abort "{{{1
    let lines = execute('scriptnames')->split('\n')
    call setqflist([], ' ', {
        \ 'lines': lines,
        \ 'efm': '%m: %f',
        \ 'title': ':Scriptnames',
        \ 'quickfixtextfunc': s:SID ..'no_qftf',
        \ })
    do <nomodeline> QuickFixCmdPost cwindow
endfu

fu s:no_qftf(_) abort
    return []
endfu


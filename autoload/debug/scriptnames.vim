fu debug#scriptnames#main() abort "{{{1
    let items = s:get_scriptnames()
    call setqflist([], ' ', {'items': items, 'title': ':Scriptnames'})
    do <nomodeline> QuickFixCmdPost copen
endfu

fu s:get_scriptnames() abort "{{{1
    let lines = execute('scriptnames')->split('\n')
    let items = []
    for line in lines
        if line =~# ':'
            call add(items, {
            \ 'text': matchstr(line, '\d\+'),
            \ 'filename': matchstr(line, ': \zs.*')->expand(),
            \ 'valid': 1,
            \ })
        endif
    endfor
    return items
endfu


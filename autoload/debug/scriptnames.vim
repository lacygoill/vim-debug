fu debug#scriptnames#main() abort "{{{1
    let list = s:get_scriptnames()
    call setqflist([], ' ', {'items': list, 'title': ':Scriptnames'})
    do <nomodeline> QuickFixCmdPost copen
endfu

fu s:get_scriptnames() abort "{{{1
    let lines = split(execute('scriptnames'), '\n')
    let list = []
    for line in lines
        if line =~# ':'
            call add(list, {
            \ 'text': matchstr(line, '\d\+'),
            \ 'filename': expand(matchstr(line, ': \zs.*')),
            \ })
        endif
    endfor
    return list
endfu


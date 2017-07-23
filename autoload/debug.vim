" scriptnames {{{1

fu! debug#scriptnames() abort
    let lines = split(execute('scriptnames'), '\n')
    let list = []
    for line in lines
        if line =~# ':'
            call add(list, { 'text':     matchstr(line, '\d\+'),
                           \ 'filename': expand(matchstr(line, ': \zs.*')),
                           \ })
        endif
    endfor
    return list
endfu

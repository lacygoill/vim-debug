com! -bar -count=0 Scriptnames
                \  call setqflist(s:scriptnames_qflist())
                \| copen
                \| <count>

" scriptnames_qflist {{{1

fu! s:scriptnames_qflist() abort
    let names = execute('scriptnames')
    let list = []
    for line in split(names, '\n')
        if line =~# ':'
            call add(list, { 'text':     matchstr(line, '\d\+'),
                           \ 'filename': expand(matchstr(line, ': \zs.*')),
                           \ })
        endif
    endfor
    return list
endfu


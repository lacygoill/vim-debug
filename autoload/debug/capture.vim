fu! debug#capture#variable(type) abort "{{{1
    let pat = '\vlet\s+\zs(\S+)(\s*)[+-.*]?\=.*'
    if match(getline('.'), pat) ==# -1
        echo 'No variable to capture on this line'
        return
    endif
    t.
    sil exe 'keepj keepp s/'.pat.'/g:d_\1\2= deepcopy(\1)/e'
endfu

fu! debug#capture#dump() abort "{{{1
    let vars = getcompletion('d_*', 'var')
    if empty(vars)
        echo 'there are no debugging variables'
    else
        let tempfile = tempname()
        exe 'pedit '.tempfile
        call map(vars, {i,v -> v.' = '.string(g:{v})})
        wincmd P
        if &l:pvw
            call setline(1, vars)
            sil update
            nno  <buffer><nowait><silent>  q  :<c-u>call lg#window#quit()<cr>
        endif
    endif
endfu


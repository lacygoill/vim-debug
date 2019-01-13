fu! debug#capture#setup(verbose) abort "{{{1
    let s:verbose = a:verbose
    set opfunc=debug#capture#variable
endfu

fu! debug#capture#variable(_) abort "{{{1
    let pat = 'let\s\+\zs\([bwtglsav]:\)\=\(\a\w*\)\(\s*\)[+-.*]\==.*'
    if match(getline('.'), pat) ==# -1
        echo 'No variable to capture on this line'
        return
    endif
    t.
    let rep = s:verbose
        \ ? 'g:d_\2\3= get(g:, ''d_\2'', []) + [deepcopy(\1\2)]'
        \ : 'g:d_\2\3= deepcopy(\1\2)'
    sil exe 'keepj keepp s/'.pat.'/'.rep.'/e'
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
            " If we  call this  function while  in a help  buffer, which  is not
            " modifiable, the new buffer will be non-modifiable.
            setl modifiable
            call setline(1, vars)
            sil update
            nno  <buffer><nowait><silent>  q  :<c-u>call lg#window#quit()<cr>
        endif
    endif
endfu


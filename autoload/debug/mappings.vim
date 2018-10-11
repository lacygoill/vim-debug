fu! debug#mappings#using_function_keys() abort "{{{1
    let pat = '\m\cno mapping found'
    let lines = ['']
    for i in range(1,37)
        for mode in ['n', 'v', 'o', 'i', 'c']
            for modifier in ['', 's-']
                sil let out = execute('verb '.mode.'no <'.modifier.'f'.i.'>', '')
                if out !~# pat
                    let lines += split(out, '\n')
                endif
            endfor
        endfor
    endfor
    call debug#log#output({'excmd': 'Mappings using function keys', 'lines': lines})
endfu


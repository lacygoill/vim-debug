" messages_command {{{1

fu! debug#messages_command(bang) abort

    " `qfl` is a list of dictionaries
    " each one has the key:
    "
    "         text
    "
    " … and may have 2 other keys:
    "
    "         filename
    "         lnum
    let qfl = []

    " iterate over the messages in the log
    for msg in split(execute('messages'), '\n\+')
        " try to capture the address in a line such as:
        "         line    42:
        let l:lnum = matchstr(msg, '\v\C^line\s+\zs\d+\ze:$')

        "  ┌─ if you found one
        "  │                                             ┌─ and the previous message was an error
        "  │                                             │
        if !empty(l:lnum) && !empty(qfl) && qfl[-1].text =~# '^Error detected while processing'
            " append the line number to the previous message in the qfl
            let qfl[-1].text = substitute(qfl[-1].text, ':$', '['.l:lnum.']:', '')
        else
            call add(qfl, { 'text': msg })
        endif

        " try to capture the chain of function calls:
        "         FuncA[1]..FuncB:
        let chain = matchstr(qfl[-1].text, '\v\s+\zs\S+\]\ze:$')
        if empty(chain)
            continue
        endif

        " remove the chain from the message
        "         Error detected while processing function
        let qfl[-1].text = substitute(qfl[-1].text, '\v\s+\S+:$', '', '')
        " iterate over the function calls in the chain
        "         FuncA[12]
        "         FuncB[34]
        for call in split(chain, '\.\.')
            " add each call to the qfl
            call add(qfl, { 'text': call })

            " get the address where the function was called
            let l:lnum = matchstr(call, '\v\[\zs\d+\ze\]$')
            " get the function name
            let function = substitute(call, '\v\[\d+\]$', '', '')

            " if the name of a function contains a slash, or a dot, it's
            " not a function, it's a file
            "
            " it happens when the error occurred in a sourced file, like
            " a ftplugin; put a garbage command in one of them to reproduce
            if function =~# '[/.]' && filereadable(function)
                let qfl[-1].filename = function
                let qfl[-1].lnum = l:lnum
                let qfl[-1].text = ''
                " there's no chain of calls, the only error comes from this file
                continue
            " if the name of a function is just a number, it's a numbered
            " function, whose real name contains curly braces
            elseif function =~# '^\d\+$'
                let function = '{'.function.'}'
            endif

            " get the name of the file in which the function was defined
            "         Last set from ~/.vim/vimrc
            let definition = split(execute('verb function '.function), '\n')
            let filename = expand(matchstr(get(definition, 1, ''), 'from \zs.*'))

            if !filereadable(filename)
                continue
            endif

            " capture the code inside the function
            let code = definition[2:-2]
            let leading_address = len(matchstr(definition[-1], '^ *'))
            " remove leading address in front of each line
            let code = map(code, 'v:val[leading_address : -1]')
            " FIXME:
            " what's the point?
            call map(code, 'v:val ==# " " ? "" : v:val')

            let body = []
            let offset = 0
            for line in readfile(filename)
                " FIXME:
                " handle continuation lines
                " how does our plugin handle them?
                if line =~# '^\s*\\' && !empty(body)
                    let body[-1][0] .= s:sub(line, '^\s*\\', '')
                    " the address of a line in a function isn't necessarily
                    " the same as the one in the file
                    "
                    " every continuation line increases the difference between the 2
                    "
                    " `body` is a list of lists
                    " the 1st item of each list is a line of code
                    " the 2nd item is the offset to add to the address of the
                    " line in the function, to get the address of the line in
                    " the file
                    let offset += 1
                else
                    call extend(body, [[ s:gsub(line, '\t', repeat(' ', &tb)), offset ]])
                endif
            endfor

            for j in range(len(body)-len(code)-2)
                if function =~# '^{'
                    let pattern = '.*\.'
                elseif function =~# '^<SNR>'
                    let pattern = '\%(s:\|<SID>\)'.matchstr(function, '_\zs.*').'\>'
                else
                    let pattern = function.'\>'
                endif

                if body[j][0] =~# '\C^\s*fu\%[nction]!\=\s*'.pattern
             \ && (body[j + len(code) + 1][0] =~# '\C^\s*endf'
             \ && map(body[j+1 : j+len(code)], 'v:val[0]') ==# code
             \ || pattern !~# '\*')
                    let qfl[-1].filename = filename
                    let qfl[-1].lnum = j + body[j][1] + l:lnum + 1
                    break
                endif
            endfor

        endfor
    endfor

    call setqflist(qfl)
    call setqflist([], 'a', { 'title': ':Messages' })
    copen
    $
    call search('^[^|]', 'bWc')
endfu

" break {{{1

fu! s:break(type, arg) abort
    if a:arg ==# 'here' || a:arg ==# ''
        " we can't simply look for `fu!` backwards, because there could be
        " a whole function defined before us inside the current function
        "
        " so we need to use `searchpair()`
        "
        " what `searchpair('fu!', … , 'b')` does, is:
        "
        "         initialize a counter to 0
        "         look at `fu!` backwards
        "         every time `endfu` is found, increase the counter
        "         every time `fu!` is found, decrease the counter
        "         go on until `fu!` is found while the counter is zero

        let l:lnum = searchpair('^\s*fu\%[nction]\>.*(', '', '^\s*endf\%[unction]\>', 'Wbn')
        if l:lnum && l:lnum < line('.')
            let function = matchstr(getline(l:lnum), '^\s*\w\+!\=\s*\zs[^( ]*')
            if function =~# '^s:\|^<SID>'
                let id = s:script_id('%')
                if id
                    let function = s:sub(function, '^s:|^\<SID\>', '<SNR>'.id.'_')
                else
                    return 'echoerr "Could not determine script id"'
                endif
            endif
            if function =~# '\.'
                return 'echoerr "Dictionary functions not supported"'
            endif
            return 'break'.a:type.' func '.(line('.')==l:lnum ? '' : line('.')-l:lnum).' '.function
        else
            return 'break'.a:type.' here'
        endif
    endif
    return 'break'.a:type.' '.s:break_snr(a:arg)
endfu

" break_setup {{{1

fu! debug#break_setup() abort
    com! -buffer -bar -nargs=? -complete=custom,s:complete_breakadd Breakadd
                \ exe s:break('add',<q-args>)
    com! -buffer -bar -nargs=? -complete=custom,s:complete_breakdel Breakdel
                \ exe s:break('del',<q-args>)
endfu

" break_snr {{{1

fu! s:break_snr(arg) abort
    let id = s:script_id('%')
    if id
        return s:gsub(a:arg, '^func.*\zs%(<s:|\<SID\>)', '<SNR>'.id.'_')
    else
        return a:arg
    endif
endfu

" complete_breakadd {{{1

fu! s:complete_breakadd(A, L, P) abort
    let functions = join(sort(map(split(execute('function'), '\n'), 'matchstr(v:val, " \\zs[^(]*")')), '\n')
    if a:L =~# '^\w\+\s\+\w*$'
        return "here\nfile\nfunc"

    elseif a:L =~# '^\w\+\s\+func\s*\d*\s\+s:'
        let id = s:script_id('%')
        return s:gsub(functions,'\<SNR\>'.id.'_', 's:')

    elseif a:L =~# '^\w\+\s\+func '
        return functions

    elseif a:L =~# '^\w\+\s\+file '
        return glob(a:A.'*')
    else
        return ''
    endif
endfu

" complete_breakdel {{{1

fu! s:complete_breakdel(A, L, P) abort
    let args = matchstr(a:L, '\s\zs\S.*')
    let list = split(execute('breaklist'), "\n")
    call map(list, 's:sub(v:val, ''^\s*\d+\s*(\w+) (.*)  line (\d+)$'', ''\1 \3 \2'')')

    if a:L =~# '^\w\+\s\+\w*$'
        return "*\nhere\nfile\nfunc"

    elseif a:L =~# '^\w\+\s\+func\s'
        return join(map(filter(list, 'v:val =~# "^func"'), 'v:val[5 : -1]'), "\n")

    elseif a:L =~# '^\w\+\s\+file\s'
        return join(map(filter(list, 'v:val =~# "^file"'), 'v:val[5 : -1]'), "\n")

    else
        return ''
    endif
endfu

" gsub {{{1

fu! s:gsub(str,pat,rep) abort
    return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfu

" script_id {{{1

fu! s:script_id(filename) abort
    let filename = fnamemodify(expand(a:filename), ':p')
    for script in debug#scriptnames()
        if script.filename ==# filename
            return +script.text
        endif
    endfor
    return ''
endfu

" sub {{{1

fu! s:sub(str,pat,rep) abort
    return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfu

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

    call setqflist(list)
    call setqflist([], 'a', { 'title': ':Scriptnames'})
    copen
endfu

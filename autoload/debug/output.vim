fu debug#output#last_ex_command() abort "{{{1
    call setreg('o', s:get_output(), 'c')
    return '"o]p'
endfu

fu s:get_output() abort "{{{1
    try
        " We remove the first newline, so that we can insert the output of a command
        " inline, and not on the next line.
        return histget(':')->execute()->substitute('\n', '', '')
    catch
        " If the last command failed and produced an error, it will fail again.
        " But we still want something to be inserted: the error message(s).
        let messages = execute('messages')->split('\n')->reverse()
        let idx = match(messages, '^E\d\+')
        call remove(messages, idx+1, -1)
        call filter(messages, {_, v -> v =~# '\C^E\d\+'})
        return reverse(messages)->join("\n")
    endtry
endfu


fu! debug#output#last_ex_command() abort "{{{1
    let mode = mode(1)
    if mode is# 'i'
        let s:paste_save = &paste
        " enable 'paste' so that Vim  doesn't automatically add indentation when the
        " output has multiple lines
        set paste
        augroup restore_paste
            au!
            au CursorMovedI,TextChangedI * sil! exe 'set '.(s:paste_save ? '' : 'no').'paste'
                \ | unlet! s:paste_save
                \ | exe 'au! restore_paste' | aug! restore_paste
        augroup END
        return s:get_output()
    else
        let @o = s:get_output()
        return '"o]p'
    endif
endfu

fu! s:get_output() abort "{{{1
    try
        " We remove the first newline, so that we can insert the output of a command
        " inline, and not on the next line.
        return substitute(execute(histget(':')),'\n','','')
    catch
        " If the last command failed and produced an error, it will fail again.
        " But we still want something to be inserted: the error message(s).
        let messages = reverse(split(execute('messages'), '\n'))
        let idx = match(messages, '^E\d\+')
        call remove(messages, idx+1, -1)
        call filter(messages, {i,v -> v =~# '\C^E\d\+'})
        return join(reverse(messages), "\n")
    endtry
endfu


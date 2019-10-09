fu! debug#log#output(what) abort "{{{1
    " The dictionary passed to this function should have one of those set of keys:{{{
    "
    "      ┌ command we want to execute
    "      │ (to read its output in the preview window)
    "      │
    "      │      ┌ desired level of verbosity
    "      │      │
    "    - excmd, level    for :Verbose Cmd
    "    - excmd, lines    for :RepeatableMotions
    "             │        or any custom command for which we manually build the output
    "             │
    "             └ lists of lines which we'll use as the output of the command
    "
"}}}
    if    !has_key(a:what, 'excmd')
    \ && (!has_key(a:what, 'level') || !has_key(a:what, 'lines'))
        return
    endif

    let tempfile = tempname()

    let excmd = a:what.excmd
    " Don't run any single-character command.{{{
    "
    " This would raise an error in the next line; specifically because of:
    "
    "     split(excmd[1:])[0]
    "     E684: list index out of range: 0~
    "
    " We  could  fix it  with  `get()`,  but  there's  another issue  with  some
    " single-character commands, such as `:a` (and possibly `:c`, `:i`).
    " Trying to accept single-character commands is not worth it.
    "}}}
    if strlen(excmd) < 2
        return
    endif
    let pfx = exists(':'.split(excmd)[0]) == 2 || executable(split(excmd[1:])[0]) ? ':' : ''
    if has_key(a:what, 'lines')
        let title = pfx.excmd
        let lines = a:what.lines
        call writefile([title], tempfile)
        call writefile(lines, tempfile, 'a')
    else
        let level = a:what.level
        "               ┌ if the level is 1, just write `:Verbose`
        "               │ instead of `:1Verbose`
        "               ├───────────────────────┐
        let title = pfx.(level == 1 ? '' : level).'Verbose '.excmd
        call writefile([title], tempfile, 'b')
        "                                  │
        "                                  └ don't add a linefeed at the end
        " How do you know Vim adds a linefeed?{{{
        "
        " MWE:
        "         :!touch /tmp/file
        "         :call writefile(['text'], '/tmp/file')
        "         :!xxd /tmp/file
        "         00000000: 7465 7874 0a    text.~
        "                             └┤        │
        "                              │        └ LF glyph
        "                              └ LF hex code
        "}}}

        " 1. `s:redirect_…()` executes `excmd`,
        "     and redirects its output in a temporary file
        "
        " 2. `type(…)` checks the output of `s:redirect_…()`
        "
        "        it should be `0`
        "        if, instead, it's a string, then an error has occurred: bail out
        if type(s:redirect_to_tempfile(tempfile, level, excmd)) == type('')
            return
        endif
    endif

    " If we're in the command-line window, `:pedit` may fail.
    try
        " Load the file in the preview window. Useful to avoid having to close it if
        " we execute another `:Verbose` command. From `:h :ptag`:
        " > If a "Preview" window already exists, it is re-used
        " > (like a help window is).
        exe 'pedit '..tempfile

        " Vim doesn't give the focus to the preview window. Jump to it.
        wincmd P
        " if we really got there …
        if &l:pvw
            setl bt=nofile nobl noswf nowrap
            nmap <buffer><nowait><silent> q <plug>(my_quit)
            " `gf` &friends can't parse `/path/to/file line 123`,
            " so replace these line with `/path/to/file:123`
            sil! %s/Last set from.*\zs line \ze\d\+$/:/
            call search('Last set from \zs')
            nno  <buffer><nowait><silent>  DD  :<c-u>sil keepj keepp g/^\s*Last set from/d_<cr>
        endif
    catch
        return lg#catch_error()
    endtry
endfu

fu! s:redirect_to_tempfile(tempfile, level, excmd) abort "{{{1
    try
        " Purpose: if `excmd` is `!ls` we want to capture the output of `ls(1)`, not `:ls`
        let excmd = a:excmd[0] is# '!' ? 'echo system('.string(a:excmd[1:]).')' : a:excmd

        let output = execute(a:level.'verbose exe '.string(excmd))
        "                                     │{{{
        "                                     └ From `:h :verb`:
        "
        "                                                When concatenating another command,
        "                                                the ":verbose" only applies to the first one.
        "
        "                                        We want `:Verbose` to apply to the whole “pipeline“.
        "                                        Not just the part before the 1st bar.
        "}}}

        " We set 'vfile' to `tempfile`.
        " It will redirect (append) all messages to the end of this file.
        let &vfile = a:tempfile
        " Why not executing the command and `:echo`ing its output in a single command?{{{
        "
        " Two issues.
        "
        " First, you would need to run the command silently:
        "
        "     sil exe a:level.'verbose exe '.string(excmd)
        "     │
        "     └ even though verbose messages are redirected to a file,
        "       regular messages are  still displayed on the  command-line;
        "       we don't want that
        "       MWE:
        "           Verbose ls
        "
        " ---
        "
        " Second, sometimes, you would get undesired messages:
        "
        "     let &vfile = '/tmp/log'
        "     echo filter(split(execute('au'), '\n'), {_,v -> v =~# 'fugitive'})
        "     let &vfile = ''
        "
        " The  previous snippet  should have  output only  the lines  containing
        " `fugitive` inside the output of `:au`.
        " Because of this, the next command wouldn't work as expected:
        "
        "     :Verb Filter /fugitive/ au
        "}}}
        sil echo output
        let &vfile = ''

        sil exe a:level.'verbose exe '.string(excmd)
    catch
        return lg#catch_error()
    finally
        " We empty the value of 'vfile' for 2 reasons:
        "
        "     1. to restore the original value
        "
        "     2. writes are buffered, thus may not show up for some time
        "        Writing to the file ends when […] 'vfile' is made empty.
        "
        " These info are from `:h 'vfile'`.
        let &vfile = ''
    endtry
    return 0
endfu

vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import Catch from 'lg.vim'

def debug#log#output(what: dict<any>) #{{{1
    # The dictionary passed to this function should have one of those set of keys:{{{
    #
    #      ┌ command we want to execute
    #      │ (to read its output in the preview window)
    #      │
    #      │      ┌ desired level of verbosity
    #      │      │
    #    - excmd, level    for `:Verbose Cmd`
    #    - excmd, lines    for `:RepeatableMotions`
    #             │        or any custom command for which we manually build the output
    #             │
    #             └ lists of lines which we'll use as the output of the command
    #}}}
    if !has_key(what, 'excmd')
    && !(has_key(what, 'level') && has_key(what, 'lines'))
        return
    endif

    var tempfile: string = tempname()

    var excmd: string = what.excmd
    # Don't run any single-character command.{{{
    #
    # This would raise an error in the next line; specifically because of:
    #
    #     split(excmd[1 :])[0]
    #     E684: list index out of range: 0~
    #
    # We  could  fix it  with  `get()`,  but  there's  another issue  with  some
    # single-character commands, such as `:a` (and possibly `:c`, `:i`).
    # Trying to accept single-character commands is not worth it.
    #}}}
    if strlen(excmd) < 2
        echohl ErrorMsg
        echom 'Cannot run a single-character command; try to write it in its long form'
        echohl NONE
        return
    endif
    var pfx: string = exists(':' .. split(excmd)[0]) == 2
        || split(excmd[1 :])[0]->executable()
        ? ':' : ''
    if has_key(what, 'lines')
        var title: string = pfx .. excmd
        var lines: list<string> = what.lines
        writefile([title], tempfile)
        writefile(lines, tempfile, 'a')
    else
        var level: number = what.level
        var title: string = pfx
            # if the level is 1, just write `:Verbose` instead of `:1Verbose`
            .. (level == 1 ? '' : level)
            .. 'Verbose ' .. excmd
        writefile([title], tempfile, 'b')
        #                             │
        #                             └ don't add a linefeed at the end
        # How do you know Vim adds a linefeed?{{{
        #
        # MWE:
        #
        #     :!touch /tmp/file
        #     :call writefile(['text'], '/tmp/file')
        #     :!xxd /tmp/file
        #     00000000: 7465 7874 0a    text.~
        #                         ├┘        │
        #                         │         └ LF glyph
        #                         └ LF hex code
        #}}}

        # 1. `Redirect...()` executes `excmd`,
        #     and redirects its output in a temporary file
        #
        # 2. `type(...)` checks the output of `Redirect...()`
        #
        #        it should be `0`
        #        if, instead, it's a string, then an error has occurred: bail out
        if RedirectToTempfile(tempfile, level, excmd)->typename() == 'string'
            return
        endif
    endif

    # If we're in the command-line window, `:pedit` may fail.
    try
        # Load the file in the preview  window.  Useful to avoid having to close
        # it if we execute another `:Verbose` command.  From `:h :ptag`:
        #    > If a "Preview" window already exists, it is re-used
        #    > (like a help window is).
        exe 'pedit ' .. tempfile
    catch
        Catch()
        return
    endtry

    # Vim doesn't focus the preview window.  Jump to it.
    wincmd P
    # check we really got there ...
    if !&l:pvw
        return
    endif
    setl bt=nofile nobl noswf nowrap
    nmap <buffer><nowait> q <plug>(my_quit)
    search('Last set from \zs')
    nno <buffer><nowait> DD <cmd>sil keepj keepp g/^\s*Last set from/d _<cr>
enddef

def RedirectToTempfile(tempfile: string, level: number, arg_excmd: string): any #{{{1
    try
        # Purpose: if `excmd` is `!ls` we want to capture the output of `ls(1)`, not `:ls`
        var excmd: string = arg_excmd[0] == '!'
            ? 'echo system(' .. string(arg_excmd[1 :]) .. ')'
            : arg_excmd

        var output: string = execute(
            level .. 'verbose '
            # From `:h :verb`:{{{
            #
            #           When concatenating another command,
            #           the ":verbose" only applies to the first one.
            #
            # We want `:Verbose` to apply to the whole “pipeline“.
            # Not just the part before the 1st bar.
            #}}}
            .. 'exe '
            .. string(excmd))

        # We set `'vfile'` to `tempfile`.
        # It will redirect (append) all messages to the end of this file.
        &vfile = tempfile
        # Why not executing the command and `:echo`ing its output in a single command?{{{
        #
        # Two issues.
        #
        # First, you would need to run the command silently:
        #
        #     sil exe level .. 'verbose exe ' .. string(excmd)
        #     │
        #     └ even though verbose messages are redirected to a file,
        #       regular messages are  still displayed on the  command-line;
        #       we don't want that
        #       MWE:
        #           Verbose ls
        #
        # ---
        #
        # Second, sometimes, you would get undesired messages:
        #
        #     &vfile = '/tmp/log'
        #     echo execute('au')->split('\n')->filter((_, v: string): bool => v =~ 'fugitive')
        #     &vfile = ''
        #
        # The  previous snippet  should have  output only  the lines  containing
        # `fugitive` inside the output of `:au`.
        # Because of this, the next command wouldn't work as expected:
        #
        #     :Verb Filter /fugitive/ au
        #}}}
        sil echo output
        &vfile = ''

        sil exe level .. 'verbose exe ' .. string(excmd)
    catch
        return Catch()
    finally
        # We empty the value of `'vfile'` for 2 reasons:{{{
        #
        #    1. to restore the original value
        #
        #    2. writes are buffered, thus may not show up for some time
        #       Writing to the file ends when [...] 'vfile' is made empty.
        #
        # See `:h 'vfile'`.
        #}}}
        &vfile = ''
    endtry
    return false
enddef


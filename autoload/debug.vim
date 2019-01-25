fu! debug#help_about_last_errors() abort "{{{1
    let messages = reverse(split(execute('messages'), '\n'))
    "                    ┌ When an error occurs inside a try conditional,{{{
    "                    │ Vim prefixes an error message with:
    "                    │
    "                    │     Vim:
    "                    │ or:
    "                    │     Vim({cmd}):
    "                    ├───────────────┐}}}
    let pat_error = '^\%(Vim\%((\a\+)\)\=:\|".\{-}"\s\)\=\zsE\d\+'
    "                                       ├───────┘{{{
    "                                       └ in a buffer containing the word 'the', execute:
    "
    "                                               g/the/ .w >>/tmp/some_file
    "
    "                                         It raises this error message:
    "
    "                                               /tmp/file_1" E212: Can't open file for writing
    "}}}

    " index of most recent error
    let i = match(messages, pat_error)
    " index of next line which isn't an error, nor belongs to a stack trace
    let j = match(messages, '^\%('.pat_error.'\|Error\|line\)\@!', i+1)
    if j ==# -1
        let j = i+1
    endif

    let errors = map(messages[i:j-1], {idx,v -> matchstr(v, pat_error)})
    " remove lines  which don't contain  an error,  or which contain  the errors
    " E662 / E663 / E664 (they aren't interesting and come frequently)
    call filter(errors, {i,v -> !empty(v) && v !~# '^E66[234]$'})
    if empty(errors)
        return 'echo "no last errors"'
    endif

    let s:last_errors = get(s:, 'last_errors', {'taglist' : [], 'pos': -1})
    " the current latest errors are identical to the ones we saved the last time
    " we invoked this function
    if errors ==# s:last_errors.taglist
        " just update our position in the list of visited errors
        let s:last_errors.pos = (s:last_errors.pos + 1)%len(s:last_errors.taglist)
    else
        " reset our position in the list of visited errors
        let s:last_errors.pos = 0
        " reset the list of errors
        let s:last_errors.taglist = errors
    endif

    return 'h '.get(s:last_errors.taglist, s:last_errors.pos, s:last_errors.taglist[0])
endfu

fu! debug#messages() abort "{{{1
    0Verbose messages
    " If `:Verbose` encountered an error, we could still be in a regular window,
    " instead of the preview window. If that's the case, we don't want to remove
    " any text in the current buffer, nor install any match.
    if !&l:pvw
        return
    endif

    " From a help buffer, the buffer displayed in a newly opened preview
    " window inherits some settings, such as 'nomodifiable' and 'readonly'.
    " Make sure they're disabled so that we can remove noise.
    setl ma noro

    let noises = {
        \ '[fewer|more] lines': '\d+ %(fewer|more) lines%(; %(before|after) #\d+.*)?',
        \ '1 more line less':   '1 %(more )?line%( less)?%(; %(before|after) #\d+.*)?',
        \ 'change':             'Already at %(new|old)est change',
        \ 'changes':            '\d+ changes?; %(before|after) #\d+.*' ,
        \ 'E21':                "E21: Cannot make changes, 'modifiable' is off",
        \ 'E387':               'E387: Match is on current line',
        \ 'E486':               'E486: Pattern not found: \S*',
        \ 'E492':               'E492: Not an editor command: \S+',
        \ 'E501':               'E501: At end-of-file',
        \ 'E553':               'E553: No more items',
        \ 'E663':               'E663: At end of changelist',
        \ 'E664':               'E664: changelist is empty',
        \ 'Ex mode':            'Entering Ex mode.  Type "visual" to go to Normal mode.',
        \ 'empty lines':        '\s*' ,
        \ 'lines filtered':     '\d+ lines filtered' ,
        \ 'lines indented':     '\d+ lines [><]ed \d+ times?',
        \ 'file loaded':        '".{-}"%( \[RO\])? line \d+ of \d+ --\d+\%-- col \d+%(-\d+)?',
        \ 'file reloaded':      '".{-}".*\d+L, \d+C',
        \ 'g C-g':              'col \d+ of \d+; line \d+ of \d+; word \d+ of \d+; char \d+ of \d+; byte \d+ of \d+',
        \ 'C-c':                'Type\s*:qa!\s*and press \<Enter\> to abandon all changes and exit Vim',
        \ 'maintainer':         '\mMessages maintainer: Bram Moolenaar <Bram@vim.org>',
        \ 'Scanning':           'Scanning:.*',
        \ 'substitutions':      '\d+ substitutions? on \d+ lines?',
        \ 'verbose':            ':0Verbose messages',
        \ 'W10':                'W10: Warning: Changing a readonly file',
        \ 'yanked lines':       '%(block of )?\d+ lines yanked',
        \ }

    for noise in values(noises)
        sil! exe 'g/\v^'.noise.'$/d_'
    endfor

    call matchadd('ErrorMsg', '\v^E\d+:\s+.*')
    call matchadd('ErrorMsg', '\v^Vim.{-}:E\d+:\s+.*')
    call matchadd('ErrorMsg', '^Error detected while processing.*')
    call matchadd('LineNr', '\v^line\s+\d+:$')
    exe '$'
endfu

fu! debug#time(cmd, cnt) "{{{1
    let time = reltime()
    try
        " We could get rid of the if/else/endif, and shorten the code, but we
        " won't do it, because the most usual case is a:cnt = 1. And we want to
        " execute a:cmd as fast as possible (no let,  no while loop), because Ex
        " commands are slow.
        if a:cnt > 1
            let i = 0
            while i < a:cnt
                exe a:cmd
                let i += 1
            endwhile
        else
            exe a:cmd
        endif
    catch
        return lg#catch_error()
    finally
        " We clear the screen before displaying the results, to erase the
        " possible messages displayed by the command.
        redraw
        echom matchstr(reltimestr(reltime(time)), '\v.*\..{,3}').' seconds to run :'.a:cmd
    endtry
endfu

fu! debug#wrapper(cmd) abort "{{{1
    try
        ToggleEditingCommands 0
        exe 'debug '.a:cmd
    catch
        return lg#catch_error()
    finally
        ToggleEditingCommands 1
    endtry
endfu


fu! debug#prof#completion(arglead, cmdline, _pos) abort "{{{1
    if !empty(matchstr(a:cmdline, '\s-'))
        return '-read_last_profile'
    endif

    let paths_to_plugins = glob($HOME.'/.vim/plugged/*', 0, 1)
    let plugin_names = map(paths_to_plugins, {i,v -> matchstr(v, '.*/\zs.*')})
    return join(plugin_names, "\n")
endfu

fu! debug#prof#main(...) abort "{{{1
    if index(['', '-h', '--help'], a:1) >= 0
        echo printf("usage:\n    %s\n    %s",
        \ ':Prof {plugin name}         profile a plugin',
        \ ':Prof -read_last_profile    load last logged profile',
        \ )
        return
    endif

    if a:1 is# '-read_last_profile'
        return s:read_last_profile()
    endif

    let plugin_name = a:1
    if index(split(debug#prof#completion('', '', -1), "\n"), plugin_name) == -1
        echo 'There''s no plugin named:  '.a:1
        return
    endif

    let start_cmd = 'profile start $XDG_RUNTIME_VIM/profile.log'
    let file_cmd = 'prof! file '.$HOME.'/.vim/plugged/'.plugin_name.'/**/*.vim'
    exe start_cmd | exe file_cmd

    let plugin_files = glob($HOME.'/.vim/plugged/'.plugin_name.'/**/*.vim', 0, 1)
    call filter(plugin_files, {i,v -> v !~# '\m\c/t\%[est]/'})
    call map(plugin_files, {i,v -> 'so '.v})
    call writefile(plugin_files, $XDG_RUNTIME_VIM.'/profile.log')
    sil! so $XDG_RUNTIME_VIM/profile.log

    echo printf("Executing:\n    %s\n    %s\n%s\n\n",
    \ start_cmd,
    \ file_cmd,
    \ join(map(plugin_files, {i,v -> '    '.v}), "\n"),
    \ )

    " TODO: If Vim had  the subcommand `dump` (like Neovim), we  would not need to restart Vim. {{{
    " We could see the log from the current session.
    "
    " Would it be a good idea?
    "
    " Should we ask `dump` as a feature request?
    " If you do, ask about `stop` too.
    "}}}
    " Why not with `:echo`?{{{
    "
    " Because we want it logged.
    "}}}
    " Why not everything (i.e. including the previous messages) with `:echom`?{{{
    "
    " Because `:echom` doesn't translate `\n` into a newline.
    " It prints a NUL `^@` instead.
    "}}}
    echom 'Recreate the issue, restart Vim, and execute:    :Prof -read_last_profile'
endfu

fu! s:read_last_profile() abort "{{{1
    let logfile = $XDG_RUNTIME_VIM.'/profile.log'
    if !filereadable(logfile)
        echo 'There''s no results to read'
        return
    endif
    sp $XDG_RUNTIME_VIM/profile.log
    sil TW

    " folding may interfere, disable it
    let &l:fen = 0
    " create an empty fold before the first profiled function
    " for better readability
    " Why `silent!`?{{{
    "
    " If we reopen the log, the pattern won't be found anymore.
    "}}}
    sil! 1/^FUNCTION /-put_ | s/^/#/
    " create an empty fold before the summary at the end
    sil! 1/^FUNCTIONS SORTED/-put_ | s/^/#/
    let &l:fen = 1

    " fold every function, every script, and the ending summaries
    sil! %s/^FUNCTION\s\+/## /
    sil! %s/^SCRIPT\|^\zeFUNCTIONS SORTED/# /
    sil update
endfu


fu! debug#local_plugin#main(...) abort "{{{1
    let args = split(a:1)
    let kind = matchstr(a:1, '-kind\s\+\zs[^ -]\S*')
    let filetype = matchstr(a:1, '-filetype\s\+\zs[^-]\S*')

    if count(args, '-kind') == -1 || count(args, '-filetype') == -1
        echo 'usage:'
        echo '    DebugLocalPlugin -kind ftplugin -filetype sh'
        echo '    DebugLocalPlugin -kind indent   -filetype awk'
        echo '    DebugLocalPlugin -kind syntax   -filetype python'
        echo "\n"
        echo 'To get the list of breakpoints, execute:'
        echo '    breakl '
        echo "\n"
        echo 'When you are finished, execute:'
        echo '    breakd *'
        return
    endif

    if index(['ftplugin', 'indent', 'syntax'], kind) == -1
        echo 'you did not provide a valid kind; choose:  ftplugin, indent, or syntax'
        return
    elseif index(getcompletion('*', 'filetype'), filetype) == -1
        echo 'you did not provide a valid filetype'
        return
    endif

    " breakadd file */ftplugin/c.vim
    " breakadd file */indent/c.vim
    " breakadd file */syntax/c.vim
    call s:add_breakpoints(kind, filetype)

    if kind is# 'ftplugin'
        " breakadd file */ftplugin/c_*.vim
        call s:add_breakpoints('ftplugin', filetype, 'c_*.vim')
        " breakadd file */ftplugin/c/*.vim
        call s:add_breakpoints('ftplugin', filetype, 'c/*.vim')
    elseif kind is# 'syntax'
        " breakadd file */syntax/c_*.vim
        call s:add_breakpoints('syntax', filetype, 'c/*.vim')
    endif
endfu

fu! s:add_breakpoints(kind, filetype, ...) abort "{{{1
    if a:0
        let cmd = a:kind is# 'ftplugin' && (a:1 is# 'c_*.vim' || a:1 is# 'c/*.vim')
            \ ?     'breakadd file */fptlugin/'.a:filetype . a:1[1:]
            \ : a:kind is# 'syntax'
            \ ?     'breakadd file */syntax/'.a:filetype . a:1[1:]
            \ :     ''
    else
        let cmd = 'breakadd file */'.a:kind.'/'.a:filetype.'.vim'
    endif

    if cmd is# ''
        return
    endif

    echom '[:DebugLocalPlugin] executing:  '.cmd
    exe cmd
endfu

fu! debug#local_plugin#complete(arglead, cmdline, pos) abort "{{{1
    let word_before_cursor = matchstr(a:cmdline, '.*\s\zs-\S.*\%'.a:pos.'c.')

    if word_before_cursor =~# '^-filetype\s*\S*$'
        let filetypes = getcompletion('*', 'filetype')
        return join(filetypes, "\n")

    elseif word_before_cursor =~# '^-kind\s*\S*$'
        let kinds = ['ftplugin', 'indent', 'syntax']
        return join(kinds, "\n")

    elseif empty(a:arglead) || a:arglead[0] is# '-'
        let options = ['-kind', '-filetype']
        return join(options, "\n")
    endif

    return ''
endfu


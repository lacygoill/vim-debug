fu! debug#local_plugin#main(...) abort "{{{1
    let args = split(a:1)
    let kind = matchstr(a:1, '-kind\s\+\zs[^ -]\S*')
    let filetype = matchstr(a:1, '-filetype\s\+\zs[^-]\S*')

    if match(args, '-kind') == -1 || match(args, '-filetype') == -1
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

    " breakadd file */ftplugin/awk.vim
    " breakadd file */indent/awk.vim
    " breakadd file */syntax/awk.vim
    let cmd = 'breakadd file */'.kind.'/'.filetype.'.vim'
    echom '[:DebugLocalPlugin] executing:  '.cmd
    exe cmd
endfu

fu! debug#local_plugin#complete(arglead, cmdline, pos) abort "{{{1
    let word_before_cursor = matchstr(a:cmdline, '.*\s\zs-\S.*\%'.a:pos.'c')
    let word_before_cursor = matchstr(word_before_cursor, '\S*\s*$')

    if word_before_cursor =~# '^-filetype\s*'
        let filetypes = getcompletion('*', 'filetype')
        return join(filetypes, "\n")

    elseif word_before_cursor =~# '^-kind\s*'
        let kinds = ['ftplugin', 'indent', 'syntax']
        return join(kinds, "\n")

    elseif empty(a:arglead) || a:arglead[0] is# '-'
        let options = ['-kind', '-filetype']
        return join(options, "\n")
    endif

    return ''
endfu



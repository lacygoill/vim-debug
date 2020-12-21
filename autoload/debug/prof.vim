if exists('g:autoloaded_debug#prof')
    finish
endif
let g:autoloaded_debug#prof = 1

import FuncComplete from 'lg.vim'

const s:DIR = getenv('XDG_RUNTIME_VIM') ?? '/tmp'

const s:ARGUMENTS = getcompletion('profile ', 'cmdline')
"                                         ^
"                                         necessary

fu debug#prof#completion(arglead, cmdline, pos) abort "{{{1
    let l:Filter = {l -> filter(l, {_, v -> stridx(v, a:arglead) == 0})}

    if a:cmdline =~# '^\CProf\s\+func\s\+'
    \ && a:cmdline !~# '^\CProf\s\+func\s\+\S\+\s\+'
        return s:FuncComplete(a:arglead, '', 0)

    elseif a:cmdline =~# '^\CProf\s\+\%(file\|start\)\s\+'
    \ && a:cmdline !~# '^\CProf\s\+\%(file\|start\)\s\+\S\+\s\+'
        if a:arglead =~# '$\h\w*$'
            return getcompletion(a:arglead[1:], 'environment')
                \ ->map({_, v -> '$' .. v})
        else
            return getcompletion(a:arglead, 'file')
        endif

    elseif a:cmdline =~# '^\CProf\s\+\%(' .. join(s:ARGUMENTS, '\|') .. '\)'
        \ || count(a:cmdline, ' -') >= 2
        return []

    elseif a:cmdline !~# '-'
        return copy(s:ARGUMENTS)->l:Filter()
    endif

    " Warning: if you try to refactor this block, make some tests.{{{
    "
    " In particular, check how the function completes this:
    "
    "     :Prof -plu
    "     :Prof -plugin vim-
    "}}}
    let last_dash_to_cursor = matchstr(a:cmdline, '.*\s\zs-.*\%' .. (a:pos + 1) .. 'c')
    if last_dash_to_cursor =~# '^-\%[plugin]$\|^-\%[read_last_profile]$'
        return l:Filter(['-plugin', '-read_last_profile'])

    elseif last_dash_to_cursor =~# '^-plugin\s\+\S*$'
        let paths_to_plugins = glob($HOME .. '/.vim/plugged/*', 0, 1)
        let plugin_names = map(paths_to_plugins, {_, v -> matchstr(v, '.*/\zs.*')}) + ['fzf']
        return l:Filter(plugin_names)
    endif
    return []
endfu

fu debug#prof#wrapper(bang, ...) abort "{{{1
    if index(['', '-h', '--help'], a:1) >= 0
        let usage =<< trim END
            usage:
                :Prof continue
                :Prof[!] file {pattern}
                :Prof func {pattern}
                :Prof pause
                :Prof start {fname}
                :Prof -plugin {plugin name} profile a plugin
                :Prof -read_last_profile    load last logged profile
        END
        echo join(usage, "\n")
        return
    endif

    let bang = a:bang ? '!' : ''
    if a:1 =~# '^\C\%(' .. join(s:ARGUMENTS, '\|') .. '\)\s*$'
        \ .. '\|^\%(start\|file\|func\)\s\+\S\+\s*$'
        try
            exe printf('prof%s %s', bang, a:1)
        catch
            echohl ErrorMsg
            echom v:exception
            echohl NONE
        endtry
        return
    elseif a:1 is# '-read_last_profile'
        return s:read_last_profile()
    endif

    let plugin_name = substitute(a:1, '-plugin\s\+', '', '')
    let cmdline = 'Prof -plugin '
    if debug#prof#completion('', cmdline, strchars(cmdline, 1))->index(plugin_name) == -1
        echo 'There''s no plugin named:  ' .. plugin_name
        return
    endif

    let start_cmd = 'profile start ' .. s:DIR .. '/profile.log'
    if plugin_name is# 'fzf'
        let file_cmd = 'prof' .. bang .. ' file ' .. $HOME .. '/.fzf/**/*.vim'
        exe start_cmd | exe file_cmd
        let plugin_files = glob($HOME .. '/.fzf/**/*.vim', 0, 1)
    else
        let file_cmd = 'prof' .. bang .. ' file ' .. $HOME .. '/.vim/plugged/' .. plugin_name .. '/**/*.vim'
        exe start_cmd | exe file_cmd
        let plugin_files = glob($HOME .. '/.vim/plugged/' .. plugin_name .. '/**/*.vim', 0, 1)
    endif

    call filter(plugin_files, {_, v -> v !~# '\m\c/t\%[est]/'})
    call map(plugin_files, {_, v -> 'so ' .. v})
    call writefile(plugin_files, s:DIR .. '/profile.log')
    sil! exe 'so ' .. s:DIR .. '/profile.log'

    echo printf("Executing:\n    %s\n    %s\n%s\n\n",
        \ start_cmd,
        \ file_cmd,
        \ map(plugin_files, {_, v -> '    ' .. v})->join("\n"),
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
    echom 'Recreate the issue, restart Vim, and execute:  :Prof -read_last_profile'
endfu

fu s:read_last_profile() abort "{{{1
    let logfile = s:DIR .. '/profile.log'
    if !filereadable(logfile)
        echo 'There are no results to read'
        return
    endif
    exe 'sp ' .. s:DIR .. '/profile.log'
    sil TW

    " folding may interfere, disable it
    let [fen_save, winid, bufnr] = [&l:fen, win_getid(), bufnr('%')]
    let &l:fen = 0
    try
        " create an empty fold before the first profiled function for better readability;
        " we use `silent!` because if we reopen the log, the pattern won't be found anymore
        sil! 1/^FUNCTION /-put_ | s/^/#/
        " create an empty fold before the summary at the end
        sil! 1/^FUNCTIONS SORTED/-put_ | s/^/#/
    finally
        if winbufnr(winid) == bufnr
            let [tabnr, winnr] = win_id2tabwin(winid)
            call settabwinvar(tabnr, winnr, '&fen', fen_save)
        endif
    endtry

    " fold every function, every script, and the ending summaries
    sil %s/^FUNCTION\s\+/## /e
    sil %s/^SCRIPT\|^\zeFUNCTIONS SORTED/# /e
    sil! call fold#adhoc#main()
    norm! 1G
    sil! FoldAutoOpen 1
    sil update
endfu


vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import FuncComplete from 'lg.vim'

const DIR = getenv('XDG_RUNTIME_VIM') ?? '/tmp'

const ARGUMENTS = getcompletion('profile ', 'cmdline')
#                                       ^
#                                       necessary

fu debug#prof#completion(arglead, cmdline, pos) abort "{{{1
    let l:Filter = {l -> filter(l, {_, v -> stridx(v, a:arglead) == 0})}

    if a:cmdline =~# '^\CProf\s\+func\s\+'
    \ && a:cmdline !~# '^\CProf\s\+func\s\+\S\+\s\+'
        return s:FuncComplete(a:arglead, '', 0)

    elseif a:cmdline =~# '^\CProf\s\+\%(file\|start\)\s\+'
    \ && a:cmdline !~# '^\CProf\s\+\%(file\|start\)\s\+\S\+\s\+'
        if a:arglead =~# '$\h\w*$'
            return getcompletion(a:arglead[1 :], 'environment')
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

def debug#prof#wrapper(bang: string, args: string) #{{{1
    if index(['', '-h', '--help'], args) >= 0
        var usage =<< trim END
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

    if args =~ '^\C\%(' .. join(ARGUMENTS, '\|') .. '\)\s*$'
        .. '\|^\%(start\|file\|func\)\s\+\S\+\s*$'
        try
            exe printf('prof%s %s', bang, args)
        catch
            echohl ErrorMsg
            echom v:exception
            echohl NONE
        endtry
        return
    elseif args == '-read_last_profile'
        ReadLastProfile()
        return
    endif

    var plugin_name = substitute(args, '-plugin\s\+', '', '')
    var cmdline = 'Prof -plugin '
    if debug#prof#completion('', cmdline, strchars(cmdline, v:true))->index(plugin_name) == -1
        echo 'There''s no plugin named:  ' .. plugin_name
        return
    endif

    var start_cmd = 'profile start ' .. DIR .. '/profile.log'
    var plugin_files: list<string>
    var file_cmd: string
    if plugin_name == 'fzf'
        file_cmd = 'prof' .. bang .. ' file ' .. $HOME .. '/.fzf/**/*.vim'
        exe start_cmd | exe file_cmd
        plugin_files = glob($HOME .. '/.fzf/**/*.vim', false, true)
    else
        file_cmd = 'prof' .. bang .. ' file ' .. $HOME .. '/.vim/plugged/' .. plugin_name .. '/**/*.vim'
        exe start_cmd | exe file_cmd
        plugin_files = glob($HOME .. '/.vim/plugged/' .. plugin_name .. '/**/*.vim', false, true)
    endif

    filter(plugin_files, (_, v) => v !~ '\m\c/t\%[est]/')
    map(plugin_files, (_, v) => 'so ' .. v)
    writefile(plugin_files, DIR .. '/profile.log')
    sil! exe 'so ' .. DIR .. '/profile.log'

    echo printf("Executing:\n    %s\n    %s\n%s\n\n",
        start_cmd,
        file_cmd,
        map(plugin_files, (_, v) => '    ' .. v)->join("\n"),
        )

    # TODO: If Vim had  the subcommand `dump` (like Neovim), we  would not need to restart Vim. {{{
    # We could see the log from the current session.
    #
    # Would it be a good idea?
    #
    # Should we ask `dump` as a feature request?
    # If you do, ask about `stop` too.
    #}}}
    # Why not with `:echo`?{{{
    #
    # Because we want it logged.
    #}}}
    # Why not everything (i.e. including the previous messages) with `:echom`?{{{
    #
    # Because `:echom` doesn't translate `\n` into a newline.
    # It prints a NUL `^@` instead.
    #}}}
    echom 'Recreate the issue, restart Vim, and execute:  :Prof -read_last_profile'
enddef

def ReadLastProfile() #{{{1
    var logfile = DIR .. '/profile.log'
    if !filereadable(logfile)
        echo 'There are no results to read'
        return
    endif
    exe 'sp ' .. DIR .. '/profile.log'
    sil TW

    # folding may interfere, disable it
    var fen_save = &l:fen
    var winid = win_getid()
    var bufnr = bufnr('%')
    &l:fen = false
    try
        # create an empty fold before the first profiled function for better readability;
        # we use `silent!` because if we reopen the log, the pattern won't be found anymore
        sil! :1/^FUNCTION /-put _ | s/^/#/
        # create an empty fold before the summary at the end
        sil! :1/^FUNCTIONS SORTED/-put _ | s/^/#/
    finally
        if winbufnr(winid) == bufnr
            var tabnr: number
            var winnr: number
            [tabnr, winnr] = win_id2tabwin(winid)
            settabwinvar(tabnr, winnr, '&fen', fen_save)
        endif
    endtry

    # fold every function, every script, and the ending summaries
    sil :%s/^FUNCTION\s\+/## /e
    sil :%s/^SCRIPT\|^\zeFUNCTIONS SORTED/# /e
    sil! fold#adhoc#main()
    norm! 1G
    sil! FoldAutoOpen 1
    sil update
enddef


vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import FuncComplete from 'lg.vim'

const DIR: string = getenv('XDG_RUNTIME_VIM') ?? '/tmp'

const ARGUMENTS: list<string> = getcompletion('profile ', 'cmdline')
#                                                     ^
#                                                     necessary

def debug#prof#completion( #{{{1
    arglead: string,
    cmdline: string,
    pos: number
    ): list<string>

    var Filter: func = (l: list<string>): list<string> =>
        filter(l, (_, v: string): bool => stridx(v, arglead) == 0)

    if cmdline =~ '^\CProf\s\+func\s\+'
    && cmdline !~ '^\CProf\s\+func\s\+\S\+\s\+'
        return FuncComplete(arglead, '', 0)

    elseif cmdline =~ '^\CProf\s\+\%(file\|start\)\s\+'
    && cmdline !~ '^\CProf\s\+\%(file\|start\)\s\+\S\+\s\+'
        if arglead =~ '$\h\w*$'
            return getcompletion(arglead[1 :], 'environment')
                ->map((_, v) => '$' .. v)
        else
            return getcompletion(arglead, 'file')
        endif

    elseif cmdline =~ '^\CProf\s\+\%(' .. join(ARGUMENTS, '\|') .. '\)'
        || count(cmdline, ' -') >= 2
        return []

    elseif cmdline !~ '-'
        return copy(ARGUMENTS)->Filter()
    endif

    # Warning: if you try to refactor this block, make some tests.{{{
    #
    # In particular, check how the function completes this:
    #
    #     :Prof -plu
    #     :Prof -plugin vim-
    #}}}
    var last_dash_to_cursor: string = matchstr(cmdline, '.*\s\zs-.*\%' .. (pos + 1) .. 'c')
    if last_dash_to_cursor =~ '^-\%[plugin]$\|^-\%[read_last_profile]$'
        return Filter(['-plugin', '-read_last_profile'])

    elseif last_dash_to_cursor =~ '^-plugin\s\+\S*$'
        var paths_to_plugins: list<string> =
            glob($HOME .. '/.vim/plugged/*', false, true)
        var plugin_names: list<string> =
            map(paths_to_plugins, (_, v) => matchstr(v, '.*/\zs.*')) + ['fzf']
        return Filter(plugin_names)
    endif
    return []
enddef

def debug#prof#wrapper(bang: string, args: string) #{{{1
    if index(['', '-h', '--help'], args) >= 0
        var usage: list<string> =<< trim END
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

    var plugin_name: string = substitute(args, '-plugin\s\+', '', '')
    var cmdline: string = 'Prof -plugin '
    if debug#prof#completion('', cmdline, strchars(cmdline, true))->index(plugin_name) == -1
        echo 'There''s no plugin named:  ' .. plugin_name
        return
    endif

    var start_cmd: string = 'profile start ' .. DIR .. '/profile.log'
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
    var logfile: string = DIR .. '/profile.log'
    if !filereadable(logfile)
        echo 'There are no results to read'
        return
    endif
    exe 'sp ' .. DIR .. '/profile.log'
    sil TW

    # folding may interfere, disable it
    var fen_save: bool = &l:fen
    var winid: number = win_getid()
    var bufnr: number = bufnr('%')
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


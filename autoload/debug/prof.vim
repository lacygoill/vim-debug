vim9script noclear

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
        l->filter((_, v: string): bool => stridx(v, arglead) == 0)

    if cmdline =~ '^\CProf\s\+func\s\+'
    && cmdline !~ '^\CProf\s\+func\s\+\S\+\s\+'
        return FuncComplete(arglead, '', 0)

    elseif cmdline =~ '^\CProf\s\+\%(file\|start\)\s\+'
    && cmdline !~ '^\CProf\s\+\%(file\|start\)\s\+\S\+\s\+'
        if arglead =~ '$\h\w*$'
            return getcompletion(arglead[1 :], 'environment')
                ->map((_, v: string): string => '$' .. v)
        else
            return getcompletion(arglead, 'file')
        endif

    elseif cmdline =~ '^\CProf\s\+\%(' .. ARGUMENTS->join('\|') .. '\)'
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
    var last_dash_to_cursor: string = cmdline->matchstr('.*\s\zs-.*\%' .. (pos + 1) .. 'c')
    if last_dash_to_cursor =~ '^-\%[plugin]$\|^-\%[read_last_profile]$'
        return Filter(['-plugin', '-read_last_profile'])

    elseif last_dash_to_cursor =~ '^-plugin\s\+\S*$'
        var plugin_names: list<string> = ['minpac/start', 'minpac/opt', 'mine/start', 'mine/opt']
            ->map((_, v: string): string => $HOME .. '/.vim/pack/' .. v)
            ->filter((_, v: string): bool => isdirectory(v))
            ->mapnew((_, v: string): list<string> => readdir(v))
            ->reduce((a: list<string>, v: list<string>): list<string> => a + v)
            + ['fzf']
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
        echo usage->join("\n")
        return
    endif

    if args =~ '^\C\%(' .. ARGUMENTS->join('\|') .. '\)\s*$'
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

    var plugin_name: string = args->substitute('-plugin\s\+', '', '')
    var cmdline: string = 'Prof -plugin '
    if debug#prof#completion('', cmdline, strcharlen(cmdline))->index(plugin_name) == -1
        echo 'There''s no plugin named:  ' .. plugin_name
        return
    endif

    var start_cmd: string = 'profile start ' .. DIR .. '/profile.log'
    var plugin_files: list<string>
    var file_cmd: string
    if plugin_name == 'fzf'
        file_cmd = 'prof' .. bang .. ' file ' .. $HOME .. '/.fzf/**/*.vim'
        exe start_cmd | exe file_cmd
        plugin_files = glob($HOME .. '/.fzf/**/*.vim', true, true)
    else
        file_cmd = 'prof' .. bang .. ' file '
            .. $HOME .. '/.vim/pack/**/' .. plugin_name .. '/**/*.vim'
        exe start_cmd | exe file_cmd
        plugin_files = glob($HOME .. '/.vim/pack/**/' .. plugin_name .. '/**/*.vim', true, true)
    endif

    plugin_files
        ->filter((_, v: string): bool => v !~ '\c/t\%[est]/')
        ->map((_, v: string): string => 'so ' .. v)
        ->writefile(DIR .. '/profile.log')
    exe 'sil! so ' .. DIR .. '/profile.log'

    echo printf("Executing:\n    %s\n    %s\n%s\n\n",
            start_cmd,
            file_cmd,
            plugin_files
                ->map((_, v: string): string => '    ' .. v)
                ->join("\n"))

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
    sil keepj keepp :%s/\s*$//e

    sil! fold#adhoc#main()
    norm! 1G
    sil! FoldAutoOpen 1
    sil update
enddef


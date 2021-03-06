vim9script noclear

def FoldSection() #{{{1
    var new_line: string = getline('.')->substitute('^', '# ', '')
    setline('.', ['#'] + [new_line])
    if line('.') != 1
        append(line('.') - 1, '')
    endif
enddef

def FormatInfo(v: dict<any>): list<string> #{{{1
    return [
        "id\x01 " .. v.id,
        "repeat\x01 " .. v.repeat,
        "remaining\x01 " .. FormatTime(v.remaining),
        "time\x01 " .. FormatTime(v.time),
        "paused\x01 " .. v.paused,
        "callback\x01 " .. string(v.callback),
    ]
enddef

def FormatTime(v: number): string #{{{1
    return v <= 999
        ?        v .. 'ms'
        :    v <= 59'999
        ?        (v / 1'000) .. 's ' .. fmod(v, 1'000)->float2nr()->FormatTime()
        :    v <= 3'600'000
        ?        (v / 60'000) .. 'm ' .. fmod(v, 60'000)->float2nr()->FormatTime()
        :        (v / 3'600'000) .. 'h ' .. fmod(v, 3'600'000)->float2nr()->FormatTime()
enddef

def debug#timer#infoOpen() #{{{1
    # Why saving the info in a script-local variable?{{{
    #
    # To pass it to the function which will populate the buffer.
    # The  latter  is not  called  from  here,  but  from an  autocmd  installed
    # elsewhere.
    #}}}
    # Ok but why not re-capturing the info from `debug#timer#populate()`?{{{
    #
    # `populate()` will be called by an autocmd listening to `BufNewFile`.
    # When this event will  be fired, some timers may be  started by our plugins
    # (example: `vim-save`).  They're noise; we don't want them.
    #
    # We must save the info now, before any event is fired and interferes.
    #}}}
    # Why the filter?{{{
    #
    # In `vim-readline`, we have an autocmd which starts a timer after 0ms every
    # time we enter the command-line.
    # Without the filter, we would see this timer all the time.
    # It's noise.
    #
    # Besides, we don't care about a timer which we can't control (stop/pause).
    #}}}
    infos = timer_info()
        ->filter((_, v: dict<any>): bool => v.time > 0)
    if empty(infos)
        echo 'no timer is currently running'
        return
    endif
    var tempfile: string = tempname() .. '/timer_info'
    execute 'topleft :' .. (&columns / 3) .. ' vnew ' .. tempfile
    &l:previewwindow = true
    &l:wrap = false
    wincmd p
enddef

def debug#timer#measure() #{{{1
    if date == []
        echomsg '  go!'
        date = reltime()
    else
        echomsg reltime(date)
            ->reltimestr()
            ->matchstr('.*\....') .. ' seconds to do the task'
        date = []
    endif
enddef
var date: list<number>

def debug#timer#populate() #{{{1
    if infos == []
        infos = timer_info()
    endif
    var formatted_infos: list<list<string>> = infos
        ->mapnew((_, v: dict<any>): list<string> => FormatInfo(v))
    infos = []
    var lines: list<string>
    for info: list<string> in formatted_infos
        lines += info
    endfor
    lines->setline(1)
    silent :% !column -s $'\x01' -t
    # `PutDefinition()` calls `append()` which is silent, so why `:silent`?{{{
    #
    # Somehow, `:g` has priority, and it's not silent by default.
    #
    # MWE:
    #
    #     def Func()
    #         ['abc', 'def', 'ghi']->append('.')
    #     enddef
    #     :. global/^/Func()
    #     3 more lines˜
    #}}}
    silent keepjumps keeppatterns global/^callback\s\+function('.\{-}')$/PutDefinition()
    keepjumps keeppatterns global/^id\s\+/FoldSection()
enddef
var infos: list<dict<any>>

def PutDefinition() #{{{1
    var line: string = getline('.')
    var definition: list<string>
    if line =~ '^callback\s\+function(''<lambda>\d\+'')$'
        var lambda_id: string = line->matchstr('\d\+')
        definition = execute('verbose function <lambda>' .. lambda_id)->split('\n')
    else
        var func_name: string = line
            ->matchstr('^callback\s\+function(''\zs.\{-}\ze'')$')
        definition = execute('verbose function ' .. func_name)->split('\n')
    endif
    (
          ['---']
        + definition->map((_, v: string) => '    ' .. v)
    )->append('.')
enddef


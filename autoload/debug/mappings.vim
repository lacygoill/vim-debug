vim9script noclear

def debug#mappings#usingFunctionKeys() #{{{1
    var pat: string = '\cno mapping found'
    var lines: list<string> = ['']
    for i: number in range(1, 37)
        for mode: string in ['n', 'v', 'o', 'i', 'c']
            for modifier: string in ['', 'S-']
                silent var out: string = execute(
                    'verbose ' .. mode .. 'map <' .. modifier .. 'F' .. i .. '>',
                    '')
                if out !~ pat
                    lines += split(out, '\n')
                endif
            endfor
        endfor
    endfor
    debug#log#output({excmd: 'Mappings using function keys', lines: lines})
enddef


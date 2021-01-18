vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#mappings#usingFunctionKeys() #{{{1
    var pat: string = '\cno mapping found'
    var lines: list<string> = ['']
    for i in range(1, 37)
        for mode in ['n', 'v', 'o', 'i', 'c']
            for modifier in ['', 's-']
                sil var out: string = execute(
                    'verb ' .. mode .. 'no <' .. modifier .. 'f' .. i .. '>',
                    '')
                if out !~ pat
                    lines += split(out, '\n')
                endif
            endfor
        endfor
    endfor
    debug#log#output({excmd: 'Mappings using function keys', lines: lines})
enddef


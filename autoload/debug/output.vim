vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#output#lastExCommand(): string #{{{1
    setreg('o', GetOutput(), 'c')
    return '"o]p'
enddef

def GetOutput(): string #{{{1
    try
        # We remove the first newline, so that we can insert the output of a command
        # inline, and not on the next line.
        return histget(':')->execute()->substitute('\n', '', '')
    catch
        # If the last command failed and produced an error, it will fail again.
        # But we still want something to be inserted: the error message(s).
        var messages: list<string> = execute('messages')->split('\n')->reverse()
        var idx: number = match(messages, '^E\d\+')
        remove(messages, idx + 1, -1)
        return messages
            ->filter((_, v: string): bool => v =~ '\C^E\d\+')
            ->reverse()
            ->join("\n")
    endtry
    return ''
enddef


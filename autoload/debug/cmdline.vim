vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#cmdline#evalVarUnderCursor(): string #{{{1
    var cmdline: string = getcmdline()
    var pos: number = getcmdpos()
    var pat: string =
        # make sure the matched variable name is the one where our cursor is
        '\%(\w\|:\)*\%' .. pos .. 'c\%(\w\|:\)\+\&'
        # a variable name
        .. '\([bwtgv]:\)\=\%(\a\w*\)'
    #}}}
    var var_name: string = matchstr(cmdline, pat)
    if var_name !~ ':'
        var_name = 'g:' .. var_name
    endif
    if !exists(var_name)
        return cmdline
    endif
    var text_until_var: string = matchstr(cmdline,
        '.*[^a-zA-Z0-9_:]\ze\%(\w\|:\)*\%' .. pos .. 'c\%(\w\|:\)*')
    # Why `string()`?{{{
    #
    # If the value of  the variable is a string, we want it  to be quoted on the
    # command-line.
    # If  it's not,  it  needs to  be  converted into  a  string, otherwise  the
    # substitution would fail.
    #}}}
    Rep = () => eval(var_name)->string()
    var new_pos: number
    if eval(var_name)->type() == v:t_string
        new_pos = strlen(text_until_var .. eval(var_name)) + 3
    else
        new_pos = strlen(text_until_var .. eval(var_name)->string()) + 1
    endif
    var new_cmdline: string = substitute(cmdline, pat, Rep, '')
    setcmdpos(new_pos)
    # allow us to undo the evaluation
    if exists('#User#AddToUndolistC')
        do <nomodeline> User AddToUndolistC
    endif
    return new_cmdline
enddef

var Rep: func(): string

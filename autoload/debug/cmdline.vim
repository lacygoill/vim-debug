fu! debug#cmdline#eval_var_under_cursor() abort "{{{1
    let cmdline = getcmdline()
    let pos = getcmdpos()
    let pat = '\%(\w\|:\)*\%'.pos.'c\%(\w\|:\)\+\&'.'\([bwtgv]:\)\=\%(\a\w*\)'
    "         ├───────────────────────────────────┘ ├────────────────────────┘{{{
    "         │                                     └ a variable name
    "         │
    "         └ make sure the matched variable name is the one where our cursor is
    "}}}
    let var_name = matchstr(cmdline, pat)
    if var_name !~# ':'
        let var_name = 'g:'.var_name
    endif
    if !exists(var_name)
        return cmdline
    endif
    let text_until_var = matchstr(cmdline, '.*[^a-zA-Z0-9_:]\ze\%(\w\|:\)*\%'.pos.'c\%(\w\|:\)*')
    " Why `string()`?{{{
    "
    " If the value of  the variable is a string, we want it  to be quoted on the
    " command-line.
    " If  it's not,  it  needs to  be  converted into  a  string, otherwise  the
    " substitution would fail.
    "}}}
    let rep = '\=string(eval(var_name))'
    if type(eval(var_name)) == type('')
        let new_pos = strlen(text_until_var . eval(var_name)) + 3
    else
        let new_pos = strlen(text_until_var . string(eval(var_name))) + 1
    endif
    let new_cmdline = substitute(cmdline, pat, rep, '')
    call setcmdpos(new_pos)
    " allow us to undo the evaluation
    if exists('#User#add_to_undolist_c')
        do <nomodeline> User add_to_undolist_c
    endif
    return new_cmdline
endfu


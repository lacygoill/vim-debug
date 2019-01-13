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
    let new_pos = strlen(text_until_var) + strlen(eval(var_name)) + 1
    " if the value of the variable is a string,
    " we want it to be quoted on the command-line
    if type(eval(var_name)) == type('')
        let rep = '\=string(eval(var_name))'
        let new_pos += 2
    else
        let rep = '\=eval(var_name)'
    endif
    let new_cmdline = substitute(cmdline, pat, rep, '')
    call setcmdpos(new_pos)
    " allow us to undo the evaluation
    if exists('#User#add_to_undolist_c')
        do <nomodeline> User add_to_undolist_c
    endif
    return new_cmdline
endfu


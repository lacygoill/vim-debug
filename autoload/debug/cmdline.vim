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
    let new_pos = strlen(matchstr(cmdline, '.*\%(\w\|:\)*\%'.pos.'c\%(\w\|:\)*'))
    if type(var_name) == type('')
        let rep = '\=string(eval(var_name))'
        let new_pos += 1
    else
        let rep = '\=eval(var_name)'
    endif
    let new_cmdline = substitute(cmdline, pat, rep, '')
    call setcmdpos(new_pos)
    if exists('#User#add_to_undolist_c')
        do <nomodeline> User add_to_undolist_c
    endif
    return new_cmdline
endfu


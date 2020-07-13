" Interface {{{1
fu debug#terminfo#main(use_curfile) abort "{{{2
    if a:use_curfile
        call s:set_ft()
    else
        call s:split_window()
    endif

    call s:dump_termcap(a:use_curfile)
    call s:split_codes()
    call s:separate_terminal_keys_without_options()
    call s:move_keynames_into_inline_comments()
    call s:add_assignment_operators()
    call s:align_inline_comment()
    call s:add_set_commands()
    call s:escape_spaces_in_options_values()
    call s:trim_trailing_whitespace()
    call s:translate_special_keys()
    call s:sort_lines()
    call s:comment_section_headers()
    call s:fold()
    call s:install_mappings()

    sil! update
    "  │
    "  └ error if we don't have our autocmd which creates a missing directory
endfu
"}}}1
" Core {{{1
fu s:set_ft() abort "{{{2
    if &ft isnot# 'vim'
        set ft=vim
    endif
endfu

fu s:split_window() abort "{{{2
    let tempfile = tempname()..'/termcap.vim'
    exe 'sp '..tempfile
endfu

fu s:dump_termcap(use_curfile) abort "{{{2
    if !a:use_curfile
        call setline(1, split(execute('set termcap'), '\n'))
    endif
    " The bang after silent is necessary to suppress `E486` in gVim, where there
    " may be no `Terminal keys` section.
    1put ='' | sil! 1/Terminal keys/put! ='' | sil! 1/Terminal keys/put =''
    sil keepj keepp %s/^ *//e
endfu

fu s:split_codes() abort "{{{2
    " split terminal codes; one per line
    sil! keepj keepp 1,/Terminal keys\|\%$/s/ \{2,}/\r/ge
    "                                ├───┘
    "                                └ to support the GUI where there is no "Terminal keys" section

    if !search('Terminal keys', 'n')
        return
    endif
    " split terminal keys; one per line
    sil! keepj keepp /Terminal keys/,$s/ \zet_\S*/\r/ge
    sil! keepj keepp /Terminal keys/,$s/\%(<.\{-}>.*\)\@<=<\S\{-1,}> \+.\{-}\ze\%( <.\{-1,}> \+\S\|$\)/\r&/ge
    " Why this second substitution?{{{
    "
    " To handle terminal keys which are not associated to a terminal option.
    "
    "     t_k; <F10>       ^[[21~         <á>        ^[a            <ú>        ^[z
    "
    "     →
    "
    "     t_k; <F10>       ^[[21~ 
    "     <á>        ^[a
    "     <ú>        ^[z
    "}}}
endfu

fu s:separate_terminal_keys_without_options() abort "{{{2
    " move terminal keys not associated to any terminal option at the end of the buffer
    sil! keepj keepp /Terminal keys/,$g/^</m$
    " separate them from the terminal keys associated with a terminal option{{{
    "
    "     t_kP <PageUp>    ^[[5~ 
    "     <í>        ^[m
    "
    "     →
    "
    "     t_kP <PageUp>    ^[[5~ 
    "
    "     <í>        ^[m
    "}}}
    sil! 1/^<\%(.*" t_\S\S\)\@!/put! =''
endfu

fu s:move_keynames_into_inline_comments() abort "{{{2
    "     t_#2 <S-Home>    ^[[1;2H
    "     →
    "     <S-Home>    ^[[1;2H  " t_#2
    sil! keepj keepp /Terminal keys/,$s/^\(t_\S\+ \+\)\(<.\{-1,}>\)\(.*\)/\2\3" \1/e
endfu

fu s:add_assignment_operators() abort "{{{2
    " Only necessary for terminal keys (not codes):
    "
    "     <S-Home>    ^[[1;2H  " t_#2
    "     →
    "     <S-Home>=^[[1;2H  " t_#2
    sil! keepj keepp /Terminal keys/,$s/^<.\{-1,}>\zs \+/=/e
endfu

fu s:align_inline_comment() abort "{{{2
    if exists(':EasyAlign') != 2
        return
    endif

    "     <S-Home>=^[[1;2H  " t_#2
    "     <F4>=^[OS     " t_k4
    "
    "     →
    "
    "     <S-Home>=^[[1;2H " t_#2
    "     <F4>=^[OS        " t_k4

    " What's this argument `{'ig': []}`?{{{
    "
    " By default, `:EasyAlign` ignores a delimiter in a comment.
    " This prevents our alignment from being performed.
    " We fix this by passing to `:EasyAlign` the optional argument `{'ig': []}`,
    " which tells it to ignore nothing.
    "}}}
    sil! keepj keepp /Terminal keys/+,$EasyAlign /"/ {'ig': []}
endfu

fu s:add_set_commands() abort "{{{2
    sil keepj keepp %s/^\ze\%(t_\|<\)/set /e
endfu

fu s:escape_spaces_in_options_values() abort "{{{2
    "     set t_EI=^[[2 q
    "     →
    "     set t_EI=^[[2\ q
    "                  ^
    sil keepj keepp %s/\%(set.\{-}=.*[^"]\)\@<= [^" ]/\\&/ge
endfu

fu s:trim_trailing_whitespace() abort "{{{2
    sil! keepj keepp /Terminal keys/,$s/ \+$//e
endfu

fu s:translate_special_keys() abort "{{{2
    " translate caret notation of control characters
    sil keepj keepp %s/\^\[/\="\e"/ge
    sil keepj keepp %s/\^\(\u\)/\=eval('"'..'\x'..(char2nr(submatch(1)) - 64)..'"')/ge
    sil keepj keepp %s/\^?/\="\x7f"/ge

    "     <á>=^[a    →    <M-a>=^[a
    sil keepj keepp %s/^set <\zs.\ze>=\e\(\l\)/M-\1/e
endfu

fu s:sort_lines() abort "{{{2
    " sort terminal codes: easier to find a given terminal option name
    " sort terminal keys: useful later when vimdiff'ing the output with another one
    sil! keepj 1/Terminal codes/+,/Terminal keys/--sort
    sil! keepj 1/Terminal keys/++;/^$/-sort
    sil! keepj 1/Terminal keys//^$//^$/+;$sort
endfu

fu s:comment_section_headers() abort "{{{2
    "     --- Terminal codes ---    →    " Terminal codes
    "     --- Terminal keys ---     →    " Terminal keys
    sil keepj keepp %s/^--- Terminal \(\S*\).*/" Terminal \1/e
endfu

fu s:fold() abort "{{{2
    sil keepj keepp %s/^" .*\zs/\=' {{'..'{1'/e
endfu

fu s:install_mappings() abort "{{{2
    nno <buffer><expr><nowait><silent> q reg_recording() isnot# '' ? 'q' : ':<c-u>q!<cr>'
    " mapping to compare value on current line with the one in output of `:set termcap`{{{
    "
    " Note that  `:filter` is able  to filter the "Terminal  codes" section,
    " but not the "Terminal keys" section.
    " So, no  matter the line  where you press  `!!`, you'll always  get the
    " whole "Terminal codes" section.
    " The  mapping is  still useful:  if you  press `!!`  on a  line in  the
    " "Terminal codes" section,  it will correctly filter out  all the other
    " terminal codes.
    "}}}
    nno <buffer><nowait><silent> !!
        \ :<c-u>exe 'filter /'.. matchstr(getline('.'), 't_[^=]*') ..'/ set termcap'<cr>
    " open relevant help tag to get more info about the terminal option under the cursor
    nno <buffer><nowait><silent> <cr> :<c-u>call <sid>get_help()<cr>
    " get help about mappings
    nno <buffer><nowait><silent> g? :<c-u>call <sid>print_help()<cr>
endfu

fu s:get_help() abort "{{{2
    let tag = matchstr(getline('.'), '\%(^set \|" \)\@4<=t_[^=]*')
    if tag isnot# ''
        try
            exe "h '"..tag
        " some terminal options have no help tags (e.g. `'t_FL'`)
        catch /^Vim\%((\a\+)\)\=:E149:/
            echohl ErrorMsg
            echom v:exception
            echohl NONE
        endtry
    else
        echo 'no help tag on this line'
    endif
endfu

fu s:print_help() abort "{{{2
    let help =<< trim END
        Enter    open relevant help tag to get more info about the terminal option under the cursor
        !!       compare value on current line with the one in output of `:set termcap`
        g?       print this help
    END
    echo join(help, "\n")
endfu


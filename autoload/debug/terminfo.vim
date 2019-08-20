" Interface {{{1
fu! debug#terminfo#main() abort "{{{2
    if has('nvim') | call s:dump_nvim_terminfo() | return | endif

    call s:split_window()
    call s:dump_termcap()
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
fu! s:dump_nvim_terminfo() abort "{{{2
    " Issue: To get Nvim's terminfo internal db, we need to start `$ nvim -V3/tmp/log`.
    " But we can't do that from `system()` nor `jobstart()`.
    " Solution: Start Nvim in a temporary tmux window.

    " FIXME: How to support Neovim outside tmux?{{{
    "
    " In the shell, this works:
    "
    "     $ nvim -V3/tmp/log +'call timer_start(0, {-> execute("q")})' && \
    "       nvim -es +'exe "1,/{{\\%x7b$/g/^/d_" | /}}\%x7d$/,$g/^/d_' +'%p | qa!' /tmp/log
    "
    " Note that in the first Nvim command,  you can't use `-e`, and you must use
    " a timer to delay `:q`, to let the builtin UI start up:
    "
    " > invoke :q  manually, so that  the builtin UI  has a chance  to start
    " > up. Don't add -c "q" in the command-line args.
    "
    " Source:
    " https://github.com/neovim/neovim/issues/9270#issuecomment-441371260
    "
    " ---
    "
    " To integrate these 2 shell  commands in our `:TermcapDump` command, we
    " would need to use sth like `system()` or `jobstart()`.
    " But both of them fail to display Nvim's internal terminfo db:
    "
    "     :let shell_cmd = 'nvim -V3/tmp/log +''call timer_start(0, {-> execute("q")})'''
    "     :let cmd = ['/bin/bash', '-c', shell_cmd]
    "     :call jobstart(cmd)
    "     :sp /tmp/log
    "     /terminal
    "     E486~
    "
    "     :let cmd = 'nvim -V3/tmp/log +''call timer_start(0, {-> execute("q")})'''
    "     :call system(cmd)
    "     :sp /tmp/log
    "     /terminal
    "     E486~
    "
    " I think that's because Nvim sees that it's not attached to a terminal,
    " and  so has  no need  to start  up  its UI,  nor to  set its  internal
    " terminfo database.
    "}}}
    if !exists('$TMUX') | echo 'Requires tmux' | return | endif

    " Don't add a path component in the name of the temporary file.{{{
    "
    "     let tempfile = tempname()..'/foo'
    "                                 ^
    "                                 ✘
    "
    " It would cause  a pager to be opened, and you would  need to press keys to
    " get rid of it.
    " I think it's because `E484` is raised; the message can be seen only at the end:
    "
    "     $ nvim -V3/tmp/nvimLKeZX6/1/foo
    "     ...~
    "     E484: Can't open file /tmp/nvimLKeZX6/1/foo~
    "
    " Our autocmd which  automatically creates a missing  directory doesn't seem
    " to help here.
    "}}}
    let tempfile = tempname()
    let target_pane = system("tmux neww -PF '#S:#I.#P' 'nvim -V3"..tempfile.."'")[:-2]
    " Don't reduce this sleeping time too much.{{{
    "
    " Nvim's builtin UI needs some time to start up.
    "
    " https://github.com/neovim/neovim/issues/9270#issuecomment-441371260
    "}}}
    sleep 300m
    call system('tmux send -t '..shellescape('='..target_pane) .. " ':q' 'Enter'")
    exe 'sp '..tempfile

    " remove irrelevant lines
    sil keepj keepp 1,/{{\%x7b$/g/^/d_
    sil keepj keepp 1/}}\%x7d$/,$g/^/d_

    " try to add folding
    sil keepj keepp g/^\u.* capabilities:$/t. | keepp s/./-/g
    " Don't move the update after the folding.{{{
    "
    " It would cause `fold#logfile#main()` to raise an error, because it reloads
    " the buffer to apply the new folding options.
    "}}}
    sil update
    try | call fold#logfile#main() | catch | call lg#catch_error() | endtry

    call s:install_mappings()
endfu

fu! s:split_window() abort "{{{2
    let tempfile = tempname()..'/termcap.vim'
    exe 'sp '..tempfile
endfu

fu! s:dump_termcap() abort "{{{2
    call setline(1, split(execute('set termcap'), '\n'))
    1put ='' | 1/Terminal keys/put! ='' | 1/Terminal keys/put =''
    sil keepj keepp %s/^ *//e
endfu

fu! s:split_codes() abort "{{{2
    " split terminal codes; one per line
    sil keepj keepp 1,/Terminal keys/s/ \{2,}/\r/ge

    " split terminal keys; one per line
    sil keepj keepp /Terminal keys/,$s/ \zet_\S*/\r/ge
    sil keepj keepp /Terminal keys/,$s/\%(<.\{-}>.*\)\@<=<\S\{-1,}> \+.\{-}\%( <.\{-1,}> \+\S\|$\)\@=/\r&/ge
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

fu! s:separate_terminal_keys_without_options() abort "{{{2
    " move terminal keys not associated to any terminal option at the end of the buffer
    sil keepj keepp /Terminal keys/,$g/^</m$
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
    1/^<\%(.*" t_\S\S\)\@!/put! =''
endfu

fu! s:move_keynames_into_inline_comments() abort "{{{2
    "     t_#2 <S-Home>    ^[[1;2H
    "     →
    "     <S-Home>    ^[[1;2H  " t_#2
    sil keepj keepp /Terminal keys/,$s/^\(t_\S\+ \+\)\(<.\{-1,}>\)\(.*\)/\2\3" \1/e
endfu

fu! s:add_assignment_operators() abort "{{{2
    " Only necessary for terminal keys (not codes):
    "
    "     <S-Home>    ^[[1;2H  " t_#2
    "     →
    "     <S-Home>=^[[1;2H  " t_#2
    sil keepj keepp /Terminal keys/,$s/^<.\{-1,}>\zs \+/=/e
endfu

fu! s:align_inline_comment() abort "{{{2
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
    " We fix this by passing `:EasyAlign`  the optional argument `{'ig': []}` to
    " tell it to ignore nothing.
    "}}}
    sil keepj keepp /Terminal keys/+,$EasyAlign /"/ {'ig': []}
endfu

fu! s:add_set_commands() abort "{{{2
    sil keepj keepp %s/^\ze\%(t_\|<\)/set /e
endfu

fu! s:escape_spaces_in_options_values() abort "{{{2
    "     set t_EI=^[[2 q
    "     →
    "     set t_EI=^[[2\ q
    "                  ^
    sil keepj keepp %s/\%(set.\{-}=.*[^"]\)\@<= [^" ]/\\&/ge
endfu

fu! s:trim_trailing_whitespace() abort "{{{2
    sil keepj keepp /Terminal keys/,$s/ \+$//e
endfu

fu! s:translate_special_keys() abort "{{{2
    " translate caret notation of control characters
    sil keepj keepp %s/\^\[/\="\e"/ge
    sil keepj keepp %s/\^\(\u\)/\=eval('"'..'\x'..(char2nr(submatch(1)) - 64)..'"')/ge
    sil keepj keepp %s/\^?/\="\x7f"/ge

    "     <á>=^[a    →    <M-a>=^[a
    sil keepj keepp %s/^set <\zs.\{-1,}\ze>=\e\(\l\)/M-\1/e
endfu

fu! s:sort_lines() abort "{{{2
    " sort terminal codes: easier to find a given terminal option name
    " sort terminal keys: useful later when vimdiff'ing the output with another one
    sil keepj 1/Terminal codes/+,/Terminal keys/--sort
    sil keepj 1/Terminal keys/++;/^$/-sort
    sil keepj 1/Terminal keys//^$//^$/+;$sort
endfu

fu! s:comment_section_headers() abort "{{{2
    "     --- Terminal codes ---    →    " Terminal codes
    "     --- Terminal keys ---     →    " Terminal keys
    sil keepj keepp %s/^--- Terminal \(\S*\).*/" Terminal \1/e
endfu

fu! s:fold() abort "{{{2
    sil keepj keepp %s/^" .*\zs/\=' {{'..'{1'/e
endfu

fu! s:install_mappings() abort "{{{2
    nno <buffer><expr><nowait><silent> q reg_recording() isnot# '' ? 'q' : ':<c-u>q!<cr>'

    if !has('nvim')
        " mapping to compare value on current line with the one in output of `:set termcap`{{{
        "
        " Note that  `:filter` is able  to filter the "Terminal  codes" section,
        " but not the "Terminal keys" section.
        " So, no  matter the line where  you press Enter, you'll  always get the
        " whole "Terminal codes" section.
        " The mapping  is still  useful: if  you press  Enter on  a line  in the
        " "Terminal codes" section,  it will correctly filter out  all the other
        " terminal codes.
        "}}}
        nno <buffer><nowait><silent> <cr>
            \ :<c-u>exe 'filter /'.. matchstr(getline('.'), 't_[^=]*') ..'/ set termcap'<cr>
    endif
endfu


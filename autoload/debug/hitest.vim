" Where does the code in this script come from?{{{
"
"     $VIMRUNTIME/syntax/hitest.vim
"}}}
" What does it do?{{{
"
" Print your current highlight groups.
" And for each, list all the syntax groups which are linked to it.
"}}}
" Why don't you use the original script?{{{
"
" It contains a few errors:
"
"     • `:normal` instead of `normal!`
"      (which causes an issue because of a custom mapping installed by `vim-search`)
"
"     • doesn't temporarily reset 'ww'
"     (which causes an issue because we do `set ww=h,l` in our vimrc)
"}}}


fu! debug#hitest#main() abort "{{{1
    call s:options_save()
    call s:options_set()

    " Open a new window if the current one isn't empty
    if line('$') != 1 || getline(1) != ''
        new
    endif

    sil exe 'edit '.tempname()

    setl noswf noet sw=16 ts=16
    let &l:tw = &columns

    " insert highlight settings
    %d_
    put =execute('hi')

    " remove the colored xxx items
    keepj keepp %s/xxx//e

    " remove color settings (not needed here)
    keepj keepp v/links to/ keepj keepp s/\s.*$//e

    " move linked groups to the end of file
    keepj keepp g/links to/m$

    " reverse order in the links:{{{
    "
    "     markdownH1      links to Title
    "     →
    "     Title	links to markdownH1
    "}}}
    keepj keepp %s/^\(\w\+\)\s*\(links to\)\s*\(\w\+\)$/\3\t\2 \1/e
    " group all the syntax groups which are linked to the same HG on the same line
    keepj keepp g/links to/keepp norm! mz3ElD0#$p'zdd
    "                                  ├┘├─┘│││├┘├┘├┘{{{
    "                                  │ │  ││││ │ └ we don't this line anymore, remove it
    "                                  │ │  ││││ │
    "                                  │ │  ││││ └ get back where we were
    "                                  │ │  ││││
    "                                  │ │  │││└ paste the syntax group at the end of the line
    "                                  │ │  │││
    "                                  │ │  │││  we're progressively building the set of syntax groups
    "                                  │ │  │││  which are linked to the same HG:
    "                                  │ │  │││
    "                                  │ │  │││          Title
    "                                  │ │  │││          Title MarkdownH1
    "                                  │ │  │││          Title MarkdownH1 MarkdownH2
    "                                  │ │  │││          ...
    "                                  │ │  │││
    "                                  │ │  ││└ move to the previous occurrence of the syntax group name
    "                                  │ │  ││
    "                                  │ │  │└ the syntax group we've just deleted is linked to a HG (e.g. `Title`)
    "                                  │ │  │  move to the beginning of the line, where the latter is written
    "                                  │ │  │
    "                                  │ │  └ delete the syntax group name
    "                                  │ │
    "                                  │ └ move to the beginning of the syntax group name
    "                                  │   (e.g. `markdownH1`)
    "                                  │
    "                                  └ remember where we are
    "}}}

    " delete empty lines
    keepj keepp g/^ *$/d_

    " precede syntax command
    keepj keepp %s/^[^ ]*/syn keyword &\t&/

    " execute syntax commands
    syn clear | sil update | so% | setl bt=nofile

    " remove syntax commands again
    keepj keepp %s/^syn keyword //

    call s:pretty_formatting()
    call s:options_restore()
endfu

fu! s:pretty_formatting() abort "{{{1
    keepj keepp g/^/exe "norm! Wi\r\t\egww"
    keepj keepp g/^\S/j

    " find out first syntax highlighting
    let various = &highlight . ',:Normal,:Cursor,:,'
    let i = 1
    while various =~ ':'.substitute(getline(i), '\s.*$', ',', '')
        let i += 1
        if i > line('$') | break | endif
    endwhile

    " insert headlines
    call append(0, ['Highlight groups for various occasions', '--------------------------------------'])

    if i < line('$')-1
        call append(i+1, ['', 'Syntax highlighting groups', '--------------------------'])
    endif

    call cursor(1,1)
endfu

fu! s:options_save() abort "{{{1
    let s:report   = &report
    let s:wrapscan = &wrapscan
    let s:ww       = &ww
endfu

fu! s:options_set() abort "{{{1
    " be silent when we execute substitutions, deletions, ...
    set report=99999
    " could be necessary for `norm! ...#...` later
    set wrapscan
    " necessary for `norm! ...l...` later
    set ww&vim
endfu

fu! s:options_restore() abort "{{{1
    let &report   = s:report
    let &wrapscan = s:wrapscan
    let &ww       = s:ww
    unlet! s:report s:wrapscan s:ww
endfu
" }}}1


if exists('g:loaded_debug')
    finish
endif
let g:loaded_debug = 1

" autocmd {{{1

augroup my_debug
    au!
    au FileType vim call debug#break_setup()
augroup END

" commands {{{1

" Purpose:{{{
"
" Our custom <cr> mapping prevents us from using `:debug`.
" Don't even try, you wouldn't be able to quit debug mode.
" We install `:Debug` as a thin wrapper which temporarily removes our mapping.
"}}}
" What happens if we use a custom mapping while in debug mode?{{{
"
" You'll see  the first  line of  the function  which it  calls (it  happens for
" example with `c-t` ; transpose-chars).  And, you'll step through it.
"}}}
" What to do in this case?{{{
"
" Execute `cont` to get out.
"
" If you have used one of our custom editing command several times, you'll
" have to re-execute `cont` as many times as needed.
"}}}
com! -bar -nargs=1 Debug call debug#wrapper(<q-args>)

" Purpose:
" Automate the process of finding a bug in our vimrc through a binary search.
com! -bar DebugVimrc exe debug#vimrc()

com! -bang -bar -nargs=* -complete=customlist,debug#runtime_complete Runtime
\                                                                    exe debug#runtime_command(<bang>0, <f-args>)

com! -bar Scriptnames  call debug#scriptnames()

com! -range=1 -nargs=+ -complete=command Time call debug#time(<q-args>, <count>)
"    │
"    └─ tpope uses `-count=1` instead of `-range=1`
"
"       It allows the user  to give the count as as  an initial argument:
"
"               :Time 42 cmd
"
"       … in addition to a prefix (`:42Time cmd`).
"
"       I prefer `-range=1`: only works as a prefix. I will never use the
"       other syntax anyway.

com! -bar -nargs=1 -complete=option Vo echo 'local: '
\|                                     verb setl <args>?
\|                                     echo "\nglobal: "
\|                                     verb setg <args>?

" mappings {{{1
" -e        show help about last error {{{2

" Description:
" You execute some function/command which raises one or several errors.
" Press `-e` to open the help topic explaining the last one.
" Repeat to cycle through all the help topics related to the rest of the errors.

"                      ┌ info
"                      │┌ error
"                      ││
nno  <silent><unique>  -e  :<c-u>exe debug#help_about_last_errors()<cr>

" g?        show messages {{{2

nno  <silent><unique>  g?  :<c-u>call debug#messages()<cr>

" zs        show syntax groups under cursor {{{2

" Usage:
" all these commands apply to the character under the cursor
"
"     zs     show the names of all syntax groups
"     1zs    show the definition of the innermost syntax group
"     3zs    show the definition of the 3rd syntax group

nno  <silent><unique>  zs  :<c-u>call debug#synnames_map(v:count)<cr>

" By default, what do `zs` and `ze` do?{{{
"
" When 'wrap' is off,  and the cursor is on a long line,  a few characters after
" the beginning of the line (column 7?), `zs` will move the viewport so that the
" current character is near the start of the line.
" `ze` do the same,  but it moves the viewport so that  the current character is
" near the end of the line.
"}}}
" We've just lost the default `zs` command. Restore it on `zS`.
nno  <unique>  zS  zs
" For consistency's sake, do the same for `ze`.
nno  <unique>  zE  ze

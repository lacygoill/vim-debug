" guard {{{1

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
com! -bar -nargs=1 Debug exe debug#wrapper(<q-args>)

com! -bang -bar -nargs=* -complete=customlist,debug#complete_runtime Runtime
\                                                                    exe debug#runtime_command(<bang>0, <f-args>)

com! -bar Scriptnames  call debug#scriptnames()

com! -range=1 -nargs=+ -complete=command Time exe debug#time(<q-args>, <count>)
"    │
"    └─ tpope uses `-count=1` instead of `-range=1`
"
"       It allows the user to give the count as a prefix (`:42Time cmd`) or as an
"       initial argument (`:Time 42 cmd`).
"
"       I prefer `-range=1`: only works as a prefix. I will never use the
"       other syntax anyway.

com! -bar -nargs=1 -complete=option Vov echo 'local: '
\|                                      verb setl <args>?
\|                                      echo "\nglobal: "
\|                                      verb setg <args>?

" mappings {{{1

nno <silent>  g?   :<c-u>call debug#messages()<cr>

" Usage:
" all these commands apply to the character under the cursor
"
"     zs     show the names of all syntax groups
"     1zs    show the definition of the innermost syntax group
"     3zs    show the definition of the 3rd syntax group

nno <silent>  zs   :<c-u>call debug#synnames_map(v:count)<cr>

" We've just lost the default `zs` command. Restore it on `zS`.
nno zS zs
" For consistency's sake, do the same for `ze`.
nno zE ze

" NOTE:
" What do `zs` and `ze` do?
" When 'wrap' is off, and the cursor is on a long line, a few characters after
" the beginning of the line (column 7?), `zs` will move the viewport so that the
" current character is near the start of the line.
" `ze` do the same, but it moves the viewport so that the current character is
" near the end of the line.

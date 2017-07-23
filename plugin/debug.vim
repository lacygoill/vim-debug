" autocmd {{{1

augroup my_debug
    au!
    au FileType vim call debug#break_setup()
augroup END

" commands {{{1

com! -bar Scriptnames  call debug#scriptnames()

"                                             ┌─ If we execute the function (like tpope does),
"                                             │  we have to make it return an empty string.
"                                             │  Otherwise, by default, it will return 0, which makes
"                                             │  the cursor move on line 0 (1st line of buffer).
"                                             │
com! -range=1 -nargs=+ -complete=command Time call debug#time(<q-args>, <count>)
"    │
"    └─ tpope uses `-count=1` instead of `-range=1`
"
"       It allows the user to give the count as a prefix (`:42Time cmd`) or as an
"       initial argument (`:Time 42 cmd`).
"
"       I prefer `-range=1`: only works as a prefix. I will never use the
"       other syntax anyway.

" mappings {{{1

nno <silent>  g?   :<c-u>call debug#messages()<cr>

" Usage:
" all these commands apply to the character under the cursor
"
"     ZS     show the names of all syntax groups
"     1ZS    show the definition of the innermost syntax group
"     3ZS    show the definition of the 3rd syntax group

nno <silent>  ZS   :<c-u>call debug#synnames_map(v:count)<cr>

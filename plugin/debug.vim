if exists('g:loaded_debug')
    finish
endif
let g:loaded_debug = 1

" autocmds {{{1

augroup my_debug
    au!
    au FileType vim call debug#break_setup()
augroup END

augroup timer_info_populate
    au!
    au BufNewFile /tmp/*/timer_info call debug#timer#populate()
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

" Purpose:{{{
" Wrapper around commands such as `:breakadd file */ftplugin/sh.vim`.
" Provides a usage message, and smart completion.
"
" Useful to debug a filetype/indent/syntax plugin.
"}}}
com! -bar -complete=custom,debug#local_plugin#complete -nargs=* DebugLocalPlugin  call debug#local_plugin#main(<q-args>)

" Purpose:
" Automate the process of finding a bug in our vimrc through a binary search.
com! -bar DebugVimrc exe debug#vimrc()

" FIXME: Where is `debug#runtime_command()`?
" And why do we need `<f-args>` (instead of `<q-args>`)?
com! -bang -bar -nargs=* -complete=customlist,debug#runtime_complete Runtime
    \ exe debug#runtime_command(<bang>0, <f-args>)

com! -bar Scriptnames  call debug#scriptnames()

com! -count=1 -nargs=+ -complete=command Time call debug#time(<q-args>, <count>)

" Do NOT give the `-bar` attribute to `:Verbose`.{{{
"
" It would  prevent it  from working  correctly when  the command  which follows
" contains a bar:
"
"         :4Verbose cgetexpr system('grep -RHIinos pat * \| grep -v garbage')
"}}}
com! -count=1 -nargs=1 -complete=command  Verbose
    \ call debug#log#output({'level': <count>, 'excmd': <q-args>})

com! -bar -nargs=1 -complete=option Vo echo 'local: '
    \ |    verb setl <args>?
    \ |    echo "\nglobal: "
    \ |    verb setg <args>?

" mappings {{{1
" g!        last page in the output of last command {{{2

" Why?{{{
"
" `g!` is easier to type.
" `g<` could be used with `g>` to perform a pair of opposite actions.
"}}}
nno  <unique>  g!  g<

" !c        capture variable {{{2

" This mapping is useful to create a copy of a variable local to a function or a
" script into the global namespace, for debugging purpose.

nno  <silent><unique>  !c  :<c-u>set opfunc=debug#capture_variable<cr>g@l

" !d        echo g:d_* {{{2

" typing `:echo debug` gets old really fast
nno  <silent><unique>  !d  :<c-u>call debug#dump_debugging_variables()<cr>

" !e        show help about last error {{{2

" Description:
" You execute some function/command which raises one or several errors.
" Press `-e` to open the help topic explaining the last one.
" Repeat to cycle through all the help topics related to the rest of the errors.

"                       ┌ error
"                       │
nno  <silent><unique>  !e  :<c-u>exe debug#help_about_last_errors()<cr>

" !m        show messages {{{2

nno  <silent><unique>  !m  :<c-u>call debug#messages()<cr>

" !M        clean messages {{{2

" Why not `SPC c`?{{{
"
" Because in filetype  plugins (latex, shell), we often use  `bar c` for various
" purposes, like compiling or checking errors.
"}}}
nno  <silent><unique>  !M  :<c-u>messages clear <bar> echo 'messages cleared'<cr>

" !s        show syntax groups under cursor {{{2

" Usage:
" all these commands apply to the character under the cursor
"
"     !s     show the names of all syntax groups
"     1!s    show the definition of the innermost syntax group
"     3!s    show the definition of the 3rd syntax group

nno  <silent><unique>  !s  :<c-u>call debug#synnames_map(v:count)<cr>

" !t        show info about running timers {{{2

nno  <silent><unique>  !t  :<c-u>call debug#timer#info_open()<cr>


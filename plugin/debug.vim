if exists('g:loaded_scriptease')
  finish
endif
let g:loaded_scriptease = 1

" Commands {{{1

com! -bang -range=-1 -nargs=? -complete=expression PP    call debug#pp(<q-args>, <bang>0, <count>)
com! -bang -range=0  -nargs=? -complete=expression PPmsg call debug#ppmsg()

com! -bar -bang Messages exe debug#messages_command(<bang>0)

com! -bang -bar -nargs=* -complete=customlist,debug#complete Runtime
            \ exe debug#runtime_command('<bang>', <f-args>)

com! -bang -bar -nargs=* -complete=customlist,debug#complete Disarm
            \ exe debug#disarm_command(<bang>0, <f-args>)

com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Ve
            \ exe debug#open_command(<count>,'edit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vedit
            \ exe debug#open_command(<count>,'edit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vopen
            \ exe debug#open_command(<count>,'edit<bang>',<q-args>,1)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vsplit
            \ exe debug#open_command(<count>,'split',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vvsplit
            \ exe debug#open_command(<count>,'vsplit',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vtabedit
            \ exe debug#open_command(<count>,'tabedit',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vpedit
            \ exe debug#open_command(<count>,'pedit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,debug#complete Vread
            \ exe debug#open_command(<count>,'read',<q-args>,<bang>0)

" Maps {{{1

nno <silent>  g!   :<c-u>set opfunc=debug#filterop<cr>g@
nno <silent>  g!!  :<c-u>set opfunc=debug#filterop<cr>g@_
xno <silent>  g!   :<c-u>call debug#filterop(visualmode())<cr>

" Filetype {{{1

augroup scriptease
    au!
    au FileType help call debug#setup_help()
    au FileType vim call debug#setup_vim()
augroup END

" Projectionist {{{1

fu! s:projectionist_detect() abort
    let file = get(g:, 'projectionist_file', '')
    let path = substitute(debug#locate(file)[0], '[\/]after$', '', '')
    if !empty(path)
        let reload = ":Runtime ./{open}autoload,plugin{close}/**/*.vim"
        call projectionist#append(path, {
                    \ "*": {"start": reload},
                    \ "*.vim": {"start": reload},
                    \ "plugin/*.vim":   {"command": "plugin", "alternate": "autoload/{}.vim"},
                    \ "autoload/*.vim": {"command": "autoload", "alternate": "plugin/{}.vim"},
                    \ "compiler/*.vim": {"command": "compiler"},
                    \ "ftdetect/*.vim": {"command": "ftdetect"},
                    \ "syntax/*.vim":   {"command": "syntax", "alternate": ["ftplugin/{}.vim", "indent/{}.vim"]},
                    \ "ftplugin/*.vim": {"command": "ftplugin", "alternate": ["indent/{}.vim", "syntax/{}.vim"]},
                    \ "indent/*.vim":   {"command": "indent", "alternate": ["syntax/{}.vim", "ftplugin/{}.vim"]},
                    \ "after/*.vim":    {"command": "after"},
                    \ "doc/*.txt":      {"command": "doc", "start": reload}})
    endif
endfu

augroup scriptease_projectionist
    au!
    au User ProjectionistDetect call s:projectionist_detect()
augroup END

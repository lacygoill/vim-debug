if exists('g:loaded_scriptease')
  finish
endif
let g:loaded_scriptease = 1

" Commands {{{1

com! -bang -range=-1 -nargs=? -complete=expression PP    call scriptease#pp(<q-args>, <bang>0, <count>)
com! -bang -range=0  -nargs=? -complete=expression PPmsg call scriptease#ppmsg()

com! -bar -count=0 Scriptnames
            \  call setqflist(scriptease#scriptnames_qflist())
            \| copen
            \| <count>

com! -bar -bang Messages exe scriptease#messages_command(<bang>0)

com! -bang -bar -nargs=* -complete=customlist,scriptease#complete Runtime
            \ exe scriptease#runtime_command('<bang>', <f-args>)

com! -bang -bar -nargs=* -complete=customlist,scriptease#complete Disarm
            \ exe scriptease#disarm_command(<bang>0, <f-args>)

com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Ve
            \ exe scriptease#open_command(<count>,'edit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vedit
            \ exe scriptease#open_command(<count>,'edit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vopen
            \ exe scriptease#open_command(<count>,'edit<bang>',<q-args>,1)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vsplit
            \ exe scriptease#open_command(<count>,'split',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vvsplit
            \ exe scriptease#open_command(<count>,'vsplit',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vtabedit
            \ exe scriptease#open_command(<count>,'tabedit',<q-args>,<bang>0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vpedit
            \ exe scriptease#open_command(<count>,'pedit<bang>',<q-args>,0)
com! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vread
            \ exe scriptease#open_command(<count>,'read',<q-args>,<bang>0)

" Maps {{{1

nno <silent>  g!   :<c-u>set opfunc=scriptease#filterop<cr>g@
nno <silent>  g!!  :<c-u>set opfunc=scriptease#filterop<cr>g@_
xno <silent>  g!   :<c-u>call scriptease#filterop(visualmode())<cr>

nno <silent>  zS   :<c-u>exe scriptease#synnames_map(v:count)<cr>

" Filetype {{{1

augroup scriptease
    au!
    au FileType help call scriptease#setup_help()
    au FileType vim call scriptease#setup_vim()
augroup END

" Projectionist {{{1

fu! s:projectionist_detect() abort
    let file = get(g:, 'projectionist_file', '')
    let path = substitute(scriptease#locate(file)[0], '[\/]after$', '', '')
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

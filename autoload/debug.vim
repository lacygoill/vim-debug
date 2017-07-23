if exists('g:autoloaded_scriptease')
  finish
endif
let g:autoloaded_scriptease = 1

" Utility {{{1

fu! s:function(name) abort
    return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfu

fu! s:sub(str,pat,rep) abort
    return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfu

fu! s:gsub(str,pat,rep) abort
    return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfu

" Completion {{{1

fu! debug#complete(A,L,P) abort
    let cheats = {
                \ 'a': 'autoload',
                \ 'd': 'doc',
                \ 'f': 'ftplugin',
                \ 'i': 'indent',
                \ 'p': 'plugin',
                \ 's': 'syntax'}
    if a:A =~# '^\w[\\/]' && has_key(cheats,a:A[0])
        let request = cheats[a:A[0]].a:A[1:-1]
    else
        let request = a:A
    endif
    let pattern = substitute(request,'/\|\/','*/','g').'*'
    let found = {}
    for glob in split(&runtimepath, ',')
        for path in map(split(glob(glob), "\n"), 'fnamemodify(v:val, ":p")')
            let matches = split(glob(path.'/'.pattern),"\n")
            call map(matches,'isdirectory(v:val) ? v:val."/" : v:val')
            call map(matches,'fnamemodify(v:val, ":p")[strlen(path)+1:-1]')
            for match in matches
                let found[match] = 1
            endfor
        endfor
    endfor
    return sort(keys(found))
endfu

" :PP, :PPmsg {{{1

let s:escapes = {
            \ "\b": '\b',
            \ "\e": '\e',
            \ "\f": '\f',
            \ "\n": '\n',
            \ "\r": '\r',
            \ "\t": '\t',
            \ "\"": '\"',
            \ "\\": '\\'}

fu! debug#dump(object, ...) abort
    let opt = extend({'width': 0, 'level': 0, 'indent': 1, 'tail': 0, 'seen': []}, a:0 ? copy(a:1) : {})
    let opt.seen = copy(opt.seen)
    let childopt = copy(opt)
    let childopt.tail += 1
    let childopt.level += 1
    for i in range(len(opt.seen))
        if a:object is opt.seen[i]
            return type(a:object) == type([]) ? '[...]' : '{...}'
        endif
    endfor
    if type(a:object) ==# type('')
        if a:object =~# "[\001-\037']"
            let dump = '"'.s:gsub(a:object, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))').'"'
        else
            let dump = string(a:object)
        endif
    elseif type(a:object) ==# type([])
        let childopt.seen += [a:object]
        let dump = '['.join(map(copy(a:object), 'debug#dump(v:val, {"seen": childopt.seen, "level": childopt.level})'), ', ').']'
        if opt.width && opt.level + len(s:gsub(dump, '.', '.')) > opt.width
            let space = repeat(' ', opt.level)
            let dump = "[".join(map(copy(a:object), 'debug#dump(v:val, childopt)'), ",\n ".space).']'
        endif
    elseif type(a:object) ==# type({})
        let childopt.seen += [a:object]
        let keys = sort(keys(a:object))
        let dump = '{'.join(map(copy(keys), 'debug#dump(v:val) . ": " . debug#dump(a:object[v:val], {"seen": childopt.seen, "level": childopt.level})'), ', ').'}'
        if opt.width && opt.level + len(s:gsub(dump, '.', '.')) > opt.width
            let space = repeat(' ', opt.level)
            let lines = []
            let last = get(keys, -1, '')
            for k in keys
                let prefix = debug#dump(k) . ':'
                let suffix = debug#dump(a:object[k]) . ','
                if len(space . prefix . ' ' . suffix) >= opt.width - (k ==# last ? opt.tail : '')
                    call extend(lines, [prefix, debug#dump(a:object[k], childopt) . ','])
                else
                    call extend(lines, [prefix . ' ' . suffix])
                endif
            endfor
            let dump = s:sub("{".join(lines, "\n " . space), ',$', '}')
        endif
    elseif type(a:object) ==# type(function('tr'))
        let dump = s:sub(s:sub(string(a:object), '^function\(''(\d+)''', 'function(''{\1}'''), ',.*\)$', ')')
    else
        let dump = string(a:object)
    endif
    return dump
endfu

fu! s:backslashdump(value, indent) abort
    let out = debug#dump(a:value, {'level': 0, 'width': &textwidth - &shiftwidth * 3 - a:indent})
    return s:gsub(out, '\n', "\n".repeat(' ', a:indent + &shiftwidth * 3).'\\')
endfu

fu! debug#pp_command(bang, lnum, value) abort
    if v:errmsg !=# ''
        return
    elseif a:lnum == -1
        echo debug#dump(a:value, {'width': a:bang ? 0 : &columns-1})
    else
        exe a:lnum
        let indent = indent(prevnonblank('.'))
        if a:bang
            let out = debug#dump(a:value)
        else
            let out = s:backslashdump(a:value, indent)
        endif
        put =repeat(' ', indent).'PP '.out
        '[
    endif
endfu

fu! debug#ppmsg_command(bang, count, value) abort
    if v:errmsg !=# ''
        return
    elseif &verbose >= a:count
        for line in split(debug#dump(a:value, {'width': a:bang ? 0 : &columns-1}), "\n")
            echomsg line
        endfor
    endif
endfu

fu! debug#pp(expr, bang, count) abort
    if empty(a:expr)
      try
        set nomore
        while 1
          let s:input = input('PP> ', '', 'expression')
          if empty(s:input)
            break
          endif
          echon "\n"
          let v:errmsg = ''
          try
            call debug#pp_command(a:bang, -1, eval(s:input))
          catch
            echohl ErrorMsg
            echo v:exception
            echo v:throwpoint
            echohl NONE
          endtry
        endwhile
    finally
      set more
    endtry
    else
      let v:errmsg = ''
      call debug#pp_command(a:bang, a:count, eval(a:expr))
    endif
endfu

fu! debug#ppmsg(expr, bang, count) abort
    if !empty(a:expr)
        let v:errmsg = ''
        call debug#ppmsg_command(a:bang, a:count, empty(a:expr) ? expand('<sfile>') : eval(a:expr))
    elseif &verbose >= a:count && !empty(expand('<sfile>'))
        echomsg expand('<sfile>').', line '.expand('<slnum>')
    endif
endfu

" g! {{{1

fu! s:opfunc(type) abort
    let cb_save = &clipboard
    let reg_save = @@
    try
        set clipboard-=unnamed clipboard-=unnamedplus
        if a:type =~ '^\d\+$'
            sil exe 'norm! ^v'.a:type.'$hy'
        elseif a:type =~# '^.$'
            sil exe "norm! `<" . a:type . "`>y"
        elseif a:type ==# 'line'
            sil exe "norm! '[V']y"
        elseif a:type ==# 'block'
            sil exe "norm! `[\<C-V>`]y"
        else
            sil exe "norm! `[v`]y"
        endif
        redraw
        return @@
    finally
        let @@ = reg_save
        let &clipboard = cb_save
    endtry
endfu

fu! debug#filterop(type) abort
    let reg_save = @@
    try
        let expr = s:opfunc(a:type)
        let @@ = matchstr(expr, '^\_s\+').debug#dump(eval(s:gsub(expr,'\n%(\s*\\)=',''))).matchstr(expr, '\_s\+$')
        if @@ !~# '^\n*$'
            norm! gv""p
        endif
    catch /^.*/
        echohl ErrorMSG
        echo v:errmsg
        echohl NONE
    finally
        let @@ = reg_save
    endtry
endfu

" :Scriptnames {{{1

fu! debug#scriptnames_qflist() abort
    let names = execute('scriptnames')
    let list = []
    for line in split(names, "\n")
        if line =~# ':'
            call add(list, {'text': matchstr(line, '\d\+'), 'filename': expand(matchstr(line, ': \zs.*'))})
        endif
    endfor
    return list
endfu

fu! debug#scriptname(file) abort
    if a:file =~# '^\d\+$'
        return get(debug#scriptnames_qflist(), a:file-1, {'filename': a:file}).filename
    else
        return a:file
    endif
endfu

fu! debug#scriptid(filename) abort
    let filename = fnamemodify(expand(a:filename), ':p')
    for script in debug#scriptnames_qflist()
        if script.filename ==# filename
            return +script.text
        endif
    endfor
    return ''
endfu

" :Runtime {{{1

fu! s:unlet_for(files) abort
    let guards = []
    for file in a:files
        if filereadable(file)
            let lines = readfile(file, '', 500)
            if len(lines)
                for i in range(len(lines)-1)
                    let unlet = matchstr(lines[i], '^if .*\<exists *( *[''"]\%(\g:\)\=\zs[0-9A-Za-z_#]\+\ze[''"]')
                    if unlet !=# '' && index(guards, unlet) == -1
                        for j in range(0, 4)
                            if get(lines, i+j, '') =~# '^\s*finish\>'
                                call extend(guards, [unlet])
                                break
                            endif
                        endfor
                    endif
                endfor
            endif
        endif
    endfor
    if empty(guards)
        return ''
    else
        return 'unlet! '.join(map(guards, '"g:".v:val'), ' ')
    endif
endfu

fu! s:lencompare(a, b) abort
    return len(a:a) - len(a:b)
endfu

fu! debug#locate(path) abort
    let path = fnamemodify(a:path, ':p')
    let candidates = []
    for glob in split(&runtimepath, ',')
        let candidates += filter(split(glob(glob), "\n"), 'path[0 : len(v:val)-1] ==# v:val && path[len(v:val)] =~# "[\\/]"')
    endfor
    if empty(candidates)
        return ['', '']
    endif
    let preferred = sort(candidates, s:function('s:lencompare'))[-1]
    return [preferred, path[strlen(preferred)+1 : -1]]
endfu

fu! debug#runtime_command(bang, ...) abort
    let unlets = []
    let do = []
    let predo = ''

    if a:0
        let files = a:000
    elseif &filetype ==# 'vim' || expand('%:e') ==# 'vim'
        let files = [debug#locate(expand('%:p'))[1]]
        if empty(files[0])
            let files = ['%']
        endif
        if &modified && (&autowrite || &autowriteall)
            let predo = 'sil wall|'
        endif
    else
        for ft in split(&filetype, '\.')
            for pattern in ['ftplugin/%s.vim', 'ftplugin/%s_*.vim', 'ftplugin/%s/*.vim', 'indent/%s.vim', 'syntax/%s.vim', 'syntax/%s/*.vim']
                call extend(unlets, split(globpath(&rtp, printf(pattern, ft)), "\n"))
            endfor
        endfor
        let run = s:unlet_for(unlets)
        if run !=# ''
            let run .= '|'
        endif
        let run .= 'filetype detect'
        echo ':'.run
        return run
    endif

    for request in files
        if request =~# '^\.\=[\\/]\|^\w:[\\/]\|^[%#~]\|^\d\+$'
            let request = debug#scriptname(request)
            let unlets += split(glob(request), "\n")
            let do += map(copy(unlets), '"source ".escape(v:val, " \t|!")')
        else
            if get(do, 0, [''])[0] !~# '^runtime!'
                let do += ['runtime!']
            endif
            let unlets += split(globpath(&rtp, request, 1), "\n")
            let do[-1] .= ' '.escape(request, " \t|!")
        endif
    endfor
    if empty(a:bang)
        call extend(do, ['filetype detect'])
    endif
    let run = s:unlet_for(unlets)
    if run !=# ''
        let run .= '|'
    endif
    let run .= join(do, '|')
    echo ':'.run
    return predo.run
endfu

" :Disarm {{{1

fu! debug#disarm(file) abort
    let augroups = filter(readfile(a:file), 'v:val =~# "^\\s*aug\\%[roup]\\s"')
    call filter(augroups, 'v:val !~# "^\\s*aug\\%[roup]\\s\\+END"')
    for augroup in augroups
        exe augroup
        au!
        augroup END
        exe s:sub(augroup, 'aug\%[roup]', '&!')
    endfor
    call s:disable_maps_and_commands(a:file, 0)

    let tabnr    = tabpagenr()
    let winnr    = winnr()
    let altwinnr = winnr('#')

    tabdo windo call s:disable_maps_and_commands(a:file, 1)
    exe 'tabnext '.tabnr
    exe altwinnr.'wincmd w'
    exe winnr.'wincmd w'

    return s:unlet_for([a:file])
endfu

fu! s:disable_maps_and_commands(file, buf) abort
    let last_set = "\tLast set from " . fnamemodify(a:file, ':~')
    for line in split(execute('verbose command'), "\n")
        if line ==# last_set
            if last[2] ==# (a:buf ? 'b' : ' ')
                exe 'delcommand '.matchstr(last[4:-1], '^\w\+')
            endif
        else
            let last = line
        endif
    endfor
    for line in split(execute('verbose map').execute('verbose map!'), "\n")
        if line ==# last_set
            let map = matchstr(last, '^.\s\+\zs\S\+')
            let rest = matchstr(last, '^.\s\+\S\+\s\+\zs[&* ][ @].*')
            if rest[1] ==# (a:buf ? '@' : ' ')
                let cmd = last =~# '^!' ? 'unmap! ' : last[0].'unmap '
                exe cmd.(a:buf ? '<buffer>' : '').map
            endif
        else
            let last = line
        endif
    endfor
endfu

fu! debug#disarm_command(bang, ...) abort
    let files = []
    let unlets = []
    for request in a:000
        if request =~# '^\.\=[\\/]\|^\w:[\\/]\|^[%#~]\|^\d\+$'
            let request = expand(debug#scriptname(request))
            if isdirectory(request)
                let request .= "/**/*.vim"
            endif
            let files += split(glob(request), "\n")
        else
            let files += split(globpath(&rtp, request, 1), "\n")
        endif
    endfor
    for file in files
        let unlets += [debug#disarm(expand(file))]
    endfor
    echo join(files, ' ')
    return join(filter(unlets, 'v:val !=# ""'), '|')
endfu

" :Vopen, :Vedit, ... {{{1

fu! s:previewwindow() abort
    for i in range(1, winnr('$'))
        if getwinvar(i, '&previewwindow') == 1
            return i
        endif
    endfor
    return -1
endfu

fu! s:runtime_globpath(file) abort
    return split(globpath(escape(&runtimepath, ' '), a:file), "\n")
endfu

fu! debug#open_command(count,cmd,file,lcd) abort
    let found = s:runtime_globpath(a:file)
    let file = get(found, a:count - 1, '')
    if file ==# ''
        return "echoerr 'E345: Can''t find file \"".a:file."\" in runtimepath'"
    elseif a:cmd ==# 'read'
        return a:cmd.' '.fnameescape(file)
    elseif a:lcd
        let path = file[0:-strlen(a:file)-2]
        return a:cmd.' '.fnameescape(file) . '|lcd '.fnameescape(path)
    else
        let window = 0
        let precmd = ''
        let postcmd = ''
        if a:cmd =~# '^pedit'
            try
                exe 'sil ' . a:cmd
            catch /^Vim\%((\a\+)\)\=:E32/
            endtry
            let window = s:previewwindow()
            let precmd = printf('%d wincmd w|', window)
            let postcmd = '|wincmd w'
        elseif a:cmd !~# '^edit'
            exe a:cmd
        endif
        call setloclist(window, map(found,
                    \ '{"filename": v:val, "text": v:val[0 : -len(a:file)-2]}'))
        return precmd . 'll'.matchstr(a:cmd, '!$').' '.a:count . postcmd
    endif
endfu

" zS {{{1

fu! debug#synnames(...) abort
    if a:0
        let [line, col] = [a:1, a:2]
    else
        let [line, col] = [line('.'), col('.')]
    endif
    return reverse(map(synstack(line, col), 'synIDattr(v:val,"name")'))
endfu

fu! debug#synnames_map(count) abort
    if a:count
        let name = get(debug#synnames(), a:count-1, '')
        if name !=# ''
            return 'syntax list '.name
        endif
    else
        echo join(debug#synnames(), ' ')
    endif
    return ''
endfu

" K {{{1

fu! debug#helptopic() abort
    let col = col('.') - 1
    while col && getline('.')[col] =~# '\k'
        let col -= 1
    endwhile
    let pre = col == 0 ? '' : getline('.')[0 : col]
    let col = col('.') - 1
    while col && getline('.')[col] =~# '\k'
        let col += 1
    endwhile
    let post = getline('.')[col : -1]
    let syn = get(debug#synnames(), 0, '')
    let cword = expand('<cword>')
    if syn ==# 'vimFuncName'
        return cword.'()'
    elseif syn ==# 'vimOption'
        return "'".cword."'"
    elseif syn ==# 'vimUserAttrbKey'
        return ':command-'.cword
    elseif pre =~# '^\s*:\=$'
        return ':'.cword
    elseif pre =~# '\<v:$'
        return 'v:'.cword
    elseif cword ==# 'v' && post =~# ':\w\+'
        return 'v'.matchstr(post, ':\w\+')
    else
        return cword
    endif
endfu

" Settings {{{1

fu! s:build_path() abort
    let old_path = substitute(&g:path, '\v^\.,/%(usr|emx)/include,,,?', '', '')
    let new_path = escape(&runtimepath, ' ')
    return !empty(old_path) ? old_path.','.new_path : new_path
endfu

fu! debug#includeexpr(file) abort
    if a:file =~# '^\.\=[A-Za-z_]\w*\%(#\w\+\)\+$'
        let f = substitute(a:file, '^\.', '', '')
        return 'autoload/'.tr(matchstr(f, '[^.]\+\ze#') . '.vim', '#', '/')
    endif
    return substitute(a:file, '<sfile>', '%', 'g')
endfu

fu! debug#cfile() abort
    let original = expand('<cfile>')
    let cfile = original
    if cfile =~# '^\.\=[A-Za-z_]\w*\%(#\w\+\)\+$'
        return '+djump\ ' . matchstr(cfile, '[^.]*') . ' ' . debug#includeexpr(cfile)
    else
        return debug#includeexpr(cfile)
    endif
endfu

fu! debug#setup_vim() abort
    let &l:path = s:build_path()
    setl suffixesadd=.vim keywordprg=:help
    setl includeexpr=debug#includeexpr(v:fname)
    setl include=^\\s*\\%(so\\%[urce]\\\|ru\\%[untime]\\)[!\ ]\ *
    setl define=^\\s*fu\\%[nction][!\ ]\\s*
    cno <expr><buffer> <Plug><cfile> debug#cfile()
    let b:dispatch = ':Runtime'
    com! -bar -bang -buffer Console Runtime|PP
    com! -buffer -bar -nargs=? -complete=custom,s:Complete_breakadd Breakadd
                \ exe s:break('add',<q-args>)
    com! -buffer -bar -nargs=? -complete=custom,s:Complete_breakdel Breakdel
                \ exe s:break('del',<q-args>)

    nno <buffer> <nowait> <silent>  K  :<c-u>exe 'help '.debug#helptopic()<cr>
endfu

fu! debug#setup_help() abort
    let &l:path = s:build_path()
    com! -bar -bang -buffer Console PP
endfu


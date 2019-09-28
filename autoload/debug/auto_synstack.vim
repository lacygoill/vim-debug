if exists('g:autoloaded_debug#auto_synstack')
    finish
endif
let g:autoloaded_debug#auto_synstack = 1

let s:DIR = getenv('XDG_RUNTIME_VIM') == v:null ? '/tmp' : $XDG_RUNTIME_VIM

fu! debug#auto_synstack#main() abort "{{{1
    let s:minivimrc = s:DIR..'/debug_syntax_plugin.vim'

    augroup debug_syntax
        au!
        au CursorMoved <buffer> echo join(reverse(map(synstack(line('.'), col('.')), {_,v -> synIDattr(v, 'name')})))
        au BufEnter <buffer> exe 'so '..s:minivimrc
    augroup END

    " open a new file to write our mini syntax plugin
    exe 'new '..s:minivimrc
    call setline(1, 'syn clear')
endfu


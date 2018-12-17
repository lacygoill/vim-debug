fu! debug#autostack#main() abort
    let s:minivimrc = $XDG_RUNTIME_VIM . '/debug_syntax_plugin.vim'

    augroup debug_syntax
        au!
        au CursorMoved <buffer> echo join(reverse(map(synstack(line('.'), col('.')), {i,v -> synIDattr(v, 'name')})))
        au BufEnter <buffer> exe 'so ' . s:minivimrc
    augroup END

    " open a new file to write our mini syntax plugin
    exe 'new '. s:minivimrc
endfu


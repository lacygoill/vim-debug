runtime! ftplugin/markdown.vim

let b:title_like_in_markdown = 1

setl bh=delete bt=nofile fdl=99

nno  <buffer><nowait><silent>  q  :<c-u>close<cr>
nno  <buffer><nowait><silent>  R  :<c-u>e<cr>

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
                    \ .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
                    \ ."
                    \      setl fdl<
                    \    | unlet! b:title_like_in_markdown
                    \    | exe 'nunmap <buffer> q'
                    \    | exe 'nunmap <buffer> R'
                    \  "

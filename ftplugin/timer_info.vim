if exists('b:did_ftplugin')
    finish
endif

runtime! ftplugin/markdown.vim
unlet! b:did_ftplugin

let b:title_like_in_markdown = 1

setl bh=delete bt=nofile fdl=99 wfw

nno <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<cmd>q<cr>'
nno <buffer><nowait> R <cmd>e<cr>

let b:did_ftplugin = 1

" Teardown {{{1

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    \ .. '| call debug#timer_info#undo_ftplugin()'


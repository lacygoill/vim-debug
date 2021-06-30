vim9script

if exists('b:did_ftplugin')
    finish
endif

runtime! ftplugin/markdown.vim
unlet! b:did_ftplugin

b:title_like_in_markdown = true

&l:bufhidden = 'delete'
&l:buftype = 'nofile'
&l:foldlevel = 99
&l:winfixwidth = true

nnoremap <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<Cmd>quit<CR>'
nnoremap <buffer><nowait> R <Cmd>edit<CR>

b:did_ftplugin = true

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute')
    .. '| call debug#timerInfo#undoFtplugin()'


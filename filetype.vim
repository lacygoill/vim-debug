if exists('did_load_filetypes')
    finish
endif

augroup filetypedetect
    au! BufRead,BufNewFile  /tmp/*/timer_info  setf timer_info
augroup END

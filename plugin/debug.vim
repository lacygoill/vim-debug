augroup my_debug
    au!
    au FileType vim call debug#break_setup()
augroup END

com! -bar -bang  Messages     call debug#messages_command(<bang>0)
com! -bar        Scriptnames  call debug#scriptnames()

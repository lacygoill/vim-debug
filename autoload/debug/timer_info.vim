vim9script noclear

def debug#timerInfo#undoFtplugin()
    set bufhidden<
    set buftype<
    set foldlevel<
    set winfixwidth<
    unlet! b:title_like_in_markdown
    nunmap <buffer> q
    nunmap <buffer> R
enddef


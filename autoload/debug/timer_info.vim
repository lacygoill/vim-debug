vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#timerInfo#undoFtplugin()
    set bufhidden<
    set buftype<
    set foldlevel<
    set winfixwidth<
    unlet! b:title_like_in_markdown
    nunmap <buffer> q
    nunmap <buffer> R
enddef


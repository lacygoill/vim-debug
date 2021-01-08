vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#timerInfo#undoFtplugin()
    set bh< bt< fdl< wfw<
    unlet! b:title_like_in_markdown
    nunmap <buffer> q
    nunmap <buffer> R
enddef


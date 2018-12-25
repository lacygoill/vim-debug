if exists('b:current_syntax')
    finish
endif

" ✔
"     syn match timerInfoNoise        '^#'
"     syn match timerInfoInteresting  '\%(^#\)\@2<=\sid\s\+\zs.*' contains=timerInfoNoise





syn match timerInfoNoise        '^\%(#\+\|---\)$\|^#\s\zeid' conceal
syn match timerInfoInteresting  '^\%(remaining\|#\sid\)\s\+\zs.*\|^paused\s\+\zs1$\|^\s\{4}.*' contains=timerInfoCallback
" Why highlighting the text after the `:return` keyword?{{{
"
" Because  it's the  latter we  must  search if  there's an  issue with  the
" callback.
" `:return` is  never written in the  original code from which  the timer is
" started.
"}}}
syn match timerInfoCallback     '^\s\{4}1\s\+return\s\zs.*'

hi link timerInfoInteresting  Identifier
hi link timerInfoCallback     WarningMsg

let b:current_syntax = 'timer_info'





" Without `\zs`, the order of the rules matters:    easy to understand.
" From `:h :syn-priority`:
"
"         1. When multiple Match or Region items start in the same position,
"            the item defined last has priority.
"
" With `\zs`, `Interesting` always wins over `Callback`.
" Is it explained by:
"
"         3. An item that starts in an earlier position has priority over
"            items that start in later positions.
" ?
"
" With `\zs` + `contains`, `Callback` always wins over `Interesting`.
" Why???
" It seems that the rule stating  that characters before `\zs` (and after `\ze`)
" are consumed doesn't apply for nested syntax items.
" Find a MWE confirming this theory.
"     syn match timerInfoCallback     '^\s\{4}1\s\+return\s\zs.*'
"     syn match timerInfoInteresting  '^\s\{4}.*' contains=timerInfoCallback
"
"     hi link timerInfoInteresting  Identifier
"     hi link timerInfoCallback     WarningMsg
"
"     let b:current_syntax = 'timer_info'

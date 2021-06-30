vim9script

if exists('b:current_syntax')
    finish
endif

# ✔
#     syntax match timerInfoNoise        '^#'
#     syntax match timerInfoInteresting  '\%(^#\)\@1<=\sid\s\+\zs.*' contains=timerInfoNoise





syntax match timerInfoNoise        '^\%(#\+\|---\)$\|^#\s\zeid' conceal
syntax match timerInfoInteresting  '^\%(remaining\|#\sid\)\s\+\zs.*\|^paused\s\+\zs1$\|^\s\{4}.*' contains=timerInfoCallback
# Why highlighting the text after the `:return` keyword?{{{
#
# Because  it's the  latter we  must  search if  there's an  issue with  the
# callback.
# `:return` is  never written in the  original code from which  the timer is
# started.
#}}}
syntax match timerInfoCallback     '^\s\{4}1\s\+return\s\zs.*'

highlight def link timerInfoInteresting  Identifier
highlight def link timerInfoCallback     WarningMsg

b:current_syntax = 'timer_info'





# The following comments apply to the `timerInfoCallback` rule.
#
# Without `\zs`, the order of the rules matters.
# This is expected; from `:help :syn-priority`:
#
#    > 1. When multiple Match or Region items start in the same position,
#    >    the item defined last has priority.
#
# With `\zs`, `Interesting` always wins over `Callback`.
# Is it explained by:
#
#    > 3. An item that starts in an earlier position has priority over
#    >    items that start in later positions.
#
# ?
#
# With  `\zs`  + `contains`  (in  the  `timerInfoInteresting` rule),  `Callback`
# always wins over `Interesting`.
# Why???
# It  seems that  the rule  stating that  characters before  `\zs` are  consumed
# doesn't apply for contained syntax items.
# Find a MWE confirming this theory.
#
#     syntax match timerInfoCallback     '^\s\{4}1\s\+return\s\zs.*'
#     syntax match timerInfoInteresting  '^\s\{4}.*' contains=timerInfoCallback
#
#     highlight def link timerInfoInteresting  Identifier
#     highlight def link timerInfoCallback     WarningMsg
#
#     let b:current_syntax = 'timer_info'
#
# Update: I think that the rule is correct,  but the text of a contained item is
# parsed twice (once for the outer item, once for the inner item).
# The consumption of characters at the outer level only applies to outer items.
# Basically, I think the consumed characters are tied to a level of nesting.

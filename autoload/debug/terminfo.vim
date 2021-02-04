vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Interface {{{1
def debug#terminfo#main(use_curfile: bool) #{{{2
    if use_curfile
        SetFt()
    else
        SplitWindow()
    endif

    DumpTermcap(use_curfile)
    SplitCodes()
    SeparateTerminalKeysWithoutOptions()
    MoveKeynamesIntoInlineComments()
    AddAssignmentOperators()
    AlignInlineComment()
    AddSetCommands()
    EscapeSpacesInOptionsValues()
    TrimTrailingWhitespace()
    TranslateSpecialKeys()
    SortLines()
    CommentSectionHeaders()
    Fold()
    InstallMappings()

    sil! update
    #  │
    #  └ error if we don't have our autocmd which creates a missing directory
enddef
#}}}1
# Core {{{1
def SetFt() #{{{2
    if &ft != 'vim'
        set ft=vim
    endif
enddef

def SplitWindow() #{{{2
    var tempfile: string = tempname() .. '/termcap.vim'
    exe 'sp ' .. tempfile
enddef

def DumpTermcap(use_curfile: bool) #{{{2
    execute('set termcap')->split('\n')->setline(1)
    append(1, '')
    # The bang  after silent is necessary  to suppress `E486` in  the GUI, where
    # there may be no `Terminal keys` section.
    sil! :1/Terminal keys/ | append(line('.') - 1, '')
    sil! :1/Terminal keys/ | append('.', '')
    sil keepj keepp :%s/^ *//e
enddef

def SplitCodes() #{{{2
    # split terminal codes; one per line
    sil! keepj keepp :1,/Terminal keys\|\%$/s/ \{2,}/\r/ge
    #                                 ├───┘
    #                                 └ to support the GUI where there is no "Terminal keys" section

    if search('Terminal keys', 'n') == 0
        return
    endif
    # split terminal keys; one per line
    sil! keepj keepp :/Terminal keys/,$s/ \zet_\S*/\r/ge
    sil! keepj keepp :/Terminal keys/,$s/\%(<.\{-}>.*\)\@<=<\S\{-1,}> \+.\{-}\ze\%( <.\{-1,}> \+\S\|$\)/\r&/ge
    # Why this second substitution?{{{
    #
    # To handle terminal keys which are not associated to a terminal option.
    #
    #     t_k; <F10>       ^[[21~         <á>        ^[a            <ú>        ^[z
    #
    #     →
    #
    #     t_k; <F10>       ^[[21~ 
    #     <á>        ^[a
    #     <ú>        ^[z
    #}}}
enddef

def SeparateTerminalKeysWithoutOptions() #{{{2
    # move terminal keys not associated to any terminal option at the end of the buffer
    sil! keepj keepp :/Terminal keys/,$g/^</m $
    # separate them from the terminal keys associated with a terminal option{{{
    #
    #     t_kP <PageUp>    ^[[5~ 
    #     <í>        ^[m
    #
    #     →
    #
    #     t_kP <PageUp>    ^[[5~ 
    #
    #     <í>        ^[m
    #}}}
    sil! :1/^<\%(.*" t_\S\S\)\@!/put! _
enddef

def MoveKeynamesIntoInlineComments() #{{{2
    #     t_#2 <S-Home>    ^[[1;2H
    #     →
    #     <S-Home>    ^[[1;2H  " t_#2
    sil! keepj keepp :/Terminal keys/,$s/^\(t_\S\+ \+\)\(<.\{-1,}>\)\(.*\)/\2\3" \1/e
enddef

def AddAssignmentOperators() #{{{2
    # Only necessary for terminal keys (not codes):
    #
    #     <S-Home>    ^[[1;2H  " t_#2
    #     →
    #     <S-Home>=^[[1;2H  " t_#2
    sil! keepj keepp :/Terminal keys/,$s/^<.\{-1,}>\zs \+/=/e
enddef

def AlignInlineComment() #{{{2
    if exists(':EasyAlign') != 2
        return
    endif

    #     <S-Home>=^[[1;2H  " t_#2
    #     <F4>=^[OS     " t_k4
    #
    #     →
    #
    #     <S-Home>=^[[1;2H " t_#2
    #     <F4>=^[OS        " t_k4

    # What's this argument `{'ig': []}`?{{{
    #
    # By default, `:EasyAlign` ignores a delimiter in a comment.
    # This prevents our alignment from being performed.
    # We fix this by passing to `:EasyAlign` the optional argument `{'ig': []}`,
    # which tells it to ignore nothing.
    #}}}
    sil! keepj keepp :/Terminal keys/+,$EasyAlign /"/ {'ig': []}
enddef

def AddSetCommands() #{{{2
    sil keepj keepp :%s/^\ze\%(t_\|<\)/set /e
enddef

def EscapeSpacesInOptionsValues() #{{{2
    #     set t_EI=^[[2 q
    #     →
    #     set t_EI=^[[2\ q
    #                  ^
    sil keepj keepp :%s/\%(set.\{-}=.*[^"]\)\@<= [^" ]/\\&/ge
enddef

def TrimTrailingWhitespace() #{{{2
    sil! keepj keepp :/Terminal keys/,$s/ \+$//e
enddef

def TranslateSpecialKeys() #{{{2
    # translate caret notation of control characters
    sil keepj keepp :%s/\^\[/\="\e"/ge
    sil keepj keepp :%s/\^\(\u\)/\=eval('"' .. '\x' .. (submatch(1)->char2nr() - 64) .. '"')/ge
    sil keepj keepp :%s/\^?/\="\x7f"/ge

    #     <á>=^[a    →    <M-a>=^[a
    sil keepj keepp :%s/^set <\zs.\ze>=\e\(\l\)/M-\1/e
enddef

def SortLines() #{{{2
    # sort terminal codes: easier to find a given terminal option name
    # sort terminal keys: useful later when vimdiff'ing the output with another one
    sil! keepj :1/Terminal codes/+,/Terminal keys/--sort
    sil! keepj :1/Terminal keys/++;/^$/-sort
    sil! keepj :1/Terminal keys//^$//^$/+;$sort
enddef

def CommentSectionHeaders() #{{{2
    #     --- Terminal codes ---    →    " Terminal codes
    #     --- Terminal keys ---     →    " Terminal keys
    sil keepj keepp :%s/^--- Terminal \(\S*\).*/" Terminal \1/e
enddef

def Fold() #{{{2
    sil keepj keepp :%s/^" .*\zs/\=' {{' .. '{1'/e
enddef

def InstallMappings() #{{{2
    nno <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<cmd>q!<cr>'
    # mapping to compare value on current line with the one in output of `:set termcap`{{{
    #
    # Note that  `:filter` is able  to filter the "Terminal  codes" section,
    # but not the "Terminal keys" section.
    # So, no  matter the line  where you press  `!!`, you'll always  get the
    # whole "Terminal codes" section.
    # The  mapping is  still useful:  if you  press `!!`  on a  line in  the
    # "Terminal codes" section,  it will correctly filter out  all the other
    # terminal codes.
    #}}}
    nno <buffer><nowait> !!
        \ <cmd>exe 'filter /' .. getline('.')->matchstr('t_[^=]*') .. '/ set termcap'<cr>
    # open relevant help tag to get more info about the terminal option under the cursor
    nno <buffer><nowait> <cr> <cmd>call <sid>GetHelp()<cr>
    # get help about mappings
    nno <buffer><nowait> g? <cmd>call <sid>PrintHelp()<cr>
enddef

def GetHelp() #{{{2
    var tag: string = getline('.')->matchstr('\%(^set \|" \)\@4<=t_[^=]*')
    if tag != ''
        try
            exe "h '" .. tag
        # some terminal options have no help tags (e.g. `'t_FL'`)
        catch /^Vim\%((\a\+)\)\=:E149:/
            echohl ErrorMsg
            echom v:exception
            echohl NONE
        endtry
    else
        echo 'no help tag on this line'
    endif
enddef

def PrintHelp() #{{{2
    var help: list<string> =<< trim END
        Enter    open relevant help tag to get more info about the terminal option under the cursor
        !!       compare value on current line with the one in output of `:set termcap`
        g?       print this help
    END
    echo join(help, "\n")
enddef


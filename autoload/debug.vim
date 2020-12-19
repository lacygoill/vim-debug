vim9script

if exists('g:autoloaded_debug')
    finish
endif
g:autoloaded_debug = 1

import Catch from 'lg.vim'

fu debug#help_about_last_errors() abort "{{{1
    let messages = execute('messages')->split('\n')->reverse()
    "                    ┌ When an error occurs inside a try conditional,{{{
    "                    │ Vim prefixes an error message with:
    "                    │
    "                    │     Vim:
    "                    │ or:
    "                    │     Vim({cmd}):
    "                    ├───────────────┐}}}
    let pat_error = '^\%(Vim\%((\a\+)\)\=:\|".\{-}"\s\)\=\zsE\d\+'
    "                                       ├───────┘{{{
    "                                       └ in a buffer containing the word 'the', execute:
    "
    "                                               g/the/ .w >>/tmp/some_file
    "
    "                                         It raises this error message:
    "
    "                                               /tmp/file_1" E212: Can't open file for writing
    "}}}

    " index of most recent error
    let i = match(messages, pat_error)
    " index of next line which isn't an error, nor belongs to a stack trace
    let j = match(messages, '^\%(' .. pat_error .. '\|Error\|line\)\@!', i+1)
    if j == -1
        let j = i+1
    endif

    let errors = map(messages[i : j - 1], {idx, v -> matchstr(v, pat_error)})
    " remove lines  which don't contain  an error,  or which contain  the errors
    " E662 / E663 / E664 (they aren't interesting and come frequently)
    call filter(errors, {_, v -> !empty(v) && v !~# '^E66[234]$'})
    if empty(errors)
        return 'echo "no last errors"'
    endif

    let s:last_errors = get(s:, 'last_errors', {'taglist' : [], 'pos': -1})
    " the current latest errors are identical to the ones we saved the last time
    " we invoked this function
    if errors ==# s:last_errors.taglist
        " just update our position in the list of visited errors
        let s:last_errors.pos = (s:last_errors.pos + 1) % len(s:last_errors.taglist)
    else
        " reset our position in the list of visited errors
        let s:last_errors.pos = 0
        " reset the list of errors
        let s:last_errors.taglist = errors
    endif

    return 'h ' .. get(s:last_errors.taglist, s:last_errors.pos, s:last_errors.taglist[0])
endfu

fu debug#messages() abort "{{{1
    0Verbose messages
    " If `:Verbose` encountered an error, we could still be in a regular window,
    " instead  of the  preview window.   If that's  the case,  we don't  want to
    " remove any text in the current buffer, nor install any match.
    if !&l:pvw | return | endif

    " From a help buffer, the buffer displayed in a newly opened preview
    " window inherits some settings, such as 'nomodifiable' and 'readonly'.
    " Make sure they're disabled so that we can remove noise.
    setl ma noro

    let noises = {
        \ '[fewer|more] lines': '\d\+ \%(fewer\|more\) lines\%(; \%(before\|after\) #\d\+.*\)\=',
        \ '1 more line less':   '1 \%(more \)\=line\%( less\)\=\%(; \%(before\|after\) #\d\+.*\)\=',
        \ 'change':             'Already at \%(new\|old\)est change',
        \ 'changes':            '\d\+ changes\=; \%(before\|after\) #\d\+.*' ,
        \ 'E21':                "E21: Cannot make changes, 'modifiable' is off",
        \ 'E387':               'E387: Match is on current line',
        \ 'E486':               'E486: Pattern not found: \S*',
        \ 'E492':               'E492: Not an editor command: \S\+',
        \ 'E553':               'E553: No more items',
        \ 'E663':               'E663: At end of changelist',
        \ 'E664':               'E664: changelist is empty',
        \ 'Ex mode':            'Entering Ex mode.  Type "visual" to go to Normal mode.',
        \ 'empty lines':        '\s*',
        \ 'lines filtered':     '\d\+ lines filtered',
        \ 'lines indented':     '\d\+ lines [><]ed \d\+ times\=',
        \ 'file loaded':        '".\{-}"\%( \[RO\]\)\= line \d\+ of \d\+ --\d\+%-- col \d\+\%(-\d\+\)\=',
        \ 'file reloaded':      '".\{-}".*\d\+L, \d\+C',
        \ 'g C-g':              'col \d\+ of \d\+; line \d\+ of \d\+; word \d\+ of \d\+;'
        \                   .. ' char \d\+ of \d\+; byte \d\+ of \d\+',
        \ 'C-c':           'Type\s*:qa!\s*and press <Enter> to abandon all changes and exit Vim',
        \ 'maintainer':    'Messages maintainer: Bram Moolenaar <Bram@vim.org>',
        \ 'Scanning':      'Scanning:.*',
        \ 'substitutions': '\d\+ substitutions\= on \d\+ lines\=',
        \ 'verbose':       ':0Verbose messages',
        \ 'W10':           'W10: Warning: Changing a readonly file',
        \ 'yanked lines':  '\%(block of \)\=\d\+ lines yanked',
        \ }

    for noise in values(noises)
        sil exe 'g/^' .. noise .. '$/d_'
    endfor

    call matchadd('ErrorMsg', '^E\d\+:\s\+.*', 0)
    call matchadd('ErrorMsg', '^Vim.\{-}:E\d\+:\s\+.*', 0)
    call matchadd('ErrorMsg', '^Error detected while processing.*', 0)
    call matchadd('LineNr', '^line\s\+\d\+:$', 0)
    exe '$'
endfu

fu debug#time(cmd, cnt) "{{{1
    let time = reltime()
    try
        " We could  get rid of the  if/else/endif, and shorten the  code, but we
        " won't do it, because the most usual case is `a:cnt = 1`.  And we want to
        " execute `a:cmd` as  fast as possible (no let, no  while loop), because
        " Ex commands are slow.
        if a:cnt > 1
            let i = 0
            while i < a:cnt
                exe a:cmd
                let i += 1
            endwhile
        else
            exe a:cmd
        endif
    catch
        return s:Catch()
    finally
        " We clear the screen before displaying the results, to erase the
        " possible messages displayed by the command.
        redraw
        echom reltime(time)->reltimestr()->matchstr('.*\..\{,3}') .. ' seconds to run :' .. a:cmd
    endtry
endfu

fu debug#unused_functions() abort "{{{1
    " look for all function definitions in the current repo
    sil noa lvim /^\s*fu\%[nction]\s\+/ ./**/*.vim
    let functions = getloclist(0)->map({_, v -> v.text->matchstr('[^ (]*\ze(')})

    " build a list of unused functions
    let unused = []
    for afunc in functions
        let pat = afunc
        if afunc[:1] is# 's:'
            let pat ..= '\|<sid>' .. afunc[2:]
        endif
        exe 'sil noa lvim /' .. pat .. '/ ./**/*.vim'
        " the name of an unused function appears only once
        if getloclist(0, {'size': 0}).size <= 1
            let unused += [afunc]
        endif
    endfor

    " report unused functions if any
    if empty(unused)
        echom 'no unused function in ' .. getcwd()
    else
        exe 'lvim /' .. join(unused, '\|') .. '/ ./**/*.vim'
    endif
endfu

def debug#vimPatches(n: string, append = v:false) #{{{1
    if n == ''
        var msg =<< trim END
            provide a major Vim version number

            usage example:

                VimPatches 8.2
                VimPatches 7.4 - 8.2
        END
        echo join(msg, "\n")
    elseif index(MAJOR_VERSIONS, n) != -1
        var filename = 'ftp://ftp.vim.org/pub/vim/patches/' .. n .. '/README'
        if append
            var bufnr = bufadd(filename)
            bufload(bufnr)
            getbufline(bufnr, 1, '$')->append('$')
            exe 'bw! ' .. bufnr
            append('$', '')
            # Sometimes, we have 2 empty lines between 2 major versions, instead of just 1; remove it.{{{
            #
            # That happens, for example, if you run:
            #
            #     :VimPatches 8.0 - 8.2
            #
            # There are 2 empty lines between the 8.1 patches and the 8.2 patches.
            # For some  reason, we need to  delay, otherwise we might  delete an
            # empty line which we want to keep (e.g. between 8.0 and 8.1).
            #}}}
            au SafeState * ++once sil! g/^\n\n\|\%^$\|\%$$/d _
            #                                 ^----------^
            #                                 also delete the first and last empty lines
        elseif bufloaded(filename)
            Display(filename)
            return
        else
            sil exe 'sp ' .. filename
            Prettify()
        endif
    elseif n =~ '^\d\.\d\s*-\s*\d\.\d$'
        var first: string
        var last: string
        [first, last] = matchlist(n, '\(\d\.\d\)\s*-\s*\(\d\.\d\)')[1:2]
        if index(MAJOR_VERSIONS, first) == -1
            Error(first .. ' is not a valid major Vim version')
        elseif index(MAJOR_VERSIONS, last) == -1
            Error(last .. ' is not a valid major Vim version')
        endif
        var filename = 'VimPatches ' .. n
        if bufloaded(filename)
            Display(filename)
            return
        endif
        new
        exe 'file ' .. fnameescape(filename)
        var ifirst = index(MAJOR_VERSIONS, first)
        var ilast = index(MAJOR_VERSIONS, last)
        var numbers = MAJOR_VERSIONS[ifirst : ilast]
        for number in numbers
            debug#vimPatches(number, true)
        endfor
        Prettify()
    else
        Error('invalid argument')
    endif
enddef

def Display(filename: string)
    var winid = bufnr(filename)->win_findbuf()->get(-1)
    if winid > 0
        win_gotoid(winid)
    else
        exe 'sp ' .. filename
    endif
enddef

def Error(msg: string)
    echohl ErrorMsg
    echom msg
    echohl NONE
enddef

def Prettify()
    # no modified indicator in the status line if we edit the buffer
    setl bt=nofile nobl noswf nowrap

    # remove noise
    sil g/^Patches for Vim/ :.;/^\s*SIZE/d _
    sil! g/^--- The story continues with Vim /d _
    sil keepj keepp :%s/^\s*\d\+\s\+//e

    # format links
    sil keepj keepp :%s@^[0-9.]\+@[&](https://github.com/vim/vim/releases/tag/v&)@e

    # conceal url (copied from the markdown syntax plugin)
    syn match xUrl /\S\+/ contained
    syn region xLinkText matchgroup=xLinkTextDelimiter
        \ start=/!\=\[\ze\_[^]]*] \=[[\x28]/ end=/\]\ze \=[[\x28]/
        \ nextgroup=xLink keepend concealends skipwhite
    syn region xLink matchgroup=xLinkDelimiter
        \ start=/(/ end=/)/
        \ contained keepend conceal contains=xUrl
    hi link xLinkText Underlined
    hi link xUrl Float
    setl cole=3 cocu=nc
enddef

def debug#vimPatchesCompletion(_a: any, _l: any, _p: any): string #{{{1
    return join(MAJOR_VERSIONS, "\n")
enddef

const MAJOR_VERSIONS =<< trim END
    6.3
    6.4
    7.0
    7.1
    7.2
    7.3
    7.4
    8.0
    8.1
    8.2
END


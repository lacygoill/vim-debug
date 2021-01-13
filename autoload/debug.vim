vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import Catch from 'lg.vim'

def debug#helpAboutLastErrors(): string #{{{1
    var messages = execute('messages')->split('\n')->reverse()
    #                    ┌ When an error occurs inside a try conditional,{{{
    #                    │ Vim prefixes an error message with:
    #                    │
    #                    │     Vim:
    #                    │ or:
    #                    │     Vim({cmd}):
    #                    ├───────────────┐}}}
    var pat_error = '^\%(Vim\%((\a\+)\)\=:\|".\{-}"\s\)\=\zsE\d\+'
    #                                       ├───────┘{{{
    #                                       └ in a buffer containing the word 'the', execute:
    #
    #                                               g/the/ .w >>/tmp/some_file
    #
    #                                         It raises this error message:
    #
    #                                               /tmp/file_1" E212: Can't open file for writing
    #}}}

    # index of most recent error
    var i = match(messages, pat_error)
    # index of next line which isn't an error, nor belongs to a stack trace
    var j = match(messages, '^\%(' .. pat_error .. '\|Error\|line\)\@!', i + 1)
    if j == -1
        j = i + 1
    endif

    var errors = map(messages[i : j - 1], (idx, v) => matchstr(v, pat_error))
    # remove lines  which don't contain  an error,  or which contain  the errors
    # E662 / E663 / E664 (they aren't interesting and come frequently)
    filter(errors, (_, v) => !empty(v) && v !~ '^E66[234]$')
    if empty(errors)
        return 'echo "no last errors"'
    endif

    # the current latest errors are identical to the ones we saved the last time
    # we invoked this function
    if errors == last_errors.taglist
        # just update our position in the list of visited errors
        last_errors.pos = (last_errors.pos + 1) % len(last_errors.taglist)
    else
        # reset our position in the list of visited errors
        last_errors.pos = 0
        # reset the list of errors
        last_errors.taglist = errors
    endif

    return 'h ' .. get(last_errors.taglist, last_errors.pos, last_errors.taglist[0])
enddef
var last_errors = {taglist: [], pos: -1}

def debug#messages() #{{{1
    :0Verbose messages
    # If `:Verbose` encountered an error, we could still be in a regular window,
    # instead  of the  preview window.   If that's  the case,  we don't  want to
    # remove any text in the current buffer, nor install any match.
    if !&l:pvw
        return
    endif

    # From a help buffer, the buffer displayed in a newly opened preview
    # window inherits some settings, such as 'nomodifiable' and 'readonly'.
    # Make sure they're disabled so that we can remove noise.
    setl ma noro

    var noises = {
        '[fewer|more] lines': '\d\+ \%(fewer\|more\) lines\%(; \%(before\|after\) #\d\+.*\)\=',
        '1 more line less':   '1 \%(more \)\=line\%( less\)\=\%(; \%(before\|after\) #\d\+.*\)\=',
        'change':             'Already at \%(new\|old\)est change',
        'changes':            '\d\+ changes\=; \%(before\|after\) #\d\+.*',
        'E21':                "E21: Cannot make changes, 'modifiable' is off",
        'E387':               'E387: Match is on current line',
        'E486':               'E486: Pattern not found: \S*',
        'E492':               'E492: Not an editor command: \S\+',
        'E553':               'E553: No more items',
        'E663':               'E663: At end of changelist',
        'E664':               'E664: changelist is empty',
        'Ex mode':            'Entering Ex mode.  Type "visual" to go to Normal mode.',
        'empty lines':        '\s*',
        'lines filtered':     '\d\+ lines filtered',
        'lines indented':     '\d\+ lines [><]ed \d\+ times\=',
        'file loaded':        '".\{-}"\%( \[RO\]\)\= line \d\+ of \d\+ --\d\+%-- col \d\+\%(-\d\+\)\=',
        'file reloaded':      '".\{-}".*\d\+L, \d\+C',
        'g C-g':              'col \d\+ of \d\+; line \d\+ of \d\+; word \d\+ of \d\+;'
                          .. ' char \d\+ of \d\+; byte \d\+ of \d\+',
        'C-c':           'Type\s*:qa!\s*and press <Enter> to abandon all changes and exit Vim',
        'maintainer':    'Messages maintainer: Bram Moolenaar <Bram@vim.org>',
        'Scanning':      'Scanning:.*',
        'substitutions': '\d\+ substitutions\= on \d\+ lines\=',
        'verbose':       ':0Verbose messages',
        'W10':           'W10: Warning: Changing a readonly file',
        'yanked lines':  '\%(block of \)\=\d\+ lines yanked',
        }

    for noise in values(noises)
        sil exe 'g/^' .. noise .. '$/d _'
    endfor

    matchadd('ErrorMsg', '^E\d\+:\s\+.*', 0)
    matchadd('ErrorMsg', '^Vim.\{-}:E\d\+:\s\+.*', 0)
    matchadd('ErrorMsg', '^Error detected while processing.*', 0)
    matchadd('LineNr', '^line\s\+\d\+:$', 0)
    cursor('$', 0)
enddef

def debug#time(cmd: string, cnt: number) #{{{1
    var time = reltime()
    try
        # We could  get rid of the  if/else/endif, and shorten the  code, but we
        # won't do it, because the most usual case is `cnt = 1`.  And we want to
        # execute `cmd` as fast as possible  (no let, no while loop), because Ex
        # commands are slow.
        if cnt > 1
            var i = 0
            while i < cnt
                exe cmd
                i += 1
            endwhile
        else
            exe cmd
        endif
    catch
        Catch()
    finally
        # We  clear the  screen  before  displaying the  results,  to erase  the
        # possible messages displayed by the command.
        redraw
        echom reltime(time)
            ->reltimestr()
            ->matchstr('.*\..\{,3}') .. ' seconds to run :' .. cmd
    endtry
enddef

def debug#unusedFunctions() #{{{1
    # TODO: I think it would be useful if `InRepo()` was a libary function.
    # And maybe it should return the path to the root of the repo.
    # Look at `vim-cwd` for inspiration.
    if !InRepo()
        echo 'Not in a repo'
        return
    endif

    # look for all function definitions in the current repo
    try
        # Do *not* use `:noa`.{{{
        #
        # If `:lvim` needs to look into a  file which is already open in another
        # Vim instance,  there is  a risk  that `E325` is  raised.  And  if that
        # happens, you might not be able to see the message, which is confusing,
        # because it  looks like Vim  is blocked.  The  issue is triggered  by a
        # combination of `:sil` and `try/catch`.
        #
        # You  can work  around it  with an  autocmd listening  to `SwapExists`,
        # which we currently have in our vimrc.  But `:noa` would suppress it.
        #
        # ---
        #
        # Also, `:noa` would suppress `Syntax`,  which in turn would prevent the
        # files in which `:lvim` looks for from being highlighted:
        #
        #     $ vim -Nu NONE --cmd 'syn on' +'noa lvim /autocmd/ $VIMRUNTIME/filetype.vim'
        #}}}
        sil lvim /^\C\s*\%(fu\%[nction]\|def\)\s\+/ ./**/*.vim
    # E480: No match: ...
    catch /^Vim\%((\a\+)\)\=:E480:/
        echo 'Could not find any function in the repo'
        return
    endtry
    var functions = getloclist(0)->mapnew((_, v) => v.text->matchstr('[^ (]*\ze('))

    # build a list of unused functions
    var unused: list<string> = []
    for afunc in functions
        var pat = afunc
        if afunc[: 1] == 's:'
            pat ..= '\|<sid>' .. afunc[2 :]
        endif
        exe 'sil lvim /\C\%(' .. pat .. '\)(/ ./**/*.vim'
        # the name of an unused function appears only once
        if getloclist(0, {size: 0}).size <= 1
            unused += [afunc]
        endif
    endfor

    # report unused functions if any
    if empty(unused)
        lclose
        echo 'No unused function in ' .. getcwd()
    else
        setloclist(0, [], 'f')
        exe 'lvim /\C\%(' .. join(unused, '\|')  .. '\)(/ ./**/*.vim'
    endif
enddef

def InRepo(): bool
    var bufname = expand('<afile>:p')->resolve()
    var dir = isdirectory(bufname) ? bufname : fnamemodify(bufname, ':h')
    var dir_escaped = escape(dir, ' ')
    var match = finddir('.git/', dir_escaped .. ';')
    return !empty(match)
enddef

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
            Mapping()
            return
        else
            sil exe 'sp ' .. filename
            Prettify()
            Mapping()
        endif
    elseif n =~ '^\d\.\d\s*-\s*\d\.\d$'
        var first: string
        var last: string
        [first, last] = matchlist(n, '\(\d\.\d\)\s*-\s*\(\d\.\d\)')[1 : 2]
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

def Mapping()
    # We often press `x` instead of `gx` by accident.
    nmap <buffer><nowait> x gx
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

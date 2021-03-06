vim9script noclear

import Catch from 'lg.vim'
import LOGFILE_CHAN from '../plugin/debug.vim'

def debug#cleanLog() #{{{1
    # clean Vim keylog (obtained with `$ vim -w keylog`)
    if search('\%x80') > 0
        # Those sequences don't match any key pressed interactively.{{{
        #
        # For example, this one:
        #
        #     <80>ý`
        #
        # matches the pseudo-key `<CursorHold>`:
        #
        #     :echo "\<CursorHold>"
        #     <80><fd>`˜
        #}}}
        silent keepjumps keeppatterns :% substitute/\%x80ý[`a]//ge
        # Those sequences match meta chords.{{{
        #
        # For example:
        #
        #     <80>F2 ⇔ M-a
        #     ...
        #     <80>F9 ⇔ M-h
        #     <80>FA ⇔ M-i
        #     ...
        #     <80>FR ⇔ M-z
        #}}}
        silent keepjumps keeppatterns :% substitute/\%x80F\([2-9A-R]\)/\=CleanVimKeylogRep()/ge
        return
    endif

    # clean event log (obtained with `:LogEvents`)
    if getline(1) !~ '\d\{2}:\d{2}'
        :1 delete _
        if getline(1) =~ '\<VimResized\>'
            silent :1,/^\S/-1 delete _
        endif
    endif
    silent keepjumps keeppatterns :% substitute/^.\{7}//e
    silent keepjumps keeppatterns global/^\%(OptionSet\|SourcePre\|SourcePost\)\s/ :.,/^\S\|\%$/-1 delete _
    silent keepjumps keeppatterns global/^\s*afile: "$/delete _
    execute 'silent keepjumps keeppatterns :% substitute/^\S\+\s\+amatch:\s*\zs' .. escape($HOME, '/') .. '/\~/e'
enddef

def CleanVimKeylogRep(): string
    var s: string = "\<Esc>"
    var m: string = submatch(1)
    if m =~ '^\d$'
        s ..= (m->char2nr() + 47)->nr2char()
    else
        s ..= (m->char2nr() + 40)->nr2char()
    endif
    return s
enddef

def debug#helpAboutLastErrors(): string #{{{1
    var messages: list<string> = execute('messages')->split('\n')->reverse()
    var pat_error: string = '^\%('
        # When an error occurs inside a try conditional, Vim prefixes an error message with:{{{
        #
        #     Vim:
        #
        # or:
        #
        #     Vim({cmd}):
        #}}}
        .. 'Vim\%((\a\+)\)\=:'
        # In a buffer containing the word 'the', execute:{{{
        #
        #     :global/the/ .w >>/tmp/some_file
        #
        # It raises this error message:
        #
        #     "/tmp/some_file" E212: Can't open file for writing˜
        #}}}
        .. '\|".\{-}"\s\)'
        .. '\=\zsE\d\+'

    # index of most recent error
    var i: number = match(messages, pat_error)
    # index of next line which isn't an error, nor belongs to a stack trace
    var j: number = match(messages, '^\%(' .. pat_error .. '\|Error\|line\)\@!', i + 1)
    if j == -1
        j = i + 1
    endif

    var errors: list<string> = messages[i : j - 1]
        ->map((_, v: string) => v->matchstr(pat_error))
        # remove lines  which don't contain  an error,  or which contain  the errors
        # E662 / E663 / E664 (they aren't interesting and come frequently)
        ->filter((_, v: string): bool => !empty(v) && v !~ '^E66[234]$')
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

    return 'help ' .. get(last_errors.taglist, last_errors.pos, last_errors.taglist[0])
enddef
var last_errors: dict<any> = {taglist: [], pos: -1}

def debug#lastPressedKeys() #{{{1
    if stridx(&runtimepath, '/tmux,') == -1
        echo 'vim-tmux needs to be installed'
        return
    elseif $VIMSERVER != ''
        tmux#run#command('vim +"call debug#lastPressedKeys()"')
    else
        # don't dump the keys in an important buffer
        if expand('%:p') != '' || (line('$') + 1)->line2byte() > 2
            new
        endif
        execute 'silent read ' .. LOGFILE_CHAN
        silent vglobal/ : raw key input/delete _
        #     123.456 : raw key input: "x"
        #     →
        #     123s "x"
        silent :% substitute/^\s*\(\d\+\)\.\d\+\s*:\s*raw key input\s*:\s*/\1s /e
    endif
enddef

def debug#logOptions() #{{{1
    var logfile: string = '/tmp/vim_options.txt'
    execute('set!')
        ->split('\n')
        ->writefile(logfile)
    execute 'split ' .. logfile
enddef

def debug#messages() #{{{1
    :0 Verbose messages
    # If `:Verbose` encountered an error, we could still be in a regular window,
    # instead  of the  preview window.   If that's  the case,  we don't  want to
    # remove any text in the current buffer, nor install any match.
    if !&l:previewwindow
        return
    endif

    # From a help buffer, the buffer displayed in a newly opened preview
    # window inherits some settings, such as 'nomodifiable' and 'readonly'.
    # Make sure they're disabled so that we can remove noise.
    &l:modifiable = true
    &l:readonly = false

    var noises: dict<string> = {
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

    for noise: string in noises->values()
        execute 'silent global/^' .. noise .. '$/delete _'
    endfor

    matchadd('ErrorMsg', '^E\d\+:\s\+.*', 0)
    matchadd('ErrorMsg', '^Vim.\{-}:E\d\+:\s\+.*', 0)
    matchadd('ErrorMsg', '^Error detected while processing.*', 0)
    matchadd('LineNr', '^line\s\+\d\+:$', 0)
    cursor('$', 0)
enddef

def debug#time(cmd: string, cnt: number) #{{{1
    var time: list<number> = reltime()
    try
        # We could  get rid of the  if/else/endif, and shorten the  code, but we
        # won't do it, because the most usual case is `cnt = 1`.  And we want to
        # execute `cmd` as fast as possible  (no let, no while loop), because Ex
        # commands are slow.
        if cnt > 1
            var i: number = 0
            while i < cnt
                execute cmd
                ++i
            endwhile
        else
            execute cmd
        endif
    catch
        Catch()
        return
    finally
        # We  clear the  screen  before  displaying the  results,  to erase  the
        # possible messages displayed by the command.
        redraw
        echomsg reltime(time)
            ->reltimestr()
            ->matchstr('.*\....') .. ' seconds to run :' .. cmd
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
        # Do *not* use `:noautocmd`.{{{
        #
        # If `:lvimgrep`  needs to  look into  a file which  is already  open in
        # another Vim instance,  there is a risk that `E325`  is raised.  And if
        # that  happens, you  might not  be able  to see  the message,  which is
        # confusing,  because  it looks  like  Vim  is  blocked.  The  issue  is
        # triggered by a combination of `:silent` and `try/catch`.
        #
        # You  can work  around it  with an  autocmd listening  to `SwapExists`,
        # which we currently have in our vimrc.  But `:noautocmd` would suppress it.
        #
        # ---
        #
        # Also,  `:noautocmd`  would  suppress  `Syntax`, which  in  turn  would
        # prevent  the  files   in  which  `:lvimgrep`  looks   for  from  being
        # highlighted:
        #
        #     syntax on
        #     noautocmd lvimgrep /autocmd/ $VIMRUNTIME/filetype.vim
        #}}}
        silent lvimgrep /^\C\s*\%(fu\%[nction]\|def\)\s\+/ ./**/*.vim
    # E480: No match: ...
    catch /^Vim\%((\a\+)\)\=:E480:/
        echo 'Could not find any function in the repo'
        return
    endtry
    var functions: list<string> = getloclist(0)
        ->mapnew((_, v: dict<any>): string => v.text->matchstr('[^ (]*\ze('))

    # build a list of unused functions
    var unused: list<string>
    for afunc: string in functions
        var pat: string = afunc
        if afunc[: 1] == 's:'
            pat ..= '\|<SID>' .. afunc[2 :]
        endif
        execute 'silent lvimgrep /\C\%(' .. pat .. '\)(/ ./**/*.vim'
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
        execute 'lvimgrep /\C\%(' .. unused->join('\|')  .. '\)(/ ./**/*.vim'
    endif
enddef

def InRepo(): bool
    var bufname: string = expand('<afile>:p')->resolve()
    var dir: string = isdirectory(bufname) ? bufname : bufname->fnamemodify(':h')
    var dir_escaped: string = escape(dir, ' ')
    var match: string = finddir('.git/', dir_escaped .. ';')
    return !empty(match)
enddef

def debug#vimPatches(n: string, append = false) #{{{1
    if n == ''
        var msg: list<string> =<< trim END
            provide a major Vim version number

            usage example:

                VimPatches 8.2
                VimPatches 7.4 - 8.2
        END
        echo msg->join("\n")
    elseif index(MAJOR_VERSIONS, n) >= 0
        var filename: string = 'ftp://ftp.vim.org/pub/vim/patches/' .. n .. '/README'
        if append
            var bufnr: number = bufadd(filename)
            bufload(bufnr)
            getbufline(bufnr, 1, '$')->append('$')
            execute 'bwipeout! ' .. bufnr
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
            autocmd SafeState * ++once silent! global/^\n\n\|\%^$\|\%$$/delete _
            #                                              ^----------^
            #                                              also delete the first and last empty lines
        elseif bufloaded(filename)
            Display(filename)
            Mapping()
            return
        else
            execute 'silent split ' .. filename
            debug#vimPatchesPrettify()
            Mapping()
        endif
    elseif n =~ '^\d\.\d\s*-\s*\d\.\d$'
        var first: string
        var last: string
        [first, last] = matchlist(n, '\(\d\.\d\)\s*-\s*\(\d\.\d\)')[1 : 2]
        if index(MAJOR_VERSIONS, first) == -1
            Error(first .. ' is not a valid major Vim version')
            return
        elseif index(MAJOR_VERSIONS, last) == -1
            Error(last .. ' is not a valid major Vim version')
            return
        endif
        var filename: string = 'VimPatches ' .. n
        if bufloaded(filename)
            Display(filename)
            return
        endif
        new
        execute 'file ' .. fnameescape(filename)
        var ifirst: number = index(MAJOR_VERSIONS, first)
        var ilast: number = index(MAJOR_VERSIONS, last)
        var numbers: list<string> = MAJOR_VERSIONS[ifirst : ilast]
        for number: string in numbers
            debug#vimPatches(number, true)
        endfor
        debug#vimPatchesPrettify()
    else
        Error('invalid argument')
    endif
enddef

def Mapping()
    # We often press `x` instead of `gx` by accident.
    nmap <buffer><nowait> x gx
enddef

def Display(filename: string)
    var winid: number = bufnr(filename)->win_findbuf()->get(-1)
    if winid > 0
        win_gotoid(winid)
    else
        execute 'split ' .. filename
    endif
enddef

def Error(msg: string)
    echohl ErrorMsg
    echomsg msg
    echohl NONE
enddef

def debug#vimPatchesPrettify() #{{{1
    # no modified indicator in the status line if we edit the buffer
    &l:buftype = 'nofile'
    &l:buflisted = false
    &l:swapfile = false
    &l:wrap = false

    # remove noise
    silent global/^Patches for Vim/ :.;/^\s*SIZE/ delete _
    silent! global/^--- The story continues with Vim /delete _
    silent keepjumps keeppatterns :% substitute/^\s*\d\+\s\+//e

    # format links
    silent keepjumps keeppatterns :% substitute@^[0-9.]\+@[&](https://github.com/vim/vim/releases/tag/v&)@e

    # conceal url (copied from the markdown syntax plugin)
    syntax match xUrl /\S\+/ contained
    syntax region xLinkText matchgroup=xLinkTextDelimiter
        \ start=/!\=\[\ze\_[^]]*] \=[[\x28]/ end=/\]\ze \=[[\x28]/
        \ nextgroup=xLink keepend concealends skipwhite
    syntax region xLink matchgroup=xLinkDelimiter
        \ start=/(/ end=/)/
        \ contained keepend conceal contains=xUrl
    highlight def link xLinkText Underlined
    highlight def link xUrl Float
    &l:conceallevel = 3
    &l:concealcursor = 'nc'
enddef

def debug#vimPatchesCompletion(_, _, _): string #{{{1
    return MAJOR_VERSIONS->join("\n")
enddef

const MAJOR_VERSIONS: list<string> =<< trim END
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

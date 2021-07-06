vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# TODO: Implement a command which would tell us which rule governs the indentation of a given line.
#
# https://vi.stackexchange.com/a/25338/17449
# https://vi.stackexchange.com/a/25204/17449


# Log Channel Activity {{{1

const LOG_CHANNEL_ACTIVITY: bool = true
export const LOGFILE_CHAN: string = '/tmp/vim_channel_activity.log'

augroup LogChannelActivity
    # we need to delay until `VimEnter` so that `v:servername` has been set
    autocmd VimEnter * LogChannelActivity()
augroup END

def LogChannelActivity()
    if LOG_CHANNEL_ACTIVITY
    # only log the activity of our main Vim instance
    && v:servername != ''
        ch_logfile(LOGFILE_CHAN, 'w')
        def ReduceLogfile()
            # For now, we're only interested in the keys we've typed (interactively).
            var keep_only_this: string = 'raw key input'
            var cmd: string = printf(
                # Do *not* use `sed(1)`.{{{
                #
                #     sed -i '/pattern/!d' "$LOGFILE_CHAN"
                #         ^^
                #         ✘
                #
                # It would temporarily  delete the logfile which  would stop Vim
                # from logging channel activity.
                #}}}
                'vim -es -Nu NONE -U NONE -i NONE +"vglobal/%s/delete _" +"update | quitall!" "%s"',
                keep_only_this,
                LOGFILE_CHAN
            )
            job_start(cmd, {
                mode: 'raw',
                noblock: true,
            })
        enddef
        # The logged channel activity is very verbose.
        # Reduce it on a regular interval.
        # 10 minutes sounds good.
        #
        #     timer_start(1'000'000, (_) => ReduceLogfile(), {repeat: -1})
        #
        # Commented at  the moment because we  need as much info  as possible to
        # debug this: https://github.com/vim/vim/issues/7891
    endif
enddef

# Autocmds {{{1

augroup MyDebug | autocmd!
    autocmd BufNewFile /tmp/*/timer_info debug#timer#populate()
    autocmd BufReadPost ftp://ftp.vim.org/pub/vim/patches/*/README debug#vimPatchesPrettify()
augroup END

# Commands {{{1

# Purpose:{{{
#
# Our command-line mappings might badly interfere when we use `:debug`.
# Same thing for some autocmds listening to `CmdlineLeave`.
# We install `:Debug` as a thin wrapper which temporarily disable them.
#
# ---
#
# Also, `:debug` doesn't provide any completion for script-local functions.
# And yet, you *can* pass to `:debug` any function name.
# Again, our wrapper fixes that.
#}}}
# What happens if I use a custom mapping while in debug mode?{{{
#
# You'll see  the first  line of  the function  which it  calls (it  happens for
# example with `C-t` ; transpose-chars).  And, you'll step through it.
#}}}
#   What to do in this case?{{{
#
# Execute `cont` to get out.
#
# If you have used one of our custom editing command several times, you'll
# have to re-execute `cont` as many times as needed.
#}}}
command -bar -nargs=1 -complete=customlist,debug#debug#completion Debug debug#debug#wrapper(<q-args>)

# Wrappers around some debugging commands which don't provide completion for function names.{{{
#
# It's especially useful to fix that for  the names of functions which are local
# to a script.
#}}}
cnoreabbrev <expr> ba getcmdtype() == ':' && getcmdpos() == 3 ? 'Breakadd' : 'ba'
command -bar -nargs=1 -complete=customlist,debug#break#completion Breakadd debug#break#wrapper('add', <q-args>)
command -bar -nargs=1 -complete=customlist,debug#break#completion Breakdel debug#break#wrapper('del', <q-args>)
command -bar -bang -nargs=? -complete=customlist,debug#prof#completion Prof debug#prof#wrapper(<q-bang>, <q-args>)

# Purpose:{{{
# Wrapper around commands such as `:breakadd file */ftplugin/sh.vim`.
# Provides a usage message, and smart completion.
#
# Useful to debug a filetype/indent/syntax plugin.
#}}}
command -bar -nargs=* -complete=custom,debug#localPlugin#complete DebugLocalPlugin
    \ debug#localPlugin#main(<q-args>)

command -bar DebugMappingsFunctionKeys debug#mappings#usingFunctionKeys()

# `:DebugTerminfo` dumps the termcap db of the current Vim instance
# `:DebugTerminfo!` prettifies the termcap db written in the current file
command -bar -bang DebugTerminfo debug#terminfo#main(<bang>0)

# Sometimes, after a  refactoring, we forget to remove some  functions which are
# no longer necessary.  This command should list them in the location window.
# Warning: It might  give false  positives, because a  function may  appear only
# once in a plugin, but still be called from another plugin.
command -bar DebugUnusedFunctions debug#unusedFunctions()

command -bar Scriptnames debug#scriptnames#main()

# Since Vim's patch 8.1.1241, a range seems to be, by default, interpreted as a line address.{{{
#
# But here, we don't use the range as a line address, but as an arbitrary count.
# And it's possible that we give a count which is bigger than the number of lines in the current buffer.
# If that happens, `E16` will be raised:
#
#     :command -range=1 Cmd echo ''
#     :new
#     :3 Cmd
#     E16: Invalid range˜
#
# Here's the patch 8.1.1241:
# https://github.com/vim/vim/commit/b731689e85b4153af7edc8f0a6b9f99d36d8b011
#
# ---
#
# Solution: use the additional attribute `-addr=other`:
#
#                       v---------v
#     :command -range=1 -addr=other Cmd echo ''
#     :new
#     :3 Cmd
#
# I think it specifies that the type of  the range is not known (i.e. not a line
# address, not a buffer number, not a window number, ...).
#}}}
command -range=1 -addr=other -nargs=+ -complete=command Time debug#time(<q-args>, <count>)
# Do *not* give the `-bar` attribute to `:Verbose`.
command -range=1 -addr=other -nargs=1 -complete=command Verbose
    \ debug#log#output({level: <count>, excmd: <q-args>})

command -bar -nargs=1 -complete=option Vo debug#verbose#option(<q-args>)

command -bar -nargs=? -complete=custom,debug#vimPatchesCompletion VimPatches debug#vimPatches(<q-args>)

# Mappings {{{1
# C-x C-v   evaluate variable under cursor while on command-line{{{2

cnoremap <unique> <C-X><C-V> <C-\>e debug#cmdline#evalVarUnderCursor()<CR>

# dg C-l    clean log {{{2

nnoremap <unique> dg<C-L> <Cmd>call debug#cleanLog()<CR>

# g!        last page in the output of last command {{{2

# Why?{{{
#
# `g!` is easier to type.
# `g<` could be used with `g>` to perform a pair of opposite actions.
#}}}
nnoremap <unique> g! g<

# !c        capture variable {{{2

# This mapping is useful to create a copy of a variable local to a function or a
# script into the global namespace, for debugging purpose.

# `!c` captures the latest value of a variable.
# `!C` captures all the values of a variable during its lifetime.
nnoremap <expr><unique> !c debug#capture#setup(v:false)
nnoremap <expr><unique> !C debug#capture#setup(v:true)

# !d        echo g:d_* {{{2

nnoremap <unique> !d <Cmd>call debug#capture#dump()<CR>

# !e        show help about last error {{{2

# Description:
# You execute some function/command which raises one or several errors.
# Press `!e` to open the help topic explaining the last one.
# Repeat to cycle through all the help topics related to the rest of the errors.

# An intermediate `<Plug>`  mapping is necessary to make  the mapping repeatable
# via our submode api.
nmap <unique> !e <Plug>(help-last-errors)
nnoremap <Plug>(help-last-errors) <Cmd>execute debug#helpAboutLastErrors()<CR>

# !K        show last pressed keys {{{2

nnoremap <unique> !K <Cmd>call debug#lastPressedKeys()<CR>

# !m        show messages {{{2

nnoremap <unique> !m <Cmd>call debug#messages()<CR>

# !M        clean messages {{{2

nnoremap <unique> !M <Cmd>messages clear <Bar> echo 'messages cleared'<CR>

# !o        paste Output of last Ex command  {{{2

nmap <expr><unique> !o debug#output#lastExCommand()

# !O        log Vim options {{{2

nnoremap <unique> !O <Cmd>call debug#logOptions()<CR>

# !s        show syntax groups under cursor {{{2

# Usage:
# all these commands apply to the character under the cursor
#
#     !s     show the names of all syntax groups
#     1!s    show the definition of the innermost syntax group
#     3!s    show the definition of the 3rd syntax group

nnoremap <unique> !s <Cmd>call debug#synnames#main(v:count)<CR>

# !S        autoprint stack items under the cursor {{{2

nnoremap <unique> !S <Cmd>call debug#autoSynstack#main()<CR>

# !T        measure time to do task {{{2

nnoremap <unique> !T <Cmd>call debug#timer#measure()<CR>

# !t        show info about running timers {{{2

nnoremap <unique> !t <Cmd>call debug#timer#infoOpen()<CR>


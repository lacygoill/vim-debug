fu! debug#vimrc#main() abort "{{{1
    if !exists('$TMUX')
        return 'echoerr "Only works inside Tmux"'
    endif

    " open a new file to use as a temporary vimrc
    new $XDG_RUNTIME_VIM/debug_vimrc
    " wipe the buffer when it becomes hidden
    " useful to not have to remove the next buffer-local autocmd
    setl bh=wipe nobl noswf
    " disable automatic saving
    sil call save#toggle_auto(0)
    " make sure the file is empty
    %d_
    " import our current vimrc
    sil 0r $MYVIMRC
    " write the file
    sil update
    " Every time  we'll change  and write  our temporary vimrc,  we want  Vim to
    " start a new Vim  instance, in a new tmux pane, so that  we can begin a new
    " test. We build the necessary tmux command.
    let s:vimrc = {}
    let s:vimrc.cmd  = 'tmux split-window -c $XDG_RUNTIME_VIM'
    let s:vimrc.cmd .= ' -v -p 50'
    let s:vimrc.cmd .= ' -PF "#D"'
    let s:vimrc.cmd .= ' vim -Nu $XDG_RUNTIME_VIM/debug_vimrc'

    augroup my_debug_vimrc
        au! * <buffer>
        " start a Vim session sourcing the new temporary vimrc in a tmux pane
        au BufWritePost <buffer> call s:vimrc_act_on_pane(1)
        au BufWipeOut   <buffer> sil call save#toggle_auto(1)
        \ |                      call s:vimrc_act_on_pane(0)
        " close pane when we leave (useful if we restart with SPC R)
        au VimLeave * call s:vimrc_act_on_pane(0)
    augroup END
    return ''
endfu

fu! s:vimrc_act_on_pane(open) abort "{{{1
    " if there's already a tmux pane opened to debug Vim, kill it
    sil if get(get(s:, 'vimrc', ''), 'pane_id', -1) !=# -1
    \ &&  stridx(system('tmux list-pane -t %'.s:vimrc.pane_id),
    \            "can't find pane %".s:vimrc.pane_id) ==# -1
        sil call system('tmux kill-pane -t %'.s:vimrc.pane_id)
    endif
    if a:open
        " open  a tmux  pane, and  start a  Vim instance  with the  new modified
        " minimal vimrc
        let s:vimrc.pane_id = systemlist(s:vimrc.cmd)[0][1:]
    else
        unlet! s:vimrc
    endif
endfu


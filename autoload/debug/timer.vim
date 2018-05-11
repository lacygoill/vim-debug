fu! s:format_info(v) abort "{{{1
    return ['id: '.a:v.id,
          \ 'repeat: '.a:v.repeat,
          \ 'remaining: '.a:v.remaining,
          \ 'time: '.a:v.time,
          \ 'paused: '.a:v.paused,
          \ 'callback: '.string(a:v.callback),
          \ ]
endfu

fu! debug#timer#info() abort "{{{1
    let infos = timer_info()
    call map(infos, {i,v -> s:format_info(v)})
    if empty(infos)
        echo 'No timer is currently running'
        return
    endif
    new
    let lines = []
    for info in infos
        let lines += info
    endfor
    call setline(1, lines)
endfu


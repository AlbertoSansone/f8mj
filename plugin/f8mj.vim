if !exists('g:flake8_env')
    let g:flake8_env = ''
endif

augroup f8mj
    autocmd!
    autocmd BufEnter,BufRead,BufNew *.py :let b:flake8_buffer_info = Flake8BufferInfo()
    autocmd BufEnter,BufRead,BufNew *.py :let b:flake8_message_regex = '\('.expand('%').'\):\(\d\+\):\(\d\+\):\W*\([A-Z]\)\(\d\+\)\W*\(.*\)'
    autocmd TextChanged,TextChangedI *.py :let b:flake8_evaluated = 0
    autocmd BufEnter *.py nnoremap <leader>f8 :call RunFlake8()<CR>
    autocmd BufEnter *.py nnoremap <F8> :call RunFlake8()<CR>
    autocmd BufRead,BufNew *.py nnoremap <buffer> < <ESC>:call JumpToNext(-1)<CR>
    autocmd BufRead,BufNew *.py nnoremap <buffer> > <ESC>:call JumpToNext(1)<CR>
augroup END

function! Flake8BufferInfo()
    let result = {}
    let result.evaluated = 0
    let result.filename = ''
    let result.parsed_messages = []
    let result.curr_index = -1
    let result.env_folder = g:flake8_env
    return result
endfunction

function! RunFlake8()
    let b:flake8_buffer_info.filename = expand("%")
    let l:flake8_command = "flake8 ".expand("%")
    if exists('g:flake8_env')
        let l:env_activate = 'source '.b:flake8_buffer_info.env_folder.'/bin/activate;'
        let l:flake8_command = l:env_activate.l:flake8_command.';deactivate'
    else
        let l:env_activate = ''
    endif
    echom "running flake8 for ".b:flake8_buffer_info.filename
    echom "terminou de executar flake8. parseando resultado..."
    let l:flake8_result_lines = split(system(l:flake8_command), '\n')
    let b:flake8_buffer_info.evaluated = 1
    for line_index in range(len(l:flake8_result_lines))
        let line = l:flake8_result_lines[line_index]
        let line_matches = matchlist(line, b:flake8_message_regex)
        if len(line_matches) < 7
            continue
        endif
        let parsed_message = {}
        let parsed_message.raw = line_matches[0]
        let parsed_message.file = line_matches[1]
        let parsed_message.line = line_matches[2]
        let parsed_message.column = line_matches[3]
        let parsed_message.code_type = line_matches[4]
        let parsed_message.code_id = line_matches[5]
        let parsed_message.text = line_matches[6]
        call add(b:flake8_buffer_info.parsed_messages, parsed_message)
    endfor
    echom "Terminou flake8"
    if exists('g:flake8_env')
        call system('deactivate')
    endif
endfunction

function! JumpToNext(step)
    let l:len_messages = len(b:flake8_buffer_info.parsed_messages)
    if l:len_messages == 0
        echo 'No flake8 messages!'
        return 1
    endif
    let b:flake8_buffer_info.curr_index += a:step
    if b:flake8_buffer_info.curr_index < 0
        let b:flake8_buffer_info.curr_index = l:len_messages - 1
    elseif b:flake8_buffer_info.curr_index > l:len_messages - 1
        let b:flake8_buffer_info.curr_index = 0
    endif
    let l:curr_message = b:flake8_buffer_info.parsed_messages[b:flake8_buffer_info.curr_index]
    call cursor(l:curr_message.line, l:curr_message.column)
    redraw | call EchoFlake8MessageBuffer(5)
endfunction

function! EchoFlake8MessageBuffer(context)
    let messages = []
    let ci = b:flake8_buffer_info.curr_index
    for mi in range(len(b:flake8_buffer_info.parsed_messages))
        let m = b:flake8_buffer_info.parsed_messages[mi]
        if (mi < ci) && (ci - mi <= a:context)
            let m_str = m.raw
        elseif ci == mi
            let l = len(b:flake8_buffer_info.parsed_messages)
            let m_str = m.raw
            let m_str = (mi+1).'/'.l.'>>> '.m_str
        elseif (mi > ci) && (mi - ci <= a:context)
            let m_str = m.raw
        else
            continue
        endif
        call add(messages, m_str)
    endfor
    let result = join(messages, "\n")
    echo result
endfunction

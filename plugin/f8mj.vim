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
    return result
endfunction

function! RunFlake8()
    let b:flake8_buffer_info.parsed_messages = []
    let b:flake8_buffer_info.filename = expand("%")
    let l:flake8_command = "flake8 ".expand("%")
    if exists('g:flake8_env')
        let l:env_activate = 'source '.g:flake8_env.'/bin/activate;'
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
    highlight Flake8Message ctermbg=lightred ctermfg=red cterm=bold
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
    execute 'normal zz'
    let b:curr_line_pattern = '\%'.l:curr_message.line.'l'
    let w:line_error_match = matchadd('Flake8Message', b:curr_line_pattern, -1)
    echom w:line_error_match
    redraw | call EchoFlake8MessageBuffer(5)
    call matchdelete(w:line_error_match)
endfunction

function! EchoFlake8MessageBuffer(context)
    let messages = []
    let ci = b:flake8_buffer_info.curr_index
    let l = len(b:flake8_buffer_info.parsed_messages)
    for mi in range(len(b:flake8_buffer_info.parsed_messages))
        let m = b:flake8_buffer_info.parsed_messages[mi]
        if (mi < ci) && (ci - mi <= a:context)
            let m_str = '  '.m.raw
        elseif ci == mi
            let m_str = m.raw
            let m_str = '> '.m_str
        elseif (mi > ci) && (mi - ci <= a:context)
            let m_str = '  '.m.raw
        else
            continue
        endif
        call add(messages, m_str)
    endfor
    let status = (ci + 1).'/'.l
    call add(messages, status)
    let result = join(messages, "\n")
    echo result
endfunction

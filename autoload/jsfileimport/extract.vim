function! jsfileimport#extract#_variable(word) abort
  if a:word =~? '^\(\s\|\t\)*\(const\|let\|var\)\s'
    throw 'Cannot extract variable.'
  endif

  if a:word =~? 'return\s'
    throw 'Cannot extract code with return.'
  endif

  let l:var_name = jsfileimport#utils#_get_input('Enter variable name: ')

  silent! exe 'redraw'
  let l:type = confirm('Type: ', "&Const\n&Let\n&Var")
  if l:type < 1
    return 0
  endif

  let l:types = ['const', 'let', 'var']
  silent! exe 'norm! I'.l:types[l:type - 1].' '.l:var_name.' = '
endfunction

function! jsfileimport#extract#_method(word) abort
  let l:choice_list = ['Global']
  let l:file_info = jsfileimport#utils#_get_file_info()

  if l:file_info['in_class']
    call add(l:choice_list, 'Class')
  endif
  if l:file_info['in_method']
    call add(l:choice_list, 'Local function')
  endif

  let l:methods = {
  \ 'Global': 's:extract_global_function',
  \ 'Local function': 's:extract_local_function',
  \ 'Class': 's:extract_class_method'
  \ }

  if len(l:choice_list) ==? 1
    return s:extract_global_function(l:file_info)
  endif

  let l:type = jsfileimport#utils#_get_confirm_selection('Extract to', l:choice_list)
  let l:method = get(l:methods, l:type)

  return call(l:method, [l:file_info])
endfunction

function! s:extract_local_function(file_info) abort
  let l:fn_name = jsfileimport#utils#_get_input('Enter function name')
  let l:fn = s:get_fn_data(a:file_info)

  silent! exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].l:fn_name.'();'

  let l:format_options = &formatoptions
  set formatoptions-=ro
  let l:content = substitute(l:fn['content'], '\\n', "\<CR>", 'g')
  silent! exe 'norm! Oconst '.l:fn_name.' = '.l:fn['async']."() => {\<CR>".l:content."\<CR>};\<CR>"
  silent! exe 'norm! kV%=V%='
  let &formatoptions = l:format_options
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:extract_class_method(file_info) abort
  let l:method_name = jsfileimport#utils#_get_input('Enter method name')
  let l:fn = s:get_fn_data(a:file_info)

  let l:args = copy(l:fn['arguments'])
  call filter(l:args, {idx, val -> val !~ 'this'})
  let l:args = join(l:args, ', ')

  silent! exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].'this.'.l:method_name.'('.l:args.');'

  if a:file_info['in_method']
    call cursor(a:file_info['method']['line'], 0)
    silent! exe "norm! $%o\<CR>"
  else
    call cursor(a:file_info['class']['line'], 0)
    silent! exe "norm! $o\<CR>"
  endif

  let l:format_options = &formatoptions
  set formatoptions-=ro
  let l:content = substitute(l:fn['content'], '\\n', "\<CR>", 'g')
  silent! exe 'norm!cc'.l:fn['async'].l:method_name.'('.l:args.") {\<CR>".l:content."\<CR>}"
  silent! exe 'norm! V%=V%='
  let &formatoptions = l:format_options
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:extract_global_function(file_info) abort
  let l:fn_name = jsfileimport#utils#_get_input('Enter function name')
  let l:fn = s:get_fn_data(a:file_info)
  let l:args = join(l:fn['arguments'], ', ')

  silent! exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].l:fn_name.'('.l:args.');'
  if a:file_info['in_class']
    call cursor(a:file_info['class']['line'], 0)
    silent! exe 'norm! Oconst'
  elseif a:file_info['in_method']
    call search('^[[:blank:]]*$', 'b')
    silent! exe "norm! ccconst"
  else
    silent! exe 'norm! ccconst'
  endif

  let l:fnArgs = substitute(l:args, '\<this\>', 'self', 'g')
  let l:fnContent = substitute(l:fn['content'], '\<this\>', 'self', 'g')
  let l:fnContent = substitute(l:fnContent, '\\n', "\<CR>", 'g')
  let l:format_options = &formatoptions
  set formatoptions-=ro
  silent! exe 'norm! a '.l:fn_name.' = '.l:fn['async'].'('.l:fnArgs.") => {\<CR>".l:fnContent."\<CR>};\<CR>"
  silent! exe 'norm! kV%=V%='
  let &formatoptions = l:format_options
  call cursor(a:file_info['current_line'], a:file_info['current_column'])
endfunction

function! s:get_fn_data(file_info)
  let l:selection = jsfileimport#utils#_get_selection()
  if len(l:selection) <=? 0
    throw 'No selection.'
  endif

  let l:selectionNoComments = copy(l:selection)
  call filter(l:selectionNoComments, { idx, val -> val !~? '^[[:blank:]]*\(\/\/\|*\)' })
  let l:args = jsfileimport#parser#_parse_args(copy(l:selectionNoComments), a:file_info)
  let l:returns = jsfileimport#parser#_parse_returns(copy(l:selectionNoComments), a:file_info)
  let l:return_fn = []
  let l:vars = ''

  if l:selection[-1] =~? 'return'
    call add(l:return_fn, 'return')
  elseif len(l:returns) > 0
    let l:return_vars = join(l:returns, ', ')
    if len(l:returns) > 1
      let l:return_vars = printf('{ %s }', l:return_vars)
    endif
    let l:vars = printf('const %s = ', l:return_vars)
    call add(l:selection, printf('return %s;', l:return_vars))
  endif

  let l:content = join(l:selection, '\n')

  if l:content =~? '\<await\>'
    call add(l:return_fn, 'await')
  endif

  let l:return_fn = join(l:return_fn, ' ')
  let l:return_fn .= (strlen(l:return_fn) > 0 ? ' ' : '')

  return {
  \ 'content' : l:content,
  \ 'arguments': l:args,
  \ 'return_fn': l:return_fn,
  \ 'vars': l:vars,
  \ 'async': l:content =~? 'await' ? 'async ' : '',
  \}
endfunction

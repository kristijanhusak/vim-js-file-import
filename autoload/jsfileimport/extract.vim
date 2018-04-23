let s:method_regex = '^[[:blank:]]*\(async\)\?\<[^(]*\>([^)]*)\s*{\s*$'
let s:class_regex = '^[[:blank:]]*\<class\>\s*\<.*\>'
let s:reserved_words = ['if', 'return', 'await', 'async', 'const', 'let', 'var',
      \ 'break', 'true', 'false', 'for', 'try', 'catch', 'finally', 'switch',
      \ 'throw', 'new']

function! jsfileimport#extract#variable() abort
  let l:content = join(jsfileimport#utils#_get_selection(), '\n')

  if l:content =~? '^\(\s\|\t\)*\(const\|let\|var\)\s'
    throw 'Cannot extract variable.'
  endif

  if l:content =~? 'return\s'
    throw 'Cannot extract code with return.'
  endif

  let l:var_name = s:get_input('Enter variable name: ')

  silent exe 'redraw'
  let l:type = confirm('Type: ', "&Const\n&Let\n&Var")
  if l:type < 1
    return 0
  endif

  let l:types = ['const', 'let', 'var']
  silent exe 'norm! I'.l:types[l:type - 1].' '.l:var_name.' = '
endfunction

function! jsfileimport#extract#method() abort
  let l:choice_list = ['&Global']
  let l:has_class = search(s:class_regex, 'nb')
  let l:is_in_method = search(s:method_regex, 'nb')

  if l:has_class > 0
    call add(l:choice_list, '&Class')
  endif
  if l:is_in_method > 0
    call add(l:choice_list, '&Local function')
  endif

  if len(l:choice_list) ==? 1
    return s:extract_global_function(0, 0)
  endif

  let l:type = confirm('Extract to:', join(l:choice_list, "\n"))

  if l:type < 1
    return 0
  endif

  let l:type_name = l:choice_list[l:type - 1]
  if l:type_name =~? 'global'
    return s:extract_global_function(l:has_class, l:is_in_method)
  elseif l:type_name =~? 'class'
    return s:extract_class_method(l:is_in_method)
  endif

  return s:extract_local_function()
endfunction

function! s:extract_local_function() abort
  let l:fn_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:fn = s:get_fn_data()

  silent exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].l:fn_name.'();'

  let l:content = substitute(l:fn['content'], '\\n', "\<CR>\<C-u>", 'g')
  silent exe 'norm! Oconst '.l:fn_name.' = '.l:fn['async']."() => {\<CR>".l:content."\<CR>};\<CR>"
  silent exe 'norm! Va{='
  silent exe l:restorepos
endfunction

function! s:extract_class_method(is_in_method) abort
  let l:method_name = s:get_input('Enter method name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:fn = s:get_fn_data()

  let l:args = copy(l:fn['arguments'])
  call filter(l:args, {idx, val -> val !~ 'this'})
  let l:args = join(l:args, ', ')

  silent exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].'this.'.l:method_name.'('.l:args.');'
  if a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>"
  else
    call search(s:class_regex, 'b')
    silent exe "norm! $o\<CR>"
  endif

  let l:content = substitute(l:fn['content'], '\\n', "\<CR>\<C-u>", 'g')
  silent exe 'norm!cc'.l:fn['async'].l:method_name.'('.l:args.") {\<CR>".l:content."\<CR>}"
  silent exe 'norm! Va{='
  silent exe l:restorepos
endfunction

function! s:extract_global_function(has_class, is_in_method) abort
  let l:fn_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:fn = s:get_fn_data()

  let l:args = join(l:fn['arguments'], ', ')

  silent exe 'norm! gvc'.l:fn['vars'].l:fn['return_fn'].l:fn_name.'('.l:args.');'
  if a:has_class
    call search(s:class_regex, 'b')
    silent exe 'norm! Oconst'
  elseif a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>const"
  else
    silent exe 'norm! cconst'
  endif

  let l:fnArgs = substitute(l:args, '\<this\>', 'self', 'g')
  let l:fnContent = substitute(l:fn['content'], '\<this\>', 'self', 'g')
  let l:fnContent = substitute(l:fn['content'], '\\n', "\<CR>\<C-u>", 'g')
  silent exe 'norm! a '.l:fn_name.' = '.l:fn['async'].'('.l:fnArgs.") => {\<CR>".l:fnContent."\<CR>};\<CR>"
  silent exe 'norm! kVi{='
  silent exe l:restorepos
endfunction

function! s:get_input(question) abort
  silent exe 'redraw'
  let l:var_name = input(a:question.': ', '')
  if l:var_name ==? ''
    throw ''
  endif

  return l:var_name
endfunction

function! s:get_arguments_and_return_values(selection) abort
  let l:rgx = jsfileimport#utils#_determine_import_type()
  call filter(a:selection, { idx, val -> val !~? '^[[:blank:]]*\(\/\/\|*\)' })
  let l:content = join(a:selection, '')
  let l:matches = []
  call substitute(l:content, '\<[A-Za-z0-9_\.]\+\>', '\=add(l:matches, submatch(0))', 'g')

  let l:arguments = []
  let l:returns = []
  let l:scoped_vars = []

  let l:index = 0
  for l:match in l:matches
    if l:index > 0 && index(l:arguments, l:matches[l:index - 1]) > -1
      let l:prev = l:matches[l:index - 1]
      " Setting argument variable to value
      if match(l:content, l:prev.'\s*=\s*'.l:match) > -1 && index(l:returns, l:prev) < 0
        call add(l:returns, l:prev)
      endif
    endif

    if index(s:reserved_words, l:match) > -1 || index(l:scoped_vars, l:match) > -1
      let l:index += 1
      continue
    endif

    " Variables
    if l:index > 0 && l:matches[l:index - 1] =~? '\(const\|let\|var\)'
      let l:prev = l:matches[l:index - 1]
      " Ignore block scoped variables for returning
      let l:is_block_scoped = match(l:content, '{.\{-\}\<'.l:prev.'\s'.l:match.'\>[^}]*}') > -1
      let l:is_brackets_scoped = match(l:content, '([^)]*\<'.l:prev.'\s'.l:match.'\>[^)]*)') > -1
      if index(l:returns, l:match) < 0 && !l:is_block_scoped && !l:is_brackets_scoped
        call add(l:returns, l:match)
      endif
      if l:is_block_scoped || l:is_brackets_scoped
        call add(l:scoped_vars, l:match)
      endif
      let l:index += 1
      continue
    endif

    if l:match =~? '\.'
      let l:match = substitute(l:match, '\..*', '', 'g')
    endif

    if index(l:returns, l:match) > -1
      let l:index += 1
      continue
    endif

    let l:existPattern = substitute(l:rgx['check_import_exists'], '__FNAME__', l:match, '')

    " Ignore imports and duplicates
    if search(l:existPattern, 'n') > 0 || index(l:arguments, l:match) > -1
      let l:index += 1
      continue
    endif

    " Ignore strings
    if match(l:content, '\(''\|"\)[^''"]*\<'.l:match.'\>[^''"]*\(''\|"\)') > -1
      let l:index += 1
      continue
    endif

    " Ignore values in anonymous functions
    if match(l:content, '(.\{-\}=>[^)]*\<'.l:match.'\>[^)]*)') > -1
      let l:index += 1
      continue
    endif

    " Ignore numbers only
    if l:match =~? '^\d*$'
      let l:index += 1
      continue
    endif

    call add(l:arguments, l:match)
    let l:index += 1
  endfor

  return { 'arguments': l:arguments, 'returns': l:returns }
endfunction

function! s:get_fn_data()
  let l:selection = jsfileimport#utils#_get_selection()
  let l:args_and_return_values = s:get_arguments_and_return_values(copy(l:selection))
  let l:return_fn = []
  let l:vars = ''

  if len(l:selection) > 0 && l:selection[-1] =~? 'return'
    call add(l:return_fn, 'return')
  elseif len(l:args_and_return_values['returns']) > 0
    if len(l:args_and_return_values['returns']) ==? 1
      let l:return_vars = l:args_and_return_values['returns'][0]
    else
      let l:return_vars = printf('{ %s }', join(l:args_and_return_values['returns'], ', '))
    endif
    let l:vars = printf('const %s = ', l:return_vars)
    call add(l:selection, printf('return %s;', l:return_vars))
  endif

  let l:content = join(l:selection, '\n')

  if l:content =~? 'await'
    call add(l:return_fn, 'await')
  endif

  let l:return_fn = len(l:return_fn) > 0
    \ ? join(l:return_fn, ' ').' '
    \ : ''

  return {
  \ 'selection': l:selection,
  \ 'content' : l:content,
  \ 'arguments': l:args_and_return_values['arguments'],
  \ 'returns': l:args_and_return_values['returns'],
  \ 'return_fn': l:return_fn,
  \ 'vars': l:vars,
  \ 'async': l:content =~? 'await' ? 'async ' : '',
  \}
endfunction

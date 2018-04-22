let s:method_regex = '^[[:blank:]]*\(async\)\?\<[^(]*\>([^)]*)\s*{\s*$'
let s:class_regex = '^[[:blank:]]*\<class\>\s*\<.*\>'

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
  let l:var_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:selection = jsfileimport#utils#_get_selection()
  let l:content = join(l:selection, '\n')
  let l:content = substitute(l:content, '\\n', "\<CR>", 'g')
  silent exe 'norm! gv"_d'
  silent exe 'norm! cc'.l:var_name."();\<CR>"
  silent exe 'norm! kOconst '.l:var_name." = () => {\<CR>".l:content."\<CR>};\<CR>"
  silent exe 'norm! kVi{='
  silent exe l:restorepos
endfunction

function! s:extract_class_method(is_in_method) abort
  let l:method_name = s:get_input('Enter method name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:fn = s:get_fn_data()

  let l:args = copy(l:fn['arguments'])
  call filter(l:args, {idx, val -> val !~ 'this'})
  let l:args = join(l:args, ', ')

  let l:content = substitute(l:fn['content'], '\\n', "\<CR>", 'g')

  silent exe 'norm! gv"_d'
  silent exe 'norm! O'.l:fn['return'].l:fn['await'].'this.'.l:method_name.'('.l:args.');'
  if a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>"
  else
    call search(s:class_regex, 'b')
    silent exe "norm! $o\<CR>"
  endif

  silent exe 'norm!cc'.l:fn['async'].l:method_name.'('.l:args.") {\<CR>".l:content."\<CR>}"
  silent exe 'norm! Va{='
  silent exe l:restorepos
endfunction

function! s:extract_global_function(has_class, is_in_method) abort
  let l:var_name = s:get_input('Enter function name')
  let l:restorepos = line('.') . 'normal!' . virtcol('.') . '|'
  let l:fn = s:get_fn_data()

  let l:content = substitute(l:fn['content'], '\\n', "\<CR>", 'g')
  let l:args = join(l:fn['arguments'], ', ')

  silent exe 'norm! gv"_d'
  silent exe 'norm! O'.l:fn['return'].l:fn['await'].l:var_name.'('.l:args.");\<CR>"
  if a:has_class
    call search(s:class_regex, 'b')
    silent exe 'norm! Oconst'
  elseif a:is_in_method
    call search(s:method_regex, 'b')
    silent exe "norm! $%o\<CR>const"
  else
    silent exe 'norm! cconst'
  endif

  let l:fnArgs = substitute(l:args, 'this', 'self', 'g')
  let l:fnContent = substitute(l:content, 'this', 'self', 'g')
  silent exe 'norm! a '.l:var_name.' = '.l:fn['async'].'('.l:fnArgs.") => {\<CR>".l:fnContent."\<CR>};\<CR>"
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

function! s:get_arguments(content) abort
  let l:py_command = has('python3') ? 'py3' : 'py'
  let l:reserved_words = ['if', 'return', 'await', 'async', 'const', 'let', 'var']
  let l:content = substitute(a:content, '\\n', '', 'g')
  let l:matches = []
  silent exe l:py_command.' import vim, re'
  silent exe l:py_command.' content = vim.eval("l:content")'
  silent exe l:py_command." matches = re.findall(r'\\b[A-Za-z0-9_\\.]+\\b', content)"
  silent exe l:py_command.' vim.command(''let l:matches = %s'' % matches)'

  let l:arguments = []

  for l:match in l:matches
    if index(l:reserved_words, l:match) > -1
      continue
    endif
    if l:match =~? '\.'
      let l:match = substitute(l:match, '\..*', '', 'g')
    endif
    call add(l:arguments, l:match)
  endfor

  return l:arguments
endfunction

function! s:get_fn_data()
  let l:selection = jsfileimport#utils#_get_selection()
  let l:content = join(l:selection, '\n')

  return {
  \ 'selection': l:selection,
  \ 'content' : l:content,
  \ 'arguments': s:get_arguments(l:content),
  \ 'return': (len(l:selection) > 0 && l:selection[-1] =~? 'return') ? 'return' : '',
  \ 'async': l:content =~? 'await' ? ' async ' : '',
  \ 'await': l:content =~? 'await' ? ' await ' : '',
  \}
endfunction

function! jsfileimport#utils#_determine_import_type() abort
  let l:require_regex = {
        \ 'type': 'require',
        \ 'check_import_exists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existing_path': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_full_path_only': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_path_for_full': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_[^''"]\{-\}require(.*;\?$',
        \ 'default_export': 'module.exports\s*=.\{-\}',
        \ 'partial_export': 'module.exports.\(\<__FNAME__\>\|\s*=\_[^{]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'select_for_sort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'import_name': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*=\s*require([^)]*);\?',
        \ }

  let l:import_regex = {
        \ 'type': 'import',
        \ 'check_import_exists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existing_path': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_full_path_only': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_path_for_full': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': '^import\s\_[^''"]\{-\}from.*;\?$',
        \ 'default_export': 'export\s*default.\{-\}',
        \ 'partial_export': 'export\s*\(const\|var\|function\)\s*\<__FNAME__\>',
        \ 'select_for_sort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'import_name': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*from\s*',
        \ }

  if g:js_file_import_force_require || search(l:require_regex['lastimport'], 'n') > 0
    return l:require_regex
  endif

  return l:import_regex
endfunction

function! jsfileimport#utils#_check_python_support() abort
  if !has('python') && !has('python3')
    throw 'Vim js file import requires python or python3 support.'
  endif

  return 1
endfunction

function! jsfileimport#utils#_get_file_path(filepath) abort
  let l:py_command = has('python3') ? 'py3' : 'py'
  let l:path = a:filepath

  silent! exe l:py_command.' import vim, os.path'
  silent! exe l:py_command.' current_path = vim.eval("expand(''%:p:h'')")'
  silent! exe l:py_command.' tag_path = vim.eval("fnamemodify(a:filepath, '':p'')")'
  silent! exe l:py_command.' path = os.path.splitext(os.path.relpath(tag_path, current_path))[0]'
  silent! exe l:py_command.' leading_slash = "./" if path[0] != "." else ""'
  silent! exe l:py_command.' vim.command(''let l:path = "%s%s"'' % (leading_slash, path))'

  return l:path
endfunction

function! jsfileimport#utils#_error(msg) abort
  silent! exe 'redraw'
  echohl Error
  echo a:msg
  echohl NONE
  return 0
endfunction

function! jsfileimport#utils#_get_word(is_visual_mode) abort
  let l:word = expand('<cword>')

  if a:is_visual_mode
    let l:selection = jsfileimport#utils#_get_selection()
    let l:word = join(l:selection, '\n')
  endif

  if l:word !~? '\(\d\|\w\)'
    throw 'Invalid word.'
  endif

  return l:word
endfunction

function! jsfileimport#utils#_get_selection() abort
  let l:pos = jsfileimport#utils#_get_selection_ranges()
  let l:lines = getline(l:pos['line_start'], l:pos['line_end'])

  if len(l:lines) ==? 0
    return []
  endif

  let l:lines[-1] = l:lines[-1][:l:pos['column_end'] - (&selection ==? 'inclusive' ? 1 : 2)]
  let l:lines[0] = l:lines[0][l:pos['column_start'] - 1:]
  return l:lines
endfunction

function! jsfileimport#utils#_get_selection_ranges() abort
  let [l:line_start, l:column_start] = getpos("'<")[1:2]
  let [l:line_end, l:column_end] = getpos("'>")[1:2]

  return {
  \ 'line_start': l:line_start,
  \ 'column_start': l:column_start,
  \ 'line_end': l:line_end,
  \ 'column_end': l:column_end,
  \ }
endfunction

function! jsfileimport#utils#_count_word_in_file(word) abort
  let l:use_global = &gdefault ? '' : 'g'

  redir => l:count
    silent! exe '%s/\(require([''"]\|from\s*[''"]\)\@<!\<' . a:word . '\>//'.l:use_global.'n'
  redir END

  let l:result = strpart(l:count, 0, stridx(l:count, ' '))
  return float2nr(str2float(l:result))
endfunction

function! jsfileimport#utils#_remove_duplicate_files(files) abort
  let l:added = []
  let l:new_files = []

  for l:file in a:files
    let l:filename = split(l:file, ':')[0]
    if index(l:added, l:filename) > -1
      continue
    endif
    call add(l:new_files, l:file)
    call add(l:added, l:filename)
  endfor

  return l:new_files
endfunction

function! jsfileimport#utils#_get_confirm_selection(title, options) abort
  silent! exe ':redraw'
  let l:confirm_option = confirm(a:title.' :', '&'.join(a:options, "\n&"))
  let l:option = get(a:options, l:confirm_option - 1, -1)

  if l:option ==? -1
    throw 'Invalid choice.'
  endif

  return l:option
endfunction

function! jsfileimport#utils#_get_file_info() abort
  let l:lines = []
  let l:current_line = line('.')
  let l:current_line_content = getline('.')
  let l:current_column = col('.')
  let l:pos = jsfileimport#utils#_get_selection_ranges()
  let l:last_pos = searchpair('{', '', '}', 'bW')

  while l:last_pos > 0
    let l:close_line = searchpair('{', '', '}', 'n')
    call add(l:lines, { 'line': l:last_pos, 'close_line': l:close_line, 'content': getline(l:last_pos) })
    let l:last_pos = searchpair('{', '', '}', 'bW')
  endwhile

  call cursor(l:current_line, l:current_column)

  let l:return_data = extend({
  \ 'class': {},
  \ 'method': {},
  \ 'in_class': 0,
  \ 'in_method': 0,
  \ 'all_lines': l:lines,
  \ 'block_lines': l:lines[:-2],
  \ 'current_line': l:current_line,
  \ 'current_column': l:current_column,
  \  }, l:pos)

  if len(l:lines) ==? 0
    return l:return_data
  endif

  if l:lines[-1].content =~? '^[[:blank:]]*class\s*.*$'
    let l:return_data['class'] = l:lines[-1]
    let l:return_data['in_class'] = 1
    if len(l:lines) > 1
      let l:return_data['method'] = l:lines[-2]
      let l:return_data['in_method'] = 1
      let l:return_data['block_lines'] = l:lines[:-3]
    elseif s:is_line_method(l:current_line_content)
      call cursor(l:current_line, col('$'))
      let l:current_close_line = searchpair('{', '', '}', 'n')
      call cursor(l:current_line, l:current_column)
      let l:return_data['method'] = {
      \ 'line': l:current_line,
      \ 'close_line': l:current_close_line,
      \ 'content': l:current_line_content
      \ }
      let l:return_data['in_method'] = 1
    endif
  elseif l:lines[-1].content =~? '^[[:blank:]]*.*{[[:blank:]]*$' && l:lines[-1].line !=? l:lines[-1].close_line
    let l:return_data['method'] = l:lines[-1]
    let l:return_data['in_method'] = 1
  endif

  return l:return_data
endfunction

function! jsfileimport#utils#_is_reserved_word(word) abort
  let l:reserved_words = [
  \ 'if', 'return', 'await', 'async', 'const', 'let', 'var',
  \ 'break', 'continue', 'true', 'false', 'for', 'try', 'catch', 'finally', 'switch',
  \ 'throw', 'new', 'Object', 'Array'
  \ ]

  return index(l:reserved_words, a:word) > -1
endfunction

function! jsfileimport#utils#_get_input(question) abort
  silent! exe 'redraw'
  let l:var_name = input(a:question.': ', '')
  if l:var_name ==? ''
    throw ''
  endif

  return l:var_name
endfunction

function s:is_line_method(content) abort
  return a:content =~? '^[[:blank:]]*.*(.*).*{[[:blank:]]*$'
endfunction

" vim:foldenable:foldmethod=marker:sw=2

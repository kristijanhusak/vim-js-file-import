let s:saved_cursor_position = 0

function! jsfileimport#utils#_determine_import_type() abort
  let l:require_regex = {
        \ 'type': 'require',
        \ 'check_import_exists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existing_path': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_full_path_only': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_path_for_full': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__')",
        \ 'lastimport': '^\(const\|let\|var\)\s\_[^''"]\{-\}require(.*;\?$',
        \ 'default_export': 'module.exports\s*=.\{-\}',
        \ 'partial_export': 'module.exports.\(\<__FNAME__\>\|\s*=\_[^{]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'select_for_sort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'import_name': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*=\s*require([^)]*);\?',
        \ 'is_single_import': '^\(const\|let\|var\)\(\s\|\n\)\{-\}{\?\(\s\|\n\)\{-\}\<__FNAME__\>\(\s\|\n\)\{-\}}\?\(\s\|\n\)\{-\}=\(\s\|\n\)\{-\}require(\_[^)]\{-\});\?',
        \ }

  let l:import_regex = {
        \ 'type': 'import',
        \ 'check_import_exists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existing_path': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_full_path_only': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_path_for_full': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__'",
        \ 'lastimport': '^import\s\_[^''"]\{-\}from.*;\?$',
        \ 'default_export': 'export\s*default.\{-\}',
        \ 'partial_export': 'export\s*\(const\|var\|function\)\s*\<__FNAME__\>',
        \ 'select_for_sort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'import_name': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*from\s*',
        \ 'is_single_import': '^\import\(\s\|\n\)\{-\}{\?\(\s\|\n\)\{-\}\<__FNAME__\>\(\s\|\n\)\{-\}}\?\(\s\|\n\)\{-\}from\(\s\|\n\)\{-\}[''"][^''"]*[''"];\?',
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

function! jsfileimport#utils#_check_import_exists(name, ...) abort
  let l:rgx = jsfileimport#utils#_determine_import_type()
  let l:pattern = substitute(l:rgx['check_import_exists'], '__FNAME__', a:name, '')
  let l:throw_err = a:0 > 0

  if search(l:pattern, 'n') > 0
    if l:throw_err
      throw 'Import "'.a:name.'" already exists.'
    endif
    return 1
  endif

  return 0
endfunction

function! jsfileimport#utils#_save_cursor_position() abort
  if s:saved_cursor_position
    return 0
  endif

  silent exe 'normal mz'
  let s:saved_cursor_position = 1
endfunction

function! jsfileimport#utils#_restore_cursor_position() abort
  if s:saved_cursor_position
    silent exe 'normal `z'
  endif

  let s:saved_cursor_position = 0
endfunction

" vim:foldenable:foldmethod=marker:sw=2

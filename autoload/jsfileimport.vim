function! jsfileimport#word(...) abort
  return s:do_import('jsfileimport#tags#_get_tag', a:0)
endfunction

function! jsfileimport#prompt() abort
  return s:do_import('jsfileimport#tags#_get_tag_data_from_prompt', 0)
endfunction

function! jsfileimport#clean() abort
  silent exe 'normal! mz'
  let l:rgx = s:determine_import_type()
  call cursor(1, 0)
  let l:start = search(l:rgx['lastimport'], 'c')
  let l:end = search(l:rgx['lastimport'], 'be')

  for l:line in getline(l:start, l:end)
    let l:list = matchlist(l:line, l:rgx['import_name'])
    if len(l:list) >= 3 && jsfileimport#utils#_count_word_in_file(l:list[2]) <= 1
      silent exe l:start.'d'
      continue
    endif
    let l:start += 1
  endfor
  silent exe 'normal! `z'
endfunction

function! jsfileimport#sort(...) abort
  if a:0 == 0
    silent exe 'normal! mz'
  endif

  let l:rgx = s:determine_import_type()

  if search(l:rgx['select_for_sort'], 'be') > 0
    silent exe g:js_file_import_sort_command
  endif

  silent exe 'normal! `z'
  return 1
endfunction

function! jsfileimport#goto(...) abort
  try
    call jsfileimport#utils#_check_python_support()
    let l:name = jsfileimport#utils#_get_word()
    let l:rgx = s:determine_import_type()
    let l:tags = jsfileimport#tags#_get_taglist(l:name, l:rgx)
    let l:current_file_path = expand('%:p')

    if len(l:tags) == 0
      throw 'Tag not found.'
    endif

    if a:0 == 0
      if len(l:tags) == 1
        return jsfileimport#tags#_jump_to_tag(l:tags[0], l:current_file_path)
      endif

      let l:tag_in_current_file = jsfileimport#tags#_get_tag_in_current_file(l:tags, l:current_file_path)

      if l:tag_in_current_file['filename'] !=? ''
        return jsfileimport#tags#_jump_to_tag(l:tag_in_current_file, l:current_file_path)
      endif
    endif

    let l:tag_selection_list = jsfileimport#tags#_generate_tags_selection_list(l:tags)
    let l:options = extend(['Current path: '.expand('%'), 'Select definition:'], l:tag_selection_list)

    call inputsave()
    let l:selection = inputlist(l:options)
    call inputrestore()

    if l:selection < 1
      return 0
    endif

    if l:selection >= len(l:options) - 1
      throw 'Wrong selection.'
    endif

    return jsfileimport#tags#_jump_to_tag(l:tags[l:selection - 1], l:current_file_path)
  catch /.*/
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! jsfileimport#findusage() abort
  try
  if !executable('rg') && !executable('ag')
    throw 'rg (ripgrep) or ag (silversearcher) needed.'
  endif
  let l:rgx = s:determine_import_type()
  let l:word = jsfileimport#utils#_get_word()
  let l:current_file_path = expand('%')
  let l:executable = executable('rg') ? 'rg --sort-files' : 'ag'
  let l:line = line('.')

  let l:files = systemlist(l:executable.' '.l:word.' --vimgrep .')
  " Remove current line from list
  call filter(l:files, {idx, val -> val !~ '^'.l:current_file_path.':'.l:line.'.*$'})

  if len(l:files) > 30
    let l:files = jsfileimport#utils#_remove_duplicate_files(l:files)
  endif
  let l:options = []
  for l:file in l:files
    let [l:filename, l:row, l:col, l:pattern] = matchlist(l:file, '\([^:]*\):\(\d*\):\(\d*\):\(.*\)')[1:4]
    call add(l:options, { 'filename': l:filename, 'lnum': l:row, 'col': l:col, 'text': l:pattern })
  endfor

  call setqflist(l:options)
  silent exe 'copen'
  return 1
  catch /.*/
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
  endtry
endfunction

function! s:do_import(tag_fn_name, show_list) abort "{{{
  silent exe 'normal! mz'

  try
    call jsfileimport#utils#_check_python_support()
    let l:name = jsfileimport#utils#_get_word()
    let l:rgx = s:determine_import_type()
    call s:check_if_exists(l:name, l:rgx)
    let l:tag_data = call(a:tag_fn_name, [l:name, l:rgx, a:show_list])

    if l:tag_data['global'] !=? ''
      return s:process_import(l:name, l:tag_data['global'], l:rgx, 1)
    endif

    return s:import_tag(l:tag_data['tag'], l:name, l:rgx)
  catch /.*/
    silent exe 'normal! `z'
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction "}}}

function! s:is_partial_import(tag, name, rgx) "{{{
  let l:partial_rgx = substitute(a:rgx['partial_export'], '__FNAME__', a:name, 'g')

  " Method or partial export
  if a:tag['kind'] =~# '\(m\|p\)' || a:tag['cmd'] =~# l:partial_rgx
    return 1
  endif

  if a:tag['cmd'] =~# a:rgx['default_export'].a:name
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let l:file_path = getcwd().'/'.a:tag['filename']

  if !filereadable(l:file_path)
    return 0
  endif

  if match(join(readfile(l:file_path, '')), l:partial_rgx) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:process_import(name, path, rgx, ...) abort "{{{
  let l:import_rgx = a:rgx['import']
  let l:import_rgx = substitute(l:import_rgx, '__FNAME__', a:name, '')
  let l:import_rgx = substitute(l:import_rgx, '__FPATH__', a:path, '')
  let l:append_to_start = 0

  if a:0 > 0 && g:js_file_import_package_first
    let l:append_to_start = 1
  endif

  if search(a:rgx['lastimport'], 'be') > 0 && l:append_to_start == 0
    call append(line('.'), l:import_rgx)
  elseif search(a:rgx['lastimport']) > 0
    call append(line('.') - 1, l:import_rgx)
  else
    call append(0, l:import_rgx)
    call append(1, '')
  endif
  return s:finish_import()
endfunction "}}}

function! s:check_if_exists(name, rgx) abort "{{{
  let l:pattern = substitute(a:rgx['check_import_exists'], '__FNAME__', a:name, '')

  if search(l:pattern, 'n') > 0
    throw 'Import already exists.'
  endif

  return 0
endfunction "}}}

function! s:import_tag(tag, name, rgx) abort "{{{
  let l:is_partial = s:is_partial_import(a:tag, a:name, a:rgx)
  let l:path = jsfileimport#utils#_get_file_path(a:tag['filename'])
  let l:current_file_path = jsfileimport#utils#_get_file_path(expand('%:p'))

  if l:path ==# l:current_file_path
    throw 'Import failed. Selected import is in this file.'
  endif

  let l:escaped_path = escape(l:path, './')

  if l:is_partial == 0
    return s:process_full_import(a:name, a:rgx, l:path)
  endif

  " Check if only full import exists for given path. ES6 allows partial imports alongside full import
  let l:existing_full_path_only = substitute(a:rgx['existing_full_path_only'], '__FPATH__', l:escaped_path, '')

  if a:rgx['type'] ==? 'import' && search(l:existing_full_path_only, 'n') > 0
    call search(l:existing_full_path_only, 'e')
    return s:process_partial_import_alongside_full(a:name)
  endif

  "Partial single line
  let l:existing_path_rgx = substitute(a:rgx['existing_path'], '__FPATH__', l:escaped_path, '')

  if search(l:existing_path_rgx, 'n') <= 0
    return s:process_import('{ '.a:name.' }', l:path, a:rgx)
  endif

  call search(l:existing_path_rgx)
  let l:start_line = line('.')
  call search(l:existing_path_rgx, 'e')
  let l:end_line = line('.')

  if l:end_line > l:start_line
    return s:process_multi_line_partial_import(a:name)
  endif

  return s:process_single_line_partial_import(a:name)
endfunction "}}}

function! s:process_full_import(name, rgx, path) abort "{{{
  let l:esc_path = escape(a:path, './')
  let l:existing_import_rgx = substitute(a:rgx['existing_path_for_full'], '__FPATH__', l:esc_path, '')

  if a:rgx['type'] ==? 'import' && search(l:existing_import_rgx, 'n') > 0
    call search(l:existing_import_rgx)
    silent exe ':normal!i'.a:name.', '
    return s:finish_import()
  endif

  return s:process_import(a:name, a:path, a:rgx)
endfunction "}}}

function! s:process_single_line_partial_import(name) abort "{{{
  let l:char_under_cursor = getline('.')[col('.') - 1]
  let l:first_char = l:char_under_cursor ==? ',' ? ' ' : ', '
  let l:last_char = l:char_under_cursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:first_char.a:name.last_char

  return s:finish_import()
endfunction "}}}

function! s:process_multi_line_partial_import(name) abort "{{{
  let l:char_under_cursor = getline('.')[col('.') - 1]
  let l:first_char = l:char_under_cursor !=? ',' ? ',': ''
  let l:last_char = l:char_under_cursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:first_char
  silent exe ':normal!o'.a:name.l:last_char

  return s:finish_import()
endfunction "}}}

function! s:process_partial_import_alongside_full(name) abort "{{{
  silent exe ':normal!a, { '.a:name.' }'

  return s:finish_import()
endfunction "}}}

function! s:determine_import_type() abort "{{{
  let l:require_regex = {
        \ 'type': 'require',
        \ 'check_import_exists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existing_path': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_full_path_only': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existing_path_for_full': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_.\{-\}require(.*;\?$',
        \ 'default_export': 'module.exports\s*=.\{-\}',
        \ 'partial_export': 'module.exports.\(\<__FNAME__\>\|\s*=\_[^{]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'select_for_sort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'import_name': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  let l:import_regex = {
        \ 'type': 'import',
        \ 'check_import_exists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existing_path': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_full_path_only': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existing_path_for_full': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': '^import\s\_.\{-\}from.*;\?$',
        \ 'default_export': 'export\s*default.\{-\}',
        \ 'partial_export': 'export\s*\(const\|var\|function\)\s*\<__FNAME__\>',
        \ 'select_for_sort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'import_name': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  if g:js_file_import_force_require || search(l:require_regex['lastimport'], 'n') > 0
    return l:require_regex
  endif

  return l:import_regex
endfunction "}}}

function! s:finish_import() abort "{{{
  if g:js_file_import_sort_after_insert > 0
    call jsfileimport#sort(1)
  endif

  silent exe 'normal! `z'
  return 1
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

function! jsfileimport#word(is_visual_mode, ...) abort
  let l:show_list = get(a:, 1, 0)
  let l:word = get(a:, 2, 0)
  call s:do_import('jsfileimport#tags#_get_tag', a:is_visual_mode, l:show_list, l:word)
  let l:repeatMapping = a:0 > 0 ? 'JsFileImportList' : 'JsFileImport'
  silent! call repeat#set("\<Plug>(".l:repeatMapping.')')
endfunction

function! jsfileimport#typedef(is_visual_mode, ...) abort
  let l:show_list = get(a:, 1, 0)
  let l:word = get(a:, 2, 0)
  let l:rgx = jsfileimport#utils#_determine_import_type()
  if empty(l:word)
    let l:word = jsfileimport#utils#_get_word(a:is_visual_mode)
  endif
  call jsfileimport#utils#_save_cursor_position('typedef')
  try
    call jsfileimport#tags#_get_tag(l:word, l:rgx, l:show_list, function('s:import_typedef', [l:word, l:rgx]))
    let l:repeatMapping = a:0 > 0 ? 'JsFileImportTypedefList' : 'JsFileImportTypedef'
    silent! call repeat#set("\<Plug>(".l:repeatMapping.')')
  catch
    call jsfileimport#utils#_restore_cursor_position('typedef')
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! s:import_typedef(name, rgx, tag_data) abort
  let l:tag = a:tag_data['tag']
  let l:is_global = !empty(a:tag_data['global'])
  let l:is_partial = s:is_partial_import(a:tag_data, a:name, a:rgx)
  let l:path = l:tag['name']
  if !l:is_global
    let l:path = jsfileimport#utils#_get_file_path(l:tag['filename'])
  endif
  let l:current_file_path = jsfileimport#utils#_get_file_path(expand('%:p'))

  if !l:is_global && l:path ==# l:current_file_path
    throw 'Import failed. Selected import is in this file.'
  endif

  let l:escaped_path = escape(l:path, './')
  let line = printf(" * @typedef {import('%s')%s} %s", l:path, (l:is_partial ? '.'.a:name : ''), a:name)
  if search(line, 'n') > 0
    return jsfileimport#utils#_error('Typedef exists.')
  endif
  let existing_typedef = search('@typedef', 'n')
  if existing_typedef
    call append(existing_typedef, line)
  else
    call append(0, ['/**', line, ' */'])
  endif
endfunction

function! jsfileimport#tagfunc(pattern, flags, info) abort
  if a:flags !=? 'c'
    return v:null
  endif
  let l:rgx = jsfileimport#utils#_determine_import_type()
  return jsfileimport#tags#_get_taglist(a:pattern, l:rgx, 1)
endfunction

function! jsfileimport#prompt() abort
  call s:do_import('jsfileimport#tags#_get_tag_data_from_prompt', 0, 0, '')
  silent! call repeat#set("\<Plug>(PromptJsFileImport)")
endfunction

function! jsfileimport#sort(...) abort
  call jsfileimport#utils#_save_cursor_position('sort')

  let l:rgx = jsfileimport#utils#_determine_import_type()
  keepjumps normal! gg
  let l:start_range = search(l:rgx['lastimport'], 'nc')
  let l:end_range = search(l:rgx['lastimport'], 'nb')
  if l:start_range > 0 && l:end_range > 0
    " Kept for BC
    if !empty(g:js_file_import_sort_command)
      silent! exe g:js_file_import_sort_command
    else
      silent! exe printf('%d,%dsort! /%s/', l:start_range, l:end_range, l:rgx['sort_pattern'])
    endif
  endif

  call jsfileimport#utils#_restore_cursor_position('sort')
  return 1
endfunction

function! jsfileimport#goto(is_visual_mode, ...) abort
  try
    let l:show_list = get(a:, 1, 0) > 0
    let l:word = get(a:, 2, '')
    if !empty(l:word)
      let l:name = l:word
    else
      let l:name = jsfileimport#utils#_get_word(a:is_visual_mode)
    endif
    let l:rgx = jsfileimport#utils#_determine_import_type()
    let l:tags = jsfileimport#tags#_get_taglist(l:name, l:rgx, 1)
    let l:current_file_path = expand('%:p')

    if len(l:tags) == 0
      throw 'Tag not found.'
    endif

    if !l:show_list
      if len(l:tags) == 1
        return jsfileimport#tags#_jump_to_tag(l:tags[0], l:current_file_path, l:show_list)
      endif

      let l:tag_in_current_file = jsfileimport#tags#_get_tag_in_current_file(l:tags, l:current_file_path)

      if l:tag_in_current_file['filename'] !=? ''
        return jsfileimport#tags#_jump_to_tag(l:tag_in_current_file, l:current_file_path, l:show_list)
      endif
    endif

    return jsfileimport#utils#inputlist(
          \ l:tags,
          \ jsfileimport#tags#_generate_tags_selection_list(l:tags),
          \ 'Select tag to jump to: ',
          \ function('s:handle_goto_tag_selection', [l:tags, l:current_file_path, l:show_list])
          \ )
  catch /.*/
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! s:handle_goto_tag_selection(tags, current_file_path, show_list, selection) abort
  if a:selection < 0
    return 0
  endif

  return jsfileimport#tags#_jump_to_tag(a:tags[a:selection], a:current_file_path, a:show_list)
endfunction

function! jsfileimport#findusage(is_visual_mode) abort
  try
    if !executable('rg') && !executable('ag')
      throw 'rg (ripgrep) or ag (silversearcher) needed.'
    endif
    let l:rgx = jsfileimport#utils#_determine_import_type()
    let l:word = jsfileimport#utils#_get_word(a:is_visual_mode)
    let l:current_file_path = expand('%')
    let l:executable = executable('rg') ? 'rg --sort-files' : 'ag'
    let l:line = line('.')

    let l:files = jsfileimport#utils#systemlist(l:executable.' '.l:word.' --vimgrep .')
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
    silent! exe 'copen'
    silent! call repeat#set("\<Plug>(JsFindUsage)")
    return 1
  catch /.*/
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! jsfileimport#_import_word(name, tag_fn_name, is_visual_mode, show_list) abort
  call jsfileimport#utils#_save_cursor_position('import')
  try
    let l:rgx = jsfileimport#utils#_determine_import_type()
    call jsfileimport#utils#_check_import_exists(a:name, 1)
    if a:tag_fn_name ==? 'jsfileimport#tags#_get_tag'
      return call(a:tag_fn_name, [a:name, l:rgx, a:show_list, function('s:import_tag', [a:name, l:rgx])])
    endif

    let l:tag_data = call(a:tag_fn_name, [a:name, l:rgx, a:show_list])
    return s:import_tag(a:name, l:rgx, l:tag_data)
  catch /.*/
    call jsfileimport#utils#_restore_cursor_position('import')
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction

function! s:do_import(tag_fn_name, is_visual_mode, show_list, word) abort "{{{
  if !empty(a:word)
    let l:name = a:word
  else
    let l:name = jsfileimport#utils#_get_word(a:is_visual_mode)
  endif

  return jsfileimport#_import_word(l:name, a:tag_fn_name, a:is_visual_mode, a:show_list)
endfunction "}}}

function! s:is_partial_import(tag_data, name, rgx) "{{{
  if !empty(a:tag_data['global']) && !empty(a:tag_data['global_partial'])
    return 1
  endif
  let l:tag = a:tag_data['tag']
  let l:partial_rgx = substitute(a:rgx['partial_export'], '__FNAME__', a:name, 'g')

  " Method or partial export
  if l:tag['kind'] =~# '\(m\|p\|i\)' || l:tag['cmd'] =~# l:partial_rgx
    return 1
  endif

  if l:tag['cmd'] =~# a:rgx['default_export'].a:name
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let l:file_path = fnamemodify(l:tag['filename'], ':p')

  if !filereadable(l:file_path)
    return 0
  endif

  if match(join(readfile(l:file_path, '')), l:partial_rgx) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:process_import(name, path, rgx, is_global) abort "{{{
  let l:import_rgx = a:rgx['import']
  let l:import_rgx = substitute(l:import_rgx, '__FNAME__', a:name, '')
  let l:import_rgx = substitute(l:import_rgx, '__FPATH__', a:path, '')

  if ! g:js_file_import_omit_semicolon
    let l:import_rgx = l:import_rgx . ';'
  endif

  let l:append_to_start = 0

  if a:is_global && g:js_file_import_package_first
    let l:append_to_start = 1
  endif

  if search(a:rgx['lastimport'], 'be') > 0 && l:append_to_start == 0
    let l:has_chained_call = a:rgx.type ==? 'require' && getline('.') !=? ';$' && getline(line('.') + 1) =~? '^[[:blank:]]*\.'
    if l:has_chained_call
      call append(line('.') - 1, l:import_rgx)
    else
      call append(line('.'), l:import_rgx)
    endif
  elseif search(a:rgx['lastimport']) > 0
    call append(line('.') - 1, l:import_rgx)
  else
    let line_nr = 0
    if &filetype ==? 'vue'
      let line_nr = search('<script[^>]*>\s*$', 'wn')
    endif
    call append(line_nr, l:import_rgx)
    call append(line_nr + 1, '')
  endif
  return s:finish_import()
endfunction "}}}

function! s:import_tag(name, rgx, tag_data) abort "{{{
  let l:tag = a:tag_data['tag']
  let l:is_global = !empty(a:tag_data['global'])
  let l:is_partial = s:is_partial_import(a:tag_data, a:name, a:rgx)
  let l:path = l:tag['name']
  if !l:is_global
    let l:path = jsfileimport#utils#_get_file_path(l:tag['filename'])
  endif
  let l:current_file_path = jsfileimport#utils#_get_file_path(expand('%:p'))

  if !l:is_global && l:path ==# l:current_file_path
    throw 'Import failed. Selected import is in this file.'
  endif

  let l:escaped_path = escape(l:path, './')

  if l:is_partial == 0
    return s:process_full_import(a:name, a:rgx, l:path, l:is_global)
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
    return s:process_import('{ '.a:name.' }', l:path, a:rgx, l:is_global)
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

function! s:process_full_import(name, rgx, path, is_global) abort "{{{
  let l:esc_path = escape(a:path, './')
  let l:existing_import_rgx = substitute(a:rgx['existing_path_for_full'], '__FPATH__', l:esc_path, '')

  if a:rgx['type'] ==? 'import' && search(l:existing_import_rgx, 'n') > 0
    call search(l:existing_import_rgx)
    silent! exe ':normal!i'.a:name.', '
    return s:finish_import()
  endif

  return s:process_import(a:name, a:path, a:rgx, a:is_global)
endfunction "}}}

function! s:process_single_line_partial_import(name) abort "{{{
  let l:char_under_cursor = getline('.')[col('.') - 1]
  let l:first_char = l:char_under_cursor ==? ',' ? ' ' : ', '
  let l:last_char = l:char_under_cursor ==? ',' ? ',' : ''

  silent! exe ':normal!a'.l:first_char.a:name.last_char

  return s:finish_import()
endfunction "}}}

function! s:process_multi_line_partial_import(name) abort "{{{
  let l:char_under_cursor = getline('.')[col('.') - 1]
  let l:first_char = l:char_under_cursor !=? ',' ? ',': ''
  let l:last_char = l:char_under_cursor ==? ',' ? ',' : ''

  silent! exe ':normal!a'.l:first_char
  silent! exe ':normal!o'.a:name.l:last_char

  return s:finish_import()
endfunction "}}}

function! s:process_partial_import_alongside_full(name) abort "{{{
  silent! exe ':normal!a, { '.a:name.' }'

  return s:finish_import()
endfunction "}}}

function! s:finish_import() abort "{{{
  if g:js_file_import_sort_after_insert > 0
    call jsfileimport#sort()
  endif

  call jsfileimport#utils#_restore_cursor_position('import')
  return 1
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

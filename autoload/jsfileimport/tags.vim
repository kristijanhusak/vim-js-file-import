function! jsfileimport#tags#_get_tag(name, rgx, show_list) abort
  let l:tags = jsfileimport#tags#_get_taglist(a:name, a:rgx)
  call filter(l:tags, function('s:remove_tags_with_current_path'))

  if len(l:tags) <= 0
    if g:js_file_import_prompt_if_no_tag
      echo 'No tag found for word "'.a:name.'". Falling back to prompt.'
      return jsfileimport#tags#_get_tag_data_from_prompt(a:name, a:rgx)
    endif
    throw 'No tag found.'
  endif

  if a:show_list == 0 && len(l:tags) == 1
    return { 'tag': l:tags[0], 'global': s:check_if_global_tag(l:tags[0]), 'global_partial': 0 }
  endif

  let l:tag_selection_list = jsfileimport#tags#_generate_tags_selection_list(l:tags)
  let l:prompt_index = len(l:tag_selection_list) + 1
  let l:prompt_import = [l:prompt_index.') Enter path to file or package name manually for word "'.a:name.'"']
  let l:options = ['Select file to import:'] + l:tag_selection_list + l:prompt_import

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 1
    throw ''
  endif

  if l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  if l:selection == l:prompt_index
    silent! exe 'redraw'
    return jsfileimport#tags#_get_tag_data_from_prompt(a:name, a:rgx)
  endif

  let l:selected_tag = l:tags[l:selection - 1]
  return { 'tag': l:selected_tag, 'global': s:check_if_global_tag(l:selected_tag), 'global_partial': 0 }
endfunction

function! jsfileimport#tags#_get_tag_data_from_prompt(name, rgx, ...) abort
  call inputsave()
  let l:path = input('Path to file or package name: ', '', 'file')
  call inputrestore()

  if l:path ==? ''
    throw 'No path entered.'
  endif

  let l:tag_data = { 'global': '', 'global_partial': 0, 'tag': { 'filename': l:path, 'name': l:path, 'cmd': '', 'kind': '' } }
  let l:full_path = getcwd().'/'.l:path

  if filereadable(l:full_path) || isdirectory(l:full_path)
    return l:tag_data
  endif

  let l:global_package_tag = s:get_global_package_tag(l:path)
  if !empty(l:global_package_tag)
    let l:tag_data['global'] = 1
    let l:tag_data['tag'] = l:global_package_tag
    if l:path ==? a:name
      return l:tag_data
    endif
    let l:full_or_partial = confirm('Is import full or partial?', "&Full\n&Partial")
    if l:full_or_partial ==? 2
      let l:tag_data['global_partial'] = 1
    endif
    return l:tag_data
  endif

  if !empty(matchstr(l:path, '/'))
    let l:global_package_nested_tag = s:get_global_package_tag(split(l:path, '/')[0])

    if !empty(l:global_package_nested_tag)
      let l:tag_data['global'] = 1
      let l:tag_data['tag']['name'] = l:path
      return l:tag_data
    endif
  endif

  let l:choice = confirm('File or package not found. Import as:', "&File\n&Package\n&Cancel")
  if l:choice == 3
    throw ''
  elseif l:choice == 2
    let l:tag_data['global'] = 1
    let l:tag_data['tag']['name'] = l:path
    let l:full_or_partial = confirm('Is import full or partial?', "&Full\n&Partial")
    if l:full_or_partial ==? 2
      let l:tag_data['global_partial'] = 1
    endif
  endif

  return l:tag_data
endfunction

function! jsfileimport#tags#_get_taglist(name, rgx) abort
  let l:tags = taglist('^'.a:name.'$')
  call filter(l:tags, function('s:remove_obsolete'))
  call s:append_tags_by_filename(l:tags, a:name, a:rgx)

  let l:global_package_tag = s:get_global_package_tag(a:name)
  if empty(l:global_package_tag)
    return l:tags
  endif

  let l:already_in_taglist = len(filter(copy(l:tags), 'v:val.name ==? "'.l:global_package_tag.name.'"')) > 0

  if !l:already_in_taglist
    call add(l:tags, l:global_package_tag)
  endif

  return l:tags
endfunction

function! jsfileimport#tags#_generate_tags_selection_list(tags) abort
  function! s:tag_item(idx, tag) abort
    let l:cmd_kind = s:get_cmd_or_kind(a:tag)
    return printf('%d) %s', a:idx + 1, a:tag['filename'].l:cmd_kind)
  endfunction

  return map(copy(a:tags), function('s:tag_item'))
endfunction

function! s:get_cmd_or_kind(tag) abort
  if !empty(a:tag['cmd'])
    return ' - '.a:tag['cmd']
  endif

  let l:kinds = {
        \ 'f': 'Function',
        \ 'c': 'Class',
        \ 'm': 'Method',
        \ 'p': 'Property',
        \ 'C': 'Constant',
        \ 'v': 'Global variable',
        \ 'g': 'Generator',
        \ 'F': 'File',
        \ 'D': 'Directory',
        \ }
  if has_key(a:tag, 'kind') && has_key(l:kinds, a:tag['kind'])
    return ' - '.l:kinds[a:tag['kind']]
  endif

  return ''
endfunction

function! jsfileimport#tags#_get_tag_in_current_file(tags, current_file_path) abort
  for l:tag in a:tags
    if fnamemodify(l:tag['filename'], ':p') ==? a:current_file_path
      return l:tag
    endif
  endfor
  return { 'filename': '' }
endfunction

function! jsfileimport#tags#_jump_to_tag(tag, current_file_path, show_list) abort
  let l:tag_path = fnamemodify(a:tag['filename'], ':p')

  if l:tag_path !=? a:current_file_path && bufname('%') !=? a:tag['filename']
    silent! exe 'e '.a:tag['filename']
  else
    "Sets the previous context mark to allow jumping to this location with CTRL-O
    silent! exe 'norm!m`'
  endif
  silent! exe escape(a:tag['cmd'], '[]')
  let l:repeatMapping = a:show_list ? 'JsGotoDefinitionList' : 'JsGotoDefinition'
  silent! call repeat#set("\<Plug>(".l:repeatMapping.')')
  return 1
endfunction

function! s:remove_tags_with_current_path(idx, tag) abort "{{{
  if expand('%:p') ==? fnamemodify(a:tag['filename'], ':p')
    return 0
  endif

  return 1
endfunction "}}}

function! s:tags_has_filename(tags, filename) abort "{{{
  for l:tag in a:tags
    if l:tag['filename'] ==? a:filename
      return 1
    endif
  endfor

  return 0
endfunction "}}}

function! s:remove_obsolete(idx, tag) abort "{{{
  if a:tag['filename'] =~? 'package.lock'
    return 0
  endif

  let l:filters = extend(['import\s*from', 'require('], g:js_file_import_filters)
  for l:filter in l:filters
    if a:tag['cmd'] =~? l:filter
      return 0
    endif
  endfor

  return 1
endfunction "}}}

function! s:append_tags_by_filename(tags, name, rgx) abort "{{{
  let l:name_variations = s:get_name_variations(a:name)
  for l:item in l:name_variations
    call s:append_filename_to_tags(a:tags, l:item, a:rgx)
  endfor

  call s:append_directories_to_tags(a:name, a:tags, l:name_variations)

  return a:tags
endfunction "}}}

function! s:append_directories_to_tags(name, tags, name_variations) abort
  let l:dirs = []
  if executable('find')
    let l:find_items = join(
      \ map(copy(a:name_variations),
      \ '"-name ''".v:val."'' -type d -not -path ''./node_modules/*''"'),
      \ ' -o '
      \ )
    let l:dirs = jsfileimport#utils#systemlist('find . '.l:find_items)
    let l:dirs = map(l:dirs, 'substitute(v:val, "^\.\/", "", "")')
  else
    for l:item in a:name_variations
      let l:item_dirs = finddir(l:item, '**', '-1')
      let l:dirs += filter(copy(l:item_dirs), '!empty(v:val) && v:val !~? "node_modules"')
    endfor
  endif

  for l:dir in l:dirs
    if !empty(l:dir) && filereadable(printf('%s/index.js', l:dir)) && !s:tags_has_filename(a:tags, l:dir)
      call add(a:tags, { 'filename': l:dir, 'name': a:name, 'kind': 'D', 'cmd': '' })
    endif
  endfor
endfunction

function! s:append_filename_to_tags(tags, name, rgx) abort "{{{
  let l:files = []

  if executable('rg')
    let l:files = jsfileimport#utils#systemlist('rg -g "'.a:name.'.js*" --files')
  elseif executable('ag')
    let l:files = jsfileimport#utils#systemlist('ag -g "(/|^)'.a:name.'.js.*"')
  elseif executable('ack')
    let l:files = jsfileimport#utils#systemlist('ack -g "(/|^)'.a:name.'.js.*"')
  else
    let l:files = [findfile(a:name.'.js', '**/*')]
    if a:rgx['type'] ==? 'import'
      call add(l:files, findfile(a:name.'.jsx', '**/*'))
    endif
  endif

  for l:file in l:files
    if l:file !=? '' && !s:tags_has_filename(a:tags, l:file) && expand('%:p') !=? fnamemodify(l:file, ':p')
      call add(a:tags, { 'filename': l:file, 'name': a:name, 'kind': 'F', 'cmd': '' })
    endif
  endfor

  return a:tags
endfunction "}}}

function! s:is_global_package(name) abort "{{{
  let l:package_json = getcwd().'/package.json'
  if !filereadable(l:package_json)
    return ''
  endif

  let l:package_json_data = readfile(l:package_json, '')
  let l:data = json_decode(join(l:package_json_data))

  for l:name in s:get_name_variations(a:name)
    if has_key(l:data, 'dependencies') && has_key(l:data['dependencies'], l:name)
      return l:name
    endif

    if has_key(l:data, 'devDependencies') && has_key(l:data['devDependencies'], l:name)
      return l:name
    endif
  endfor

  return ''
endfunction "}}}

function! s:get_global_package_tag(name) abort "{{{
  let l:global_package = s:is_global_package(a:name)
  if empty(l:global_package)
    return {}
  endif

  let l:global_taglist = filter(taglist('^'.l:global_package.'$'), 'v:val.filename ==? "package.json"')
  if len(l:global_taglist) > 0
    return l:global_taglist[0]
  endif

  return {}
endfunction "}}}

function! s:check_if_global_tag(tag) abort "{{{
  return a:tag['filename'] =~? 'package.json'
endfunction "}}}

function! s:get_name_variations(name) abort "{{{
  let l:search = []
  call add(l:search, substitute(a:name, '\C\(\<\u[a-z0-9]\+\|[a-z0-9]\+\)\(\u\)', '\l\1_\l\2', 'g')) "snake case
  call add(l:search, substitute(a:name, '\C\(\<\u[a-z0-9]\+\|[a-z0-9]\+\)\(\u\)', '\l\1-\l\2', 'g')) "hyphen case
  call add(l:search, substitute(l:search[0], '_\(\l\)', '\u\1', 'g')) "lower camel case
  call add(l:search, substitute(l:search[0], '\(\%(\<\l\+\)\%(_\)\@=\)\|_\(\l\)', '\u\1\2', 'g')) "upper camel case
  call add(l:search, tolower(a:name))
  call add(l:search, toupper(a:name))
  call add(l:search, a:name)
  return uniq(sort(l:search))
endfunction "}}}
" vim:foldenable:foldmethod=marker:sw=2

function! jsfileimport#tags#_get_tag(name, rgx, showList) abort
  let l:tags = jsfileimport#tags#_get_taglist(a:name, a:rgx)
  call filter(l:tags, function('s:removeTagsWithCurrentPath'))

  if len(l:tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      return { 'global': a:name }
    endif
    if g:js_file_import_prompt_if_no_tag
      echo 'No tag found. Falling back to prompt.'
      return jsfileimport#tags#_get_tag_data_from_prompt(a:name, a:rgx)
    endif
    throw 'No tag found.'
  endif

  if a:showList == 0 && len(l:tags) == 1
    return { 'tag': l:tags[0], 'global': s:checkIfGlobalTag(l:tags[0], a:name) }
  endif

  let l:tagSelectionList = jsfileimport#tags#_generate_tags_selection_list(l:tags)
  let l:promptIndex = len(l:tagSelectionList) + 1
  let l:promptImport = [l:promptIndex.' - Enter path to file or package name manually']
  let l:options = ['Select file to import:'] + l:tagSelectionList + l:promptImport

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 1
    throw ''
  endif

  if l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  if l:selection == l:promptIndex
    return jsfileimport#tags#_get_tag_data_from_prompt(a:name, a:rgx)
  endif

  let l:selectedTag = l:tags[l:selection - 1]
  return { 'tag': l:selectedTag, 'global': s:checkIfGlobalTag(l:selectedTag, a:name) }
endfunction

function! jsfileimport#tags#_get_tag_data_from_prompt(name, rgx, ...) abort
  call inputsave()
  let l:path = input('Path to file or package name: ', '', 'file')
  call inputrestore()

  if l:path ==? ''
    throw 'No path entered.'
  endif

  let l:tagData = { 'global': '', 'tag': { 'filename': l:path, 'cmd': '', 'kind': '' } }
  let l:fullPath = getcwd().'/'.l:path

  if filereadable(l:fullPath)
    return l:tagData
  endif

  if s:isGlobalPackage(l:path)
    let l:tagData['global'] = l:path
    return l:tagData
  endif

  let l:choice = confirm('File or package not found. Import as:', "&File\n&Package\n&Cancel")
  if l:choice == 3
    throw ''
  elseif l:choice == 2
    let l:tagData['global'] = l:path
  endif

  return l:tagData
endfunction

function! jsfileimport#tags#_get_taglist(name, rgx) abort
  let l:tags = taglist('^'.a:name.'$')
  call filter(l:tags, function('s:removeObsolete'))
  call s:appendTagsByFilename(l:tags, a:name, a:rgx)

  return l:tags
endfunction

function! jsfileimport#tags#_generate_tags_selection_list(tags) abort
  let l:index = 0
  let l:options = []

  for l:tag in a:tags
    let l:index += 1
    let l:cmd = l:tag['cmd'] !=? '' ? ' - ('.l:tag['cmd'].')' : ''
    call add(l:options, l:index.' - '.l:tag['filename'].' - '.l:tag['kind'].l:cmd)
  endfor

  return l:options
endfunction

function! jsfileimport#tags#_get_tag_in_current_file(tags, currentFilePath) abort
  for l:tag in a:tags
    if fnamemodify(l:tag['filename'], ':p') ==? a:currentFilePath
      return l:tag
    endif
  endfor
  return { 'filename': '' }
endfunction

function! jsfileimport#tags#_jump_to_tag(tag, currentFilePath) abort
  let l:tagPath = fnamemodify(a:tag['filename'], ':p')

  if l:tagPath !=? a:currentFilePath && bufname('%') !=? a:tag['filename']
    silent exe 'e '.a:tag['filename']
  else
    "Sets the previous context mark to allow jumping to this location with CTRL-O
    silent exe 'norm!m`'
  endif
  silent exe escape(a:tag['cmd'], '[]')
  return 1
endfunction

function! s:removeTagsWithCurrentPath(idx, tag) abort "{{{
  if expand('%:p') ==? fnamemodify(a:tag['filename'], ':p')
    return 0
  endif

  return 1
endfunction "}}}

function! s:tagsHasFilename(tags, filename) abort "{{{
  for l:tag in a:tags
    if l:tag['filename'] ==? a:filename
      return 1
    endif
  endfor

  return 0
endfunction "}}}

function! s:removeObsolete(idx, tag) abort "{{{
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

function! s:appendTagsByFilename(tags, name, rgx) abort "{{{
  let l:search = []
  call add(l:search, substitute(a:name, '\C\(\<\u[a-z0-9]\+\|[a-z0-9]\+\)\(\u\)', '\l\1_\l\2', 'g')) "snake case
  call add(l:search, substitute(a:name, '_\(\l\)', '\u\1', 'g')) "lower camel case
  call add(l:search, substitute(a:name, '\(\%(\<\l\+\)\%(_\)\@=\)\|_\(\l\)', '\u\1\2', 'g')) "upper camel case
  call uniq(l:search)

  for l:item in l:search
    call s:appendFilenameToTags(a:tags, l:item, a:rgx)
  endfor

  return a:tags
endfunction "}}}

function! s:appendFilenameToTags(tags, name, rgx) abort "{{{
  let l:files = []

  if executable('rg')
    let l:files = systemlist('rg -g "'.a:name.'.js*" --files .', a:name)
  elseif executable('ag')
    let l:files = systemlist('ag -g "(/|^)'.a:name.'.js.*"')
  elseif executable('ack')
    let l:files = systemlist('ack -g "(/|^)'.a:name.'.js.*"')
  else
    let l:files = [findfile(a:name.'.js', '**/*')]
    if a:rgx['type'] ==? 'import'
      call add(l:files, findfile(a:name.'.jsx', '**/*'))
    endif
  endif

  for l:file in l:files
    if l:file !=? '' && !s:tagsHasFilename(a:tags, l:file)
      call add(a:tags, { 'filename': l:file, 'name': a:name, 'kind': 'C', 'cmd': '' })
    endif
  endfor

  return a:tags
endfunction "}}}

function! s:isGlobalPackage(name) abort "{{{
  let l:packageJson = getcwd().'/package.json'
  if !filereadable(l:packageJson)
    return 0
  endif

  let l:packageJsonData = readfile(l:packageJson, '')
  let l:data = json_decode(join(l:packageJsonData))

  if has_key(l:data, 'dependencies') && has_key(l:data['dependencies'], a:name)
    return 1
  endif

  if has_key(l:data, 'devDependencies') && has_key(l:data['devDependencies'], a:name)
    return 1
  endif

  return 0
endfunction "}}}

function! s:checkIfGlobalTag(tag, name) abort "{{{
  if a:tag['filename'] =~? 'package.json'
    return a:name
  endif
  return ''
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

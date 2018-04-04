function! jsfileimport#word(...) abort
  return s:doImport('jsfileimport#tags#_get_tag', a:0)
endfunction

function! jsfileimport#prompt() abort
  return s:doImport('jsfileimport#tags#_get_tag_data_from_prompt', 0)
endfunction

function! jsfileimport#clean() abort
  silent exe 'normal mz'
  let l:rgx = s:determineImportType()
  call cursor(1, 0)
  let l:start = search(l:rgx['lastimport'], 'c')
  let l:end = search(l:rgx['lastimport'], 'be')

  for l:line in getline(l:start, l:end)
    let l:list = matchlist(l:line, l:rgx['importName'])
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
    silent exe 'normal mz'
  endif

  let l:rgx = s:determineImportType()

  if search(l:rgx['selectForSort'], 'be') > 0
    silent exe g:js_file_import_sort_command
  endif

  silent exe 'normal! `z'
  return 1
endfunction

function! jsfileimport#goto(...) abort
  try
    call jsfileimport#utils#_check_python_support()
    let l:name = jsfileimport#utils#_get_word()
    let l:rgx = s:determineImportType()
    let l:tags = jsfileimport#tags#_get_taglist(l:name, l:rgx)
    let l:currentFilePath = expand('%:p')

    if len(l:tags) == 0
      throw 'Tag not found.'
    endif

    if a:0 == 0
      if len(l:tags) == 1
        return jsfileimport#tags#_jump_to_tag(l:tags[0], l:currentFilePath)
      endif

      let l:tagInCurrentFile = jsfileimport#tags#_get_tag_in_current_file(l:tags, l:currentFilePath)

      if l:tagInCurrentFile['filename'] !=? ''
        return jsfileimport#tags#_jump_to_tag(l:tagInCurrentFile, l:currentFilePath)
      endif
    endif

    let l:tagSelectionList = jsfileimport#tags#_generate_tags_selection_list(l:tags)
    let l:options = extend(['Current path: '.expand('%'), 'Select definition:'], l:tagSelectionList)

    call inputsave()
    let l:selection = inputlist(l:options)
    call inputrestore()

    if l:selection < 1
      return 0
    endif

    if l:selection >= len(l:options) - 1
      throw 'Wrong selection.'
    endif

    return jsfileimport#tags#_jump_to_tag(l:tags[l:selection - 1], l:currentFilePath)
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
  let l:rgx = s:determineImportType()
  let l:word = jsfileimport#utils#_get_word()
  let l:currentFilePath = expand('%')
  let l:executable = executable('rg') ? 'rg' : 'ag'
  let l:line = line('.')

  let l:files = systemlist(l:executable.' '.l:word.' --vimgrep .')
  call filter(l:files, {idx, val -> val !~ '^'.l:currentFilePath.':'.l:line.'.*$'})
  let l:options = ['Select usage:']

  let l:index = 0
  for l:file in l:files
    let l:index += 1
    call add(l:options, l:index.' - '.l:file)
  endfor

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 1
    throw ''
  endif

  if l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  let [l:filename, l:row, l:column] = matchlist(l:files[l:selection - 1], '\([^:]*\):\(\d*\):\(\d*\):\(.*\)')[1:3]
  let l:openFileCommand = ''

  if expand('%:p') !=? fnamemodify(l:filename, ':p')
    let l:openFileCommand = 'e '.l:filename
  else
    silent exe 'norm!m`'
  endif

  let l:command = printf('%s|call cursor(%s, %s)', l:openFileCommand, l:row, l:column)
  silent exe l:command
  return 1
  catch /.*/
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
  endtry
endfunction

function! s:doImport(tagFnName, showList) abort "{{{
  silent exe 'normal mz'

  try
    call jsfileimport#utils#_check_python_support()
    let l:name = jsfileimport#utils#_get_word()
    let l:rgx = s:determineImportType()
    call s:checkIfExists(l:name, l:rgx)
    let l:tagData = call(a:tagFnName, [l:name, l:rgx, a:showList])

    if l:tagData['global'] !=? ''
      return s:processImport(l:name, l:tagData['global'], l:rgx, 1)
    endif

    return s:importTag(l:tagData['tag'], l:name, l:rgx)
  catch /.*/
    silent exe 'normal! `z'
    if v:exception !=? ''
      return jsfileimport#utils#_error(v:exception)
    endif
    return 0
  endtry
endfunction "}}}

function! s:isPartialImport(tag, name, rgx) "{{{
  let l:partialRgx = substitute(a:rgx['partialExport'], '__FNAME__', a:name, 'g')

  " Method or partial export
  if a:tag['kind'] =~# '\(m\|p\)' || a:tag['cmd'] =~# l:partialRgx
    return 1
  endif

  if a:tag['cmd'] =~# a:rgx['defaultExport'].a:name
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let l:filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(l:filePath)
    return 0
  endif

  if match(join(readfile(l:filePath, '')), l:partialRgx) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:processImport(name, path, rgx, ...) abort "{{{
  let l:importRgx = a:rgx['import']
  let l:importRgx = substitute(l:importRgx, '__FNAME__', a:name, '')
  let l:importRgx = substitute(l:importRgx, '__FPATH__', a:path, '')
  let l:appendToStart = 0

  if a:0 > 0 && g:js_file_import_package_first
    let l:appendToStart = 1
  endif

  if search(a:rgx['lastimport'], 'be') > 0 && l:appendToStart == 0
    call append(line('.'), l:importRgx)
  elseif search(a:rgx['lastimport']) > 0
    call append(line('.') - 1, l:importRgx)
  else
    call append(0, l:importRgx)
    call append(1, '')
  endif
  return s:finishImport()
endfunction "}}}

function! s:checkIfExists(name, rgx) abort "{{{
  let l:pattern = substitute(a:rgx['checkImportExists'], '__FNAME__', a:name, '')

  if search(l:pattern, 'n') > 0
    throw 'Import already exists.'
  endif

  return 0
endfunction "}}}

function! s:importTag(tag, name, rgx) abort "{{{
  let l:isPartial = s:isPartialImport(a:tag, a:name, a:rgx)
  let l:path = jsfileimport#utils#_get_file_path(a:tag['filename'])
  let l:currentFilePath = jsfileimport#utils#_get_file_path(expand('%:p'))

  if l:path ==# l:currentFilePath
    throw 'Import failed. Selected import is in this file.'
  endif

  let l:escapedPath = escape(l:path, './')

  if l:isPartial == 0
    return s:processFullImport(a:name, a:rgx, l:path)
  endif

  " Check if only full import exists for given path. ES6 allows partial imports alongside full import
  let l:existingFullPathOnly = substitute(a:rgx['existingFullPathOnly'], '__FPATH__', l:escapedPath, '')

  if a:rgx['type'] ==? 'import' && search(l:existingFullPathOnly, 'n') > 0
    call search(l:existingFullPathOnly, 'e')
    return s:processPartialImportAlongsideFull(a:name)
  endif

  "Partial single line
  let l:existingPathRgx = substitute(a:rgx['existingPath'], '__FPATH__', l:escapedPath, '')

  if search(l:existingPathRgx, 'n') <= 0
    return s:processImport('{ '.a:name.' }', l:path, a:rgx)
  endif

  call search(l:existingPathRgx)
  let l:startLine = line('.')
  call search(l:existingPathRgx, 'e')
  let l:endLine = line('.')

  if l:endLine > l:startLine
    return s:processMultiLinePartialImport(a:name)
  endif

  return s:processSingleLinePartialImport(a:name)
endfunction "}}}

function! s:processFullImport(name, rgx, path) abort "{{{
  let l:escPath = escape(a:path, './')
  let l:existingImportRgx = substitute(a:rgx['existingPathForFull'], '__FPATH__', l:escPath, '')

  if a:rgx['type'] ==? 'import' && search(l:existingImportRgx, 'n') > 0
    call search(l:existingImportRgx)
    silent exe ':normal!i'.a:name.', '
    return s:finishImport()
  endif

  return s:processImport(a:name, a:path, a:rgx)
endfunction "}}}

function! s:processSingleLinePartialImport(name) abort "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor ==? ',' ? ' ' : ', '
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:firstChar.a:name.lastChar

  return s:finishImport()
endfunction "}}}

function! s:processMultiLinePartialImport(name) abort "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor !=? ',' ? ',': ''
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  silent exe ':normal!a'.l:firstChar
  silent exe ':normal!o'.a:name.l:lastChar

  return s:finishImport()
endfunction "}}}

function! s:processPartialImportAlongsideFull(name) abort "{{{
  silent exe ':normal!a, { '.a:name.' }'

  return s:finishImport()
endfunction "}}}

function! s:determineImportType() abort "{{{
  let l:requireRegex = {
        \ 'type': 'require',
        \ 'checkImportExists': '^\(const\|let\|var\)\s*\_[^''"]\{-\}\<__FNAME__\>\s*\_[^''"]\{-\}=\s*require(',
        \ 'existingPath': '^\(const\|let\|var\)\s*{\s*\zs\_[^''"]\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingFullPathOnly': '^\(const\|let\|var\)\s*\zs\<[^''"]\{-\}\>\ze\s*\_[^''"]\{-\}=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'existingPathForFull': '^\(const\|let\|var\)\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*=\s*require([''"]__FPATH__[''"]);\?$',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_.\{-\}require(.*;\?$',
        \ 'defaultExport': 'module.exports\s*=.\{-\}',
        \ 'partialExport': 'module.exports.\(\<__FNAME__\>\|\s*=\_[^{]\{-\}{\_[^}]\{-\}\<__FNAME__\>\_[^}]\{-\}}\)',
        \ 'selectForSort': '^\(const\|let\|var\)\s*\zs.*\ze\s*=\s*require.*;\?$',
        \ 'importName': '^\(const\|let\|var\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  let l:importRegex = {
        \ 'type': 'import',
        \ 'checkImportExists': '^import\s*\_[^''"]\{-\}\<__FNAME__\>\_[^''"]\{-\}\s*from',
        \ 'existingPath': '^import\s*[^{''"]\{-\}{\s*\zs\_[^''"]\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existingFullPathOnly': '^import\s*\zs\<[^''"]\{-\}\>\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'existingPathForFull': '^import\s*\zs{\s*\_[^''"]\{-\}\s*}\ze\s*from\s*[''"]__FPATH__[''"];\?$',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': '^import\s\_.\{-\}from.*;\?$',
        \ 'defaultExport': 'export\s*default.\{-\}',
        \ 'partialExport': 'export\s*\(const\|var\|function\)\s*\<__FNAME__\>',
        \ 'selectForSort': '^import\s*\zs.*\ze\s*from.*;\?$',
        \ 'importName': '^\(import\)\s*\(\<[^''"]\{-\}\>\)\s*',
        \ }

  if g:js_file_import_force_require || search(l:requireRegex['lastimport'], 'n') > 0
    return l:requireRegex
  endif

  return l:importRegex
endfunction "}}}

function! s:finishImport() abort "{{{
  if g:js_file_import_sort_after_insert > 0
    call jsfileimport#sort(1)
  endif

  silent exe 'normal! `z'
  return 1
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

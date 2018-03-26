if exists('g:loaded_js_file_import')
  finish
endif
let g:loaded_js_file_import = 1

let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)
let g:js_file_import_sort_command = get(g:, 'js_file_import_sort_command', "'{,'}-1sort i")
let g:js_file_import_sort_after_insert = get(g:, 'js_file_import_sort_after_insert', 0)
let g:js_file_import_prompt_if_no_tag = get(g:, 'js_file_import_prompt_if_no_tag', 1)
let g:js_file_import_package_first = get(g:, 'js_file_import_package_first', 1)

function! JsFileImport()
  return s:doImport('getTag')
endfunction

function! PromptJsFileImport()
  return s:doImport('getTagDataFromPrompt')
endfunction

function! RemoveUnusedJsFileImports()
  exe 'normal mz'
  let l:rgx = s:determineImportType()
  call cursor(1, 0)
  let l:start = search(l:rgx['lastimport'], 'c')
  let l:end = search(l:rgx['lastimport'], 'be')

  for l:line in getline(l:start, l:end)
    let l:list = matchlist(l:line, l:rgx['importName'])
    if len(l:list) >= 3 && s:countWordInFile(l:list[2]) <= 1
      exe l:start.'d'
      continue
    endif
    let l:start += 1
  endfor
  silent exe 'normal! `z'
endfunction

function! SortJsFileImport(...)
  if a:0 == 0
    exe 'normal mz'
  endif

  let l:rgx = s:determineImportType()

  if search(l:rgx['selectForSort'], 'be') > 0
    exe g:js_file_import_sort_command
  endif

  silent exe 'normal! `z'
  return 1
endfunction

function! s:doImport(tagFnName) "{{{
  exe 'normal mz'

  try
    call s:checkPythonSupport()
    let l:name = expand('<cword>')
    let l:rgx = s:determineImportType()
    call s:checkIfExists(l:name, l:rgx)
    let l:tagData = call('s:'.a:tagFnName, [l:name, l:rgx])

    if l:tagData['global'] !=? ''
      return s:processImport(l:name, l:tagData['global'], l:rgx, 1)
    endif

    return s:importTag(l:tagData['tag'], l:name, l:rgx)
  catch /.*/
    silent exe 'normal! `z'
    if v:exception !=? ''
      echo v:exception
    endif
    return 0
  endtry
endfunction "}}}

function! s:getTagDataFromPrompt(name, rgx) "{{{
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
endfunction "}}}

function! s:getTag(name, rgx) "{{{
  let l:tags = taglist('^'.a:name.'$')
  call filter(l:tags, function('s:removeObsolete'))
  call s:appendTagsByFilename(l:tags, a:name, a:rgx)

  if len(l:tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      return { 'global': a:name }
    endif
    if g:js_file_import_prompt_if_no_tag
      echo 'No tag found. Falling back to prompt.'
      return s:getTagDataFromPrompt(a:name, a:rgx)
    endif
    throw 'No tag found.'
  endif

  if len(l:tags) == 1
    return { 'tag': l:tags[0], 'global': s:checkIfGlobalTag(l:tags[0], a:name) }
  endif

  let l:options = ['Select file to import:']
  let l:index = 0

  for l:tag in l:tags
    let l:index += 1
    let l:cmd = l:tag['cmd'] != '' ? ' - ('.l:tag['cmd'].')' : ''
    call add(l:options, l:index.' - '.l:tag['filename'].' - '.l:tag['kind'].l:cmd)
  endfor
  let l:lastIndex = l:index + 1
  call add(l:options, l:lastIndex.' - Enter path to file or package name manually')

  call inputsave()
  let l:selection = inputlist(l:options)
  call inputrestore()

  if l:selection < 0 || l:selection >= len(l:options)
    throw 'Wrong selection.'
  endif

  if l:selection == l:lastIndex
    return s:getTagDataFromPrompt(a:name, a:rgx)
  endif

  let l:selectedTag = l:tags[l:selection - 1]
  return { 'tag': l:selectedTag, 'global': s:checkIfGlobalTag(l:selectedTag, a:name) }
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

function! s:getFilePath(filepath) "{{{
  let l:pyCommand = has('python3') ? 'py3' : 'py'
  let l:path = a:filepath

  exe l:pyCommand.' import vim, os.path'
  exe l:pyCommand.' currentPath = vim.eval("expand(''%:p:h'')")'
  exe l:pyCommand.' tagPath = vim.eval("fnamemodify(a:filepath, '':p'')")'
  exe l:pyCommand.' path = os.path.splitext(os.path.relpath(tagPath, currentPath))[0]'
  exe l:pyCommand.' leadingSlash = "./" if path[0] != "." else ""'
  exe l:pyCommand.' vim.command(''let l:path = "%s%s"'' % (leadingSlash, path))'

  return l:path
endfunction "}}}

function! s:processImport(name, path, rgx, ...) "{{{
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

function! s:checkIfExists(name, rgx) "{{{
  let l:pattern = substitute(a:rgx['checkImportExists'], '__FNAME__', a:name, '')

  if search(l:pattern, 'n') > 0
    throw 'Import already exists.'
  endif

  return 0
endfunction "}}}

function! s:importTag(tag, name, rgx) "{{{
  let l:isPartial = s:isPartialImport(a:tag, a:name, a:rgx)
  let l:path = s:getFilePath(a:tag['filename'])
  let l:currentFilePath = s:getFilePath(expand('%:p'))

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

function! s:processFullImport(name, rgx, path) "{{{
  let l:escPath = escape(a:path, './')
  let l:existingImportRgx = substitute(a:rgx['existingPathForFull'], '__FPATH__', l:escPath, '')

  if a:rgx['type'] ==? 'import' && search(l:existingImportRgx, 'n') > 0
    call search(l:existingImportRgx)
    exe ':normal!i'.a:name.', '
    return s:finishImport()
  endif

  return s:processImport(a:name, a:path, a:rgx)
endfunction "}}}

function! s:processSingleLinePartialImport(name) "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor ==? ',' ? ' ' : ', '
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  exe ':normal!a'.l:firstChar.a:name.lastChar

  return s:finishImport()
endfunction "}}}

function! s:processMultiLinePartialImport(name) "{{{
  let l:charUnderCursor = getline('.')[col('.') - 1]
  let l:firstChar = l:charUnderCursor !=? ',' ? ',': ''
  let l:lastChar = l:charUnderCursor ==? ',' ? ',' : ''

  exe ':normal!a'.l:firstChar
  exe ':normal!o'.a:name.l:lastChar

  return s:finishImport()
endfunction "}}}

function! s:processPartialImportAlongsideFull(name) "{{{
  exe ':normal!a, { '.a:name.' }'

  return s:finishImport()
endfunction "}}}

function! s:determineImportType() "{{{
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

function! s:appendTagsByFilename(tags, name, rgx) "{{{
  let l:search = []
  call add(l:search, substitute(a:name, '\C\(\<\u[a-z0-9]\+\|[a-z0-9]\+\)\(\u\)', '\l\1_\l\2', 'g')) "snake case
  call add(l:search, substitute(a:name, '_\(\l\)', '\u\1', 'g')) "lower camel case
  call add(l:search, substitute(a:name, '\(\%(\<\l\+\)\%(_\)\@=\)\|_\(\l\)', '\u\1\2', 'g')) "upper camel case

  for l:item in l:search
    call s:appendFilenameToTags(a:tags, l:item, 'js')

    if a:rgx['type'] ==? 'import'
      call s:appendFilenameToTags(a:tags, l:item, 'jsx')
    endif
  endfor

  return a:tags
endfunction "}}}

function! s:appendFilenameToTags(tags, name, extension) "{{{
  let l:file = findfile(a:name.'.'.a:extension, '**/*')

  if l:file != '' && !s:tagsHasFilename(a:tags, l:file)
    call add(a:tags, { 'filename': l:file, 'name': a:name, 'kind': 'C', 'cmd': '' })
  endif

  return a:tags
endfunction "}}}

function! s:tagsHasFilename(tags, filename) "{{{
  for l:tag in a:tags
    if l:tag['filename'] ==? a:filename
      return 1
    endif
  endfor

  return 0
endfunction "}}}

function! s:removeObsolete(idx, val) "{{{
  let l:v = a:val['cmd']
  let l:f = a:val['filename']
  if l:v =~? 'import\s*from' || l:v =~? 'require(' || l:f =~? 'package.lock'
    return 0
  endif

  return 1
endfunction "}}}

function! s:isGlobalPackage(name) "{{{
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

function! s:checkIfGlobalTag(tag, name) "{{{
  if a:tag['filename'] =~? 'package.json'
    return a:name
  endif
  return ''
endfunction "}}}

function! s:finishImport() "{{{
  if g:js_file_import_sort_after_insert > 0
    call SortJsFileImport(1)
  endif

  silent exe 'normal! `z'
  return 1
endfunction "}}}

function! s:checkPythonSupport() "{{{
  if !has('python') && !has('python3')
    throw 'Vim js file import requires python or python3 support.'
  endif

  return 1
endfunction "}}}

function! s:countWordInFile(word) "{{{
  redir => l:count
    silent exe '%s/\<' . a:word . '\>//gn'
  redir END

  let l:result = strpart(l:count, 0, stridx(l:count, ' '))
  return float2nr(str2float(l:result))
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

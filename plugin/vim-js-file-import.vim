let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)

function! JsFileImport()
  exe "normal mz"
  let name = expand("<cword>")
  let rgx = s:determineImportType()

  try
    let tagData = s:getTag(name, rgx)

    if tagData['global']
      return s:processImport(name, name, rgx)
    endif

    return s:importTag(tagData['tag'], name, rgx)
  catch /.*/
    exe "normal! `z"
    echo v:exception
    return 0
  endtry
endfunction

function! s:getTag(name, rgx) "{{{
  let tags = taglist("^".a:name."$")
  call filter(tags, function('s:removeObsolete'))

  if len(tags) <= 0
    if s:isGlobalPackage(a:name) > 0
      return { 'global': 1 }
    endif
    throw 'No tag found!'
  endif

  if len(tags) == 1
    return { 'tag': tags[0], 'global': s:checkIfGlobalTag(tags[0]) }
  endif

  let options = ['Select file to import:']
  let index = 0

  for tag in tags
    let index += 1
    call add(options, index.' - '.tag['filename'].' - '.tag['kind'].' - ('.tag['cmd'].')')
  endfor

  call inputsave()
  let selection = inputlist(options)
  call inputrestore()

  if selection > 0 && selection < len(options)
    let selectedTag = tags[selection - 1]
    return { 'tag': selectedTag, 'global': s:checkIfGlobalTag(selectedTag) }
  endif

  throw 'Wrong selection!'
endfunction "}}}

function! s:checkIfPartialExists(name, rgx) "{{{
  let pattern = substitute(a:rgx['checkPartialImportExists'], '__FNAME__', a:name, '')
  let multilinePattern = substitute(a:rgx['checkPartialMultiLineImportExists'], '__FNAME__', a:name, '')

  if search(pattern, 'n') > 0 || search(multilinePattern, 'n') > 0
    throw "Import already exists"
  endif

  return 0
endfunction "}}}

function! s:isPartialImport(tag, name, rgx) "{{{
  let full = { 'partial': 0, 'name': a:name }
  let partial = { 'partial': 1, 'name': a:name }

  " Method or partial export
  if a:tag['kind'] =~ '\(m\|p\)' || a:tag['cmd'] =~ a:rgx['partialExport']
    return 1
  endif

  if a:tag['cmd'] =~ a:rgx['defaultExport']
    return 0
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(filePath)
    return 0
  endif

  let fileContent = readfile(filePath, '')

  if match(fileContent, a:rgx['defaultExport'].a:name) > -1
    return 0
  endif

  if match(fileContent, a:rgx['partialExport'].a:name) > -1
    return 1
  endif

  return 0
endfunction "}}}

function! s:getFilePath(filepath) "{{{
  let currentFilePath = expand('%:p:h')
  let tagFile = fnamemodify(a:filepath, ':p')

  let path = system('python -c "import os.path; print os.path.relpath('''.tagFile.''', '''.currentFilePath.''')"')
  let path = fnamemodify(substitute(path, '\n\+$', '', ''), ':r')
  let firstChar = strpart(path, 0, 1)

  if  firstChar != '.' && firstChar != '/'
    let path = './'.path
  endif

  return path
endfunction "}}}

function! s:processImport(name, path, rgx) "{{{
  call s:checkIfExists(a:name, a:rgx)
  let importRgx = a:rgx['import']
  let importRgx = substitute(importRgx, '__FNAME__', a:name, '')
  let importRgx = substitute(importRgx, '__FPATH__', a:path, '')

  if search(a:rgx['lastimport'], 'be') > 0
    call append(line("."), importRgx)
  else
    call append(0, importRgx)
    call append(1, '')
  endif
  exe "normal! `z"
  return 1
endfunction "}}}

function! s:checkIfExists(name, rgx) "{{{
  let pattern = substitute(a:rgx['checkImportExists'], '__FNAME__', a:name, '')

  if search(pattern, 'n') > 0
    throw "Import already exists"
  endif

  return 0
endfunction "}}}

function! s:importTag(tag, name, rgx) "{{{
  let isPartial = s:isPartialImport(a:tag, a:name, a:rgx)
  let path = s:getFilePath(a:tag['filename'])
  let escapedPath = escape(path, './')

  if isPartial == 0
    return s:processImport(a:name, path, a:rgx)
  endif

  call s:checkIfPartialExists(a:name, a:rgx)

  "Partial single line
  let existingPathRgx = substitute(a:rgx['existingPath'], '__FPATH__', escapedPath, '')
  let existingImport = search(existingPathRgx, 'e')

  if existingImport > 0
    return s:processSingleLinePartialImport(a:name)
  endif

  "Partial multi line
  let existingMultiLinePathRgx = substitute(a:rgx['existingMultiLinePath'], '__FPATH__', escapedPath, '')
  let existingMultiLineImport = search(existingMultiLinePathRgx, 'e')

  if existingMultiLineImport > 0
    return s:processMultiLinePartialImport(a:name)
  endif

  return s:processImport('{ '.a:name.' }', path, a:rgx)
endfunction "}}}

function! s:processSingleLinePartialImport(name) "{{{
  let charUnderCursor = getline('.')[col('.') - 1]
  let firstChar = charUnderCursor == ',' ? ' ' : ', '
  let lastChar = charUnderCursor == ',' ? ',' : ''

  exe ':normal!a'.firstChar.a:name.lastChar
  exe ':normal! `z'

  return 1
endfunction "}}}

function! s:processMultiLinePartialImport(name) "{{{
  let charUnderCursor = getline('.')[col('.') - 1]
  let firstChar = charUnderCursor != ',' ? ',': ''
  let lastChar = charUnderCursor == ',' ? ',' : ''

  exe ':normal!a'.firstChar
  exe ':normal!o'.a:name.lastChar
  exe ':normal! `z'

  return 1
endfunction "}}}

function! s:determineImportType() "{{{
  let requireRegex = {
        \ 'checkImportExists': '^\(const\|let\|var\)\s*__FNAME__\s*=\s*require(',
        \ 'checkPartialImportExists': '^\(const\|let\|var\)\s*{.*__FNAME__.*}\s*=\srequire(',
        \ 'checkPartialMultiLineImportExists': '^\(const\|let\|var\)\s*{\n\_.\{-\}__FNAME__\_.\{-\}}\s*=\srequire(',
        \ 'existingPath': '^\(const\|let\|var\)\s*{\s*\zs.\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?',
        \ 'existingMultiLinePath': '^\(const\|let\|var\)\s*{\s*\n\zs\_.\{-\}\ze\s*}\s*=\s*require([''"]__FPATH__[''"]);\?',
        \ 'import': "const __FNAME__ = require('__FPATH__');",
        \ 'lastimport': '^\(const\|let\|var\)\s\_.*require(.*;\?',
        \ 'defaultExport': 'module.exports\s*=.*',
        \ 'partialExport': 'module.exports.',
        \ }

  let importRegex = {
        \ 'checkImportExists': 'import\s*__FNAME__\s*from',
        \ 'checkPartialImportExists': '^import\s*{.*__FNAME__.*}\s*from',
        \ 'checkPartialMultiLineImportExists': '^import\s*{\n\_.\{-\}__FNAME__\_.\{-\}}\s*from',
        \ 'existingPath': '^import\s*{\s*\zs.\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?',
        \ 'existingMultiLinePath': '^import\s*{\s*\n\zs\_.\{-\}\ze\s*}\s*from\s*[''"]__FPATH__[''"];\?',
        \ 'import': "import __FNAME__ from '__FPATH__';",
        \ 'lastimport': 'import\s\_.from.*;',
        \ 'defaultExport': 'export\s*default.*',
        \ 'partialExport': 'export\s\(const\|var\).*',
        \ }

  if g:js_file_import_force_require || search(requireRegex['lastimport'], 'n') > 0
    return requireRegex
  endif

  return importRegex
endfunction "}}}

function! s:removeObsolete(idx, val) "{{{
  let v = a:val['cmd']
  let f = a:val['filename']
  if v =~ 'import\s*from' || v =~ 'require(' || f =~ 'package.lock'
    return 0
  endif

  return 1
endfunction "}}}

function! s:isGlobalPackage(name) "{{{
  let packageJson = getcwd().'/package.json'
  if !filereadable(packageJson)
    return 0
  endif

  let packageJsonData = readfile(packageJson, '')
  let data = json_decode(join(packageJsonData))

  if has_key(data, 'dependencies') && has_key(data['dependencies'], a:name)
    return 1
  endif

  if has_key(data, 'devDependencies') && has_key(data['devDependencies'], a:name)
    return 1
  endif

  return 0
endfunction "}}}

function! s:checkIfGlobalTag(tag) "{{{
  if a:tag['filename'] =~ 'package.json'
    return 1
  endif
  return 0
endfunction "}}}

" vim:foldenable:foldmethod=marker:sw=2

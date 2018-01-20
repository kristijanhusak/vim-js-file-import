let g:js_file_import_force_require = get(g:, 'js_file_import_force_require', 0)

function! JsFileImport()
  exe "normal mz"
  let name = expand("<cword>")
  let rgx = s:determineImportType()

  try
    let tagData = s:getTag(name, rgx)

    if tagData['global']
      return s:doImport(name, name, rgx)
    endif

    let name = s:getImportName(tagData['tag'], name, rgx)
    let path = s:getFilePath(tagData['tag']['filename'])
    return s:doImport(name, path, rgx)
  catch /.*/
    exe "normal! `z"
    echo v:exception
    return 0
  endtry
endfunction

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
    call add(options, index . ' - ' . tag['filename'] . ' - '.tag['kind'].' - ('.tag['cmd'].')')
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

function! s:determineImportType() "{{{
  let requireRegex = {
  \ 'exist': '^\(const\|var\)\s*',
  \ 'import': "const __FNAME__ = require('__FPATH__');",
  \ 'lastimport': '^\(const\|var\)\s.*require(.*;\?',
  \ 'defaultExport': 'module.exports\s*=.*',
  \ 'partialExport': 'module.exports.',
  \ }

  let importRegex = {
  \ 'exist': 'import\s*',
  \ 'import': "import __FNAME__ from '__FPATH__';",
  \ 'lastimport': 'import\s.*from.*;',
  \ 'defaultExport': 'export\s*default.*',
  \ 'partialExport': 'export\s\(const\|var\).*',
  \ }


  if g:js_file_import_force_require || search(requireRegex['lastimport']) > 0
    return requireRegex
  endif

  return importRegex
endfunction "}}}

function! s:doImport(name, path, rgx) "{{{
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
  let name = substitute(a:name, '\s', '\\s', 'g')

  if search(a:rgx['exist'] . name . '.*;\?') > 0
    throw "Import already exists"
  endif

  return 0
endfunction "}}}

function! s:getImportName(tag, name, rgx) "{{{
  let name = a:name
  let destructedName = '{ ' . a:name . ' }'

  " Method or partial export
  if a:tag['kind'] =~ '\(m\|p\)' || a:tag['cmd'] =~ a:rgx['partialExport']
    return destructedName
  endif

  if a:tag['cmd'] =~ a:rgx['defaultExport']
    return name
  endif

  " Read file and try finding export in case when tag points to line
  " that is not descriptive enough
  let filePath = getcwd().'/'.a:tag['filename']

  if !filereadable(filePath)
    return name
  endif

  let fileContent = readfile(filePath, '')

  if match(fileContent, a:rgx['defaultExport'].name) > -1
    return name
  endif

  if match(fileContent, a:rgx['partialExport'].name) > -1
    return destructedName
  endif

  return name
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

" vim:foldenable:foldmethod=marker

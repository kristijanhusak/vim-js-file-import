function! FileImport()
  exe "normal mz"
  let name = expand("<cword>")
  if search('^const\s*' . name . '.*;') > 0
    exe "normal! `z"
    echo "Import already exists"
    return 0
  endif

  let tags = taglist("^".name."$")
  let foundTag = 0

  for tag in tags
    if tag['cmd'] =~ 'class\s'.name || tag['cmd'] =~ 'module\.exports.*'.name
      let foundTag = tag
      break
    endif
  endfor

  if foundTag is 0
    echo 'Tag not found'
    exe "normal! `z"
    return 0
  endif

  let path = system('realpath --relative-to="'.expand('%:p:h').'" ' . fnamemodify(foundTag['filename'], ':p'))
  let path = substitute(path, '\n\+$', '', '')
  let require = "const ".name." = require('".path."');"

  if search('^const\s.*require(.*;', 'be') > 0
    call append(line("."), require)
  else
    call append(0, require)
  endif
  exe "normal! `z"
endfunction

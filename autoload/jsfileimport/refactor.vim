function! jsfileimport#refactor#_extract() abort
  let l:method = jsfileimport#utils#_get_confirm_selection('Extract to', ['Variable', 'Method'])

  let l:word = jsfileimport#utils#_get_word(1)
  return call('jsfileimport#ast_extract#_'.tolower(l:method), [l:word])
endfunction

function! jsfileimport#refactor#_rename() abort
  let l:word = jsfileimport#utils#_get_word(0)

  return call('jsfileimport#rename#_word', [l:word])
endfunction

function! jsfileimport#refactor#extract() abort
  let l:method = jsfileimport#utils#get_confirm_selection('Extract to', ['Variable', 'Method'])

  let l:word = jsfileimport#utils#_get_word(1)
  return call('jsfileimport#extract#'.tolower(l:method), [l:word])
endfunction

function! jsfileimport#refactor#rename() abort
  let l:word = jsfileimport#utils#_get_word(0)

  return call('jsfileimport#rename#word', [l:word])
endfunction

function! jsfileimport#refactor#extract(word) abort
  let l:method = jsfileimport#utils#get_confirm_selection('Extract to', ['Variable', 'Method'])

  return call('jsfileimport#extract#'.tolower(l:method), [a:word])
endfunction

function! jsfileimport#refactor#rename(word) abort
  let l:method = jsfileimport#utils#get_confirm_selection('Rename', ['Variable', 'Method'])

  return call('jsfileimport#rename#'.tolower(l:method), [a:word])
endfunction

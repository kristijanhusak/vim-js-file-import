if g:js_file_import_no_mappings
  finish
endif

if exists('g:deoplete#enable_at_startup') && g:deoplete#enable_at_startup ==? 1 && g:deoplete_strip_file_extension ==? 1
  call deoplete#custom#source('file', 'converters', ['converter_strip_file_extension'])
endif

if !hasmapto(':JsFileImport<CR>') && !hasmapto('<Plug>(JsFileImport)') && maparg('<Leader>if', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>if <Plug>(JsFileImport)
endif

if !hasmapto('<Plug>(JsFileImport)', 'v') && maparg('<Leader>if', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>if <Plug>(JsFileImport)
endif

if !hasmapto(':JsFileImportList<CR>') && !hasmapto('<Plug>(JsFileImportList)') && maparg('<Leader>iF', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>iF <Plug>(JsFileImportList)
endif

if !hasmapto('<Plug>(JsFileImportList)', 'v') && maparg('<Leader>iF', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>iF <Plug>(JsFileImportList)
endif

if !hasmapto(':JsFileImportTypedef<CR>') && !hasmapto('<Plug>(JsFileImportTypedef)') && maparg('<Leader>it', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>it <Plug>(JsFileImportTypedef)
endif

if !hasmapto('<Plug>(JsFileImportTypedef)', 'v') && maparg('<Leader>it', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>it <Plug>(JsFileImportTypedef)
endif

if !hasmapto(':JsFileImportTypedefList<CR>') && !hasmapto('<Plug>(JsFileImportTypedefList)') && maparg('<Leader>iT', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>iT <Plug>(JsFileImportTypedefList)
endif

if !hasmapto('<Plug>(JsFileImportTypedefList)', 'v') && maparg('<Leader>iT', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>iT <Plug>(JsFileImportTypedefList)
endif

if !hasmapto(':JsGotoDefinition<CR>') && !hasmapto('<Plug>(JsGotoDefinition)') && maparg('<Leader>ig', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>ig <Plug>(JsGotoDefinition)
endif

if !hasmapto('<Plug>(JsGotoDefinition)', 'v') && maparg('<Leader>ig', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>ig <Plug>(JsGotoDefinition)
endif

if !hasmapto(':JsGotoDefinitionList<CR>') && !hasmapto('<Plug>(JsGotoDefinitionList)') && maparg('<Leader>iG', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>iG <Plug>(JsGotoDefinitionList)
endif

if !hasmapto('<Plug>(JsGotoDefinitionList)', 'v') && maparg('<Leader>iG', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>iG <Plug>(JsGotoDefinitionList)
endif

if !hasmapto(':JsFindUsage<CR>') && !hasmapto('<Plug>(JsFindUsage)') && maparg('<Leader>iu', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>iu <Plug>(JsFindUsage)
endif

if !hasmapto('<Plug>(JsFindUsage)', 'v') && maparg('<Leader>iu', 'v') ==? ''
  silent! xmap <buffer> <unique> <silent> <Leader>iu <Plug>(JsFindUsage)
endif

if !hasmapto(':PromptJsFileImport<CR>') && !hasmapto('<Plug>(PromptJsFileImport)') && maparg('<Leader>ip', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>ip <Plug>(PromptJsFileImport)
endif

if !hasmapto(':SortJsFileImport<CR>') && !hasmapto('<Plug>(SortJsFileImport)') && maparg('<Leader>is', 'n') ==? ''
  silent! nmap <buffer> <unique> <silent> <Leader>is <Plug>(SortJsFileImport)
endif

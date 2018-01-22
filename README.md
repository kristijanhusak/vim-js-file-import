# Vim js file import (alpha)

This plugin allows importing js files using ctags. Tested only with [Universal ctags](https://github.com/universal-ctags/ctags).

If you want more robust solution, check [vim-import-js](https://github.com/Galooshi/vim-import-js).

## Why?
I tried using [vim-import-js](https://github.com/Galooshi/vim-import-js), but it's really slow when used on big projects.

This plugin is written in vimscript and uses only python to generate relative paths, so it's performance is much better.

It doesn't handle all the cases that vim-import-js do (partial imports of npm packages, sorting of imports, configuration), but works most of the time.
There are still some things to be done and fixed. Check [Todo](#todo) section.

## Table of contents

* [Installation](#installation)
* [Examples](#examples)
* [Sorting](#sorting)
* [Settings](#settings)
* [Todo](#todo)
* [Contributing](#contributing)

### Installation

Install [Universal ctags](https://github.com/universal-ctags/ctags)
```sh
$ git clone https://github.com/universal-ctags/ctags
$ cd ctags && ./autogen.sh && ./configure && make && sudo make install
```

It's also recommended to install some plugin for auto-updating ctags, since this plugin heavily relies on it.
[gutentags](https://github.com/ludovicchabant/vim-gutentags) is good choice.

Add plugin to vimrc
```vimL
Plug 'ludovicchabant/vim-gutentags'
Plug 'kristijanhusak/vim-js-file-import'
```

Add binding to vimrc
```vimL
nnoremap <F5> :call JsFileImport()<CR>
```

### Examples
```js
import React from 'react';

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

Setting cursor on `MyButton` and pressing `<F5>` finds the component and adds import at top

```js
import React from 'react'
import MyButton from './components/MyButton'

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

By default `import <name> from <file>` is used. If file contains any `const <name> = require(<file>)`,
import will be added like that.

```js
const React = require('react')
const MyButton = require('./components/MyButton');

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

Partial imports are also handled (`import { <name> } from <file>`)

```js
import { MyButton } from './components/AllComponents';

class App extends React.Component {
  render() {
    return (<div><MyButton>Submit</MyButton></div>)
  }
}
```

### Sorting

To sort imports alphabetically use `SortJsFileImport()` function:

```vimL
nnoremap <F6> :call SortJsFileImport()
```

This:
```js
  import Foo from './file_path'
  import Bar from './another_file_path'
```

Becomes this:
```js
  import Bar from './another_file_path'
  import Foo from './file_path'
```

If you want imports to be always sorted, add `let g:js_file_import_sort_after_insert = 1` to your vimrc
and plugin will automatically sort imports after every insert

```vimL
let g:js_file_import_sort_after_insert = 1
```

### Settings

By default `import [name] from [file]` is used to add new imports, in case when there are no any other existing imports.
If file contains at least one `require([file])`, it will use the `require()` to import files.

To force using `require()` always, add this flag to settings:

```vimL
let g:js_file_import_force_require = 1
```

### Todo

* Allow adding flag to sort imports
* Test with exuberant ctags

### Contributing
There are no any special guidelines for contributing.

All types of contributions, suggestions and bug reports are very welcome!

### Thanks to:
* [Vim php namespace](https://github.com/arnaud-lb/vim-php-namespace) for inspiration and tests structure


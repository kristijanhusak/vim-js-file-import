# Vim js file import

This plugin allows importing js files using ctags.

Tested with [Universal ctags](https://github.com/universal-ctags/ctags)

[Ctags quick installation](#ctags-quick-installation)

Add binding to vimrc

```vimL
nnoremap <F5> :call JsFileImport()<CR>
```

Example:
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

### Ctags quick installation
```sh
$ git clone https://github.com/universal-ctags/ctags
$ cd ctags && ./autogen.sh && ./configure && make && sudo make install
```


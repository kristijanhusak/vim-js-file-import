# Vim js file import

This plugin allows importing js files using ctags.

Add binding to vimrc

```vimL
nnoremap <F5> :call FileImport()<CR>
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

Hovering over `MyButton` and pressing `<F5>` finds the component and adds import at top

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


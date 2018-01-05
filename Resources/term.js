class Term {
  constructor(xterm) {
    this._xterm = xterm;
    this._xterm.attachCustomKeyEventHandler(this._keyboardHandler);

    window.addEventListener('resize', () => this._fitResize());
  }

  init(element) {
    this._xterm.open(element);

    requestAnimationFrame(() => {
      this._initialize();
    });
  }

  write(data) {
    this._xterm.write(data);
  }

  focus() {
    this._xterm.focus();
  }

  blur() {
    this._xterm.blur();
  }

  clear() {
    this._xterm.clear();
  }

  reset() {
    this._xterm.reset();
  }

  loadFontFromCSS(cssPath, name) {
    const fontFamily = name + ', Menlo';

    WebFont.load({
      custom: { families: [name], urls: [cssPath] },
      context: window,
      active: () => {
        this._xterm.setOption('fontFamily', fontFamily);
      },
    });
    this._xterm.setOption('fontFamily', fontFamily);
  }

  _terminalReady(data) {
    window.webkit.messageHandlers.interOp.postMessage({
      op: 'terminalReady',
      data: data || {},
    });
  }

  _sigwinch(size) {
    window.webkit.messageHandlers.interOp.postMessage({
      op: 'sigwinch',
      data: size,
    });
  }

  _keyboardHandler(e) {
    return !e.catched;
  }

  _initialize() {
    this._xterm.charMeasure.measure(this._xterm.options);
    this._fitResize(size => {
      this._terminalReady({ size });
      this._xterm.on('resize', size =>
        this._sigwinch({ cols: size.cols, rows: size.rows }),
      );
    });
  }

  _fitResize(callback) {
    const bodyRect = document.body.getBoundingClientRect();

    const cols = Math.floor(bodyRect.width / this._xterm.charMeasure.width);
    const rows = Math.floor(bodyRect.height / this._xterm.charMeasure.height);
    this._xterm.resize(cols, rows);

    if (callback) {
      callback({ cols, rows });
    }
  }
}

# Havato test harness

Static + behavioural checks that run without PHP or a browser.

```bash
cd tests && npm install
node check.js ../havato        # PHP syntax across every file
node icon-sizing.js            # unsized-SVG guard + single Google button
```

`check.js` parses every PHP file with `php-parser`; the other suites model the
real semantics (CSS cascade, PHP array-key casting, XHR progress lifecycle,
matching algorithm) so regressions are caught without a WordPress install.

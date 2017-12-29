.SUFFIXES: .js .pegjs .css .html .smcat .svg .png .jpg
PEGJS=node_modules/pegjs/bin/pegjs
GIT=git
NPM=npm
MAKEDEPEND=node_modules/.bin/js-makedepend --output-to jsdependencies.mk --exclude "node_modules|docs"

GENERATED_SOURCES=src/parse/smcat-parser.js \
	src/render/dot.states.template.js \
	src/render/dot.template.js \
	src/render/smcat.template.js \
	src/render/HTMLTable.template.js \
	docs/index.html \
	docs/smcat-online-interpreter.min.js \
	docs/dev/index.html \
	docs/dev/smcat-online-interpreter.bundle.js \
	docs/dev/smcat-online-interpreter.bundle.js.map

# production rules
src/parse/%-parser.js: src/parse/peg/%-parser.pegjs
	$(PEGJS) --format umd -o $@ $<

src/render/%.template.js: src/render/%.template.hbs
	handlebars --commonjs handlebars/dist/handlebars.runtime -f $@ $<

docs/index.html: docs/index.hbs docs/smcat-online-interpreter.min.js
	node utl/cutHandlebarCookie.js docs/config/prod.json < $< > $@

docs/dev/index.html: docs/index.hbs docs/dev/smcat-online-interpreter.bundle.js
	node utl/cutHandlebarCookie.js docs/config/dev.json < $< > $@

docs/dev/smcat-online-interpreter.bundle.js: docs/smcat-online-interpreter.js src/index.js package.json
	webpack --env dev --progress

docs/smcat-online-interpreter.min.js: docs/smcat-online-interpreter.js src/index.js package.json
	webpack --env prod --progress

public:
	mkdir -p $@

public/%: docs/%
	cp $< $@

public/index.html: docs/index.html public public/smcat-online-interpreter.min.js

.npmignore: .gitignore
	cp $< $@
	echo "docs/**" >> $@
	echo "test/**" >> $@
	echo "utl/**" >> $@
	echo ".bithoundrc" >> $@
	echo ".eslintignore" >> $@
	echo ".eslintrc.json" >> $@
	echo ".gitlab-ci.yml" >> $@
	echo ".istanbul.yml" >> $@
	echo "Makefile" >> $@
	echo "jsdependencies.mk" >> $@
	echo "webpack.config.js" >> $@

# dependencies
include jsdependencies.mk

# executable targets
depend:
	$(MAKEDEPEND) --system cjs src
	$(MAKEDEPEND) --append --system cjs test
	$(MAKEDEPEND) --append --system cjs --flat-define ONLINE_INTERPRETER_SOURCES docs/smcat-online-interpreter.js

tag:
	$(GIT) tag -a `utl/getver` -m "tag release `utl/getver`"
	$(GIT) push --tags

clean:
	rm -rf $(GENERATED_SOURCES)
	rm -rf coverage
	rm -rf public

check: dev-build
	$(NPM) run lint
	$(NPM) run depcruise
	$(NPM) run nsp
	$(NPM) test
	$(NPM) outdated

lint-fix:
	$(NPM) run lint:fix

npminstall:
	$(NPM) install

install: npminstall dev-build dist

dev-build: src/index.js .npmignore docs/dev/index.html

dist: docs/index.html

pages: dist public/index.html

update-dependencies: run-update-dependencies clean dev-build check lint-fix
	$(GIT) diff package.json

run-update-dependencies:
	$(NPM) run npm-check-updates
	$(NPM) install

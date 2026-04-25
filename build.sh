#!/bin/sh
git clone https://gitlab.com/gbraad/document-generation-assets.git assets --depth 1
for f in done/[0-9]*.md; do pandoc -t html5 --template assets/templates/article-template.html --standalone $f -o ./public/${f/%.md}.html; done
for f in ./public/[0-9]*.html; do phantomjs ./assets/scripts/topdf.js $f ${f/%.html}.pdf 0.7; done
ls ./public/ | ./genindex.sh > ./index.md
pandoc -t html5 --template ./assets/templates/default-template.html --standalone -o ./public/index.html ./index.md


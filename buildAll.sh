#!/bin/sh
# Build script for MultiDuetWebMonitor
# The "buildAll" flavor produces a package suitable for a stand-alone web server, or file system. 
#
# licensed under the terms of the GNU Public License v3,
# derived from build.sh written by Christian Hammacher 2016-2017 for DWC
# rewritten for Multi Duet Web Control by Danal Estes (c) 2018
#
# The following tools are required:
# - yui-compressor from https://yui.github.io/yuicompressor
# - UglifyJS from https://github.com/mishoo/UglifyJS
# - gzip utility
# Make sure all tools are accessible via your PATH environment variable!

# Optional paths to the required tools
YUI_COMPRESSOR=yuicompressor
UGLIFYJS=uglifyjs
GZIP=gzip

# Check for required tools
if [[ ! $(type $YUI_COMPRESSOR 2>/dev/null) ]]; then
	echo "yui-compressor not found in PATH!"
	exit
fi

if [[ ! $(type $UGLIFYJS 2>/dev/null) ]]; then
	echo "uglifyjs not found in PATH!"
	exit
fi

if [[ ! $(type $GZIP 2>/dev/null) ]]; then
	echo "gzip not found in PATH!"
	exit
fi

# Core directory must contain Multi.htm
if [ ! -f "./core/Multi.htm" ] ; then
	echo "core directory doesn't contain Multi.htm"
	exit
fi

# Repository for DWC must be in directory at same level (parallel) to MultiDuetWebMonitor
if [ ! -f "../DuetWebControl/core/html404.htm" ] ; then
	echo "DWC repository must be in parallel directory.  Not Found."
	exit
fi
if [ ! -f "../DuetWebControl/core/js/notify.js" ] ; then
	echo "DWC repository must be in parallel directory.  Not Found."
	exit
fi

# Get the current version
VERSION=$(perl -nl0e 'print $1 if /MultiDWMC Web Interface Version.*(\d.\d\d).*/' ./core/Multi.htm | tr -d '\0')

# Create an empty build directory and clean up
if [  -d "./build" ] ; then
	rm -r ./build
fi
mkdir ./build
set -- MultiDuetWebControl-All*.zip
if [ -f "$1" ]; then
	rm -f ./MultiDuetWebControl-All*.zip
fi

echo "=> Building compressed Duet Multi Web Control v$VERSION bundle"

# Copy HTML files and change CSS and JS rels
echo "Changing CSS and JS paths in HTML files"
cp ../DuetWebControl/core/html404.htm ./build/html404.htm
cp ./core/Multi.htm ./build/Multi.htm
sed -i '' '/<link href/d' ./build/Multi.htm
sed -i '' '/<script src/d' ./build/Multi.htm
sed -i '' '/<!-- CSS/a\
<link href="css/dwc.css" rel="stylesheet">\' ./build/Multi.htm
sed -i '' '/<!-- Placed/a\
<script src="js/MultiDWMC.js"></script>\' ./build/Multi.htm


# Compress XML files
echo "Compressing XML files"
cp ../DuetWebControl/core/language.xml ./build/


# Minify and compress CSS files
echo "Minifying and compressing CSS files"
mkdir ./build/css
$YUI_COMPRESSOR -o ./build/css/slate.css ../DuetWebControl/core/css/slate.css
$YUI_COMPRESSOR -o ./build/css/bootstrap-theme.css ../DuetWebControl/core/css/bootstrap-theme.css
CSS_FILES=$(grep -e "\.css" ./core/Multi.htm | cut -d '"' -f 2 | sed -e 's/^/core\//')
for FILE in $CSS_FILES; do
	echo "- Minifying $FILE..."
	$YUI_COMPRESSOR $FILE >> ./build/css/dwc.css
done

# Concatenate JS files. They could be minified as well, but that would make debugging rather tricky
echo "Minifying and concatenating JS files"
mkdir ./build/js
echo "var dwcVersion = \"$VERSION\";" > ./build/js/MultiDWMC.js

JS_FILES=$(grep -e "\.js" ./core/Multi.htm | cut -d '"' -f 2 | sed -e 's/^/core\//' | tr '\n' ' ')
for FILE in $JS_FILES; do
	if [[ $FILE == "core/js/3rd-party/"* ]]; then
		echo "- Minifying $FILE..."
		cat $FILE | $UGLIFYJS -c -m --keep-fnames >> ./build/js/MultiDWMC.js
		#cat $FILE >> ./build/js/MultiDWMC.js
	else
		echo "- Appending $FILE..."
		cat $FILE >> ./build/js/MultiDWMC.js
	fi
done


# Compress font files
echo "Compressing fonts"
mkdir ./build/fonts
cat ../DuetWebControl/core/fonts/glyphicons-halflings-regular.eot   > ./build/fonts/glyphicons.eot
cat ../DuetWebControl/core/fonts/glyphicons-halflings-regular.svg   > ./build/fonts/glyphicons.svg
cat ../DuetWebControl/core/fonts/glyphicons-halflings-regular.ttf   > ./build/fonts/glyphicons.ttf
cat ../DuetWebControl/core/fonts/glyphicons-halflings-regular.woff  > ./build/fonts/glyphicons.woff
cat ../DuetWebControl/core/fonts/glyphicons-halflings-regular.woff2 > ./build/fonts/glyphicons.woff2
cat ../DuetWebControl/core/fonts/Homenaje-Regular.ttf               > ./build/fonts/Homenaje-Regular.ttf

# Now build MultiDuetWebControl-All
echo "=> Building final Duet Multi Web Control package"
cd ./build
zip -r -o ../MultiDuetWebControl-All-$VERSION.zip ./*
cd ..

# Clean up again
rm -r ./build
echo "Done"

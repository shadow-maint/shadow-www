#! /bin/sh
# vim: set noexpandtab tw=0:
# Rebuild the documentation and upload this to the web server.

set -e # we want to fail on any error instead of risking uploading broken stuff
#set -x

SHADOWSRC_TRUNK="../../trunk"

rm -rf htdocs.gen/

echo "Generate the web pages translations with po4a"
po4a -v --previous htdocs.cfg

find htdocs.gen -name "*.pl" |
while read f
do
	mv $f ${f%pl}po
done

for lang in $(grep po4a_langs htdocs.cfg | sed -e 's/\[po4a_langs\] //')
do
	for f in htdocs.gen/*.${lang/pl/po}
	do
		sed -i -e "s/\.en\"; ?>/\.${lang/pl/po}\"; ?>/" $f
	done
done

gen_translations() {
	dir="$1"

	total=$(LC_ALL=C msgfmt -o /dev/null --statistics "$dir"/*.pot 2>&1 | \
	        sed -ne "s/^.* \([0-9]*\) untranslated.*$/\1/p;d")

	echo "<table>"
	for pofile in "$dir"/*.po
	do
		lang=${pofile%.po}
		lang=$(basename $lang)
		stats=$(LC_ALL=C msgfmt -o /dev/null --statistics $pofile 2>&1)
		echo -n "<tr><td>$lang</td><td>"
		for type in translated fuzzy untranslated
		do
			strings=$(echo " $stats" | \
			          sed -ne "s/^.* \([0-9]*\) $type.*$/\1/p;d")
			if [ -n "$strings" ]
			then
				pcent=$((strings*100/total))
				width=$((strings*200/total))
				echo -n "<img height=\"10\" src=\"$type.png\" "
				echo -n "style=\"height: 1em;\" "
				echo -n "width=\"$width\" "
				echo -n "alt=\"$pcent% $type ($strings/$total), \" "
				echo -n "title=\"$type: $pcent% ($strings/$total)\"/>"
			fi
		done
		echo "</td></tr>"
	done
	echo "<? include \"table_translations_legend.php\";?>"
	echo "</table>"
	echo "<p>Last update: `LC_ALL=C date`.</p>"
}

echo Generate the translation statistics for bin
gen_translations $SHADOWSRC_TRUNK/po > htdocs.gen/table_translations_bin.php
echo Generate the translation statistics for doc
gen_translations $SHADOWSRC_TRUNK/man/po > htdocs.gen/table_translations_doc.php
echo Generate the translation statistics for htdocs
gen_translations po > htdocs.gen/table_translations_www.php

echo Extract the version
grep AM_INIT_AUTOMAKE $SHADOWSRC_TRUNK/configure.in | \
	sed -e 's/^.*,\s*\([^"]*\)).*/\1/' > htdocs.gen/version.php

get_language() {
# FIXME: use gettext
	case $1 in
		ca)
			echo -n "català"
			;;
		en)
			echo -n "English"
			;;
		es)
			echo -n "español"
			;;
		fr)
			echo -n "français"
			;;
		it)
			echo -n "Italiano"
			;;
		po)
			echo -n "polski"
			;;
		*)
			echo "Language '$1' not supported" >&2
			exit 1
			;;
	esac
}

gen_language_footer() {
	page="$1"
#	echo "Generating language footer for $page"
	page=${page%.en}
	page=${page#htdocs/}
	page=${page#htdocs.gen/}
	out=htdocs.gen/$(dirname $page)/footer_$(basename $page)
	echo "<div id=\"languages\">" > $out
	for langcode in $(ls htdocs/$page.* htdocs.gen/$page.* 2>/dev/null)
	do
		langcode=${langcode#htdocs/$page.}
		langcode=${langcode#htdocs.gen/$page.}
		language=$(get_language $langcode)
		echo "<a href=\"$(basename $page | sed -e 's/:/%3A/g').$langcode\">$language</a>" >> $out
	done
	echo "</div>" >> $out
#	echo "done"
}

echo "Generating language footers"
for page in htdocs/*.en
do
	gen_language_footer "$page"
done

find htdocs.gen -name "*.en" |
while read page
do
	gen_language_footer "$page"
done

echo Uploading...
scp -pr htdocs/*.* pkg-shadow.alioth.debian.org:/var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs
scp -pr htdocs/.htaccess pkg-shadow.alioth.debian.org:/var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs
scp -pr htdocs.gen/*.* pkg-shadow.alioth.debian.org:/var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs
#scp -pr coverage/* pkg-shadow.alioth.debian.org:/var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs/coverage
ssh pkg-shadow.alioth.debian.org chgrp -R pkg-shadow /var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs
ssh pkg-shadow.alioth.debian.org chmod -R g+rw /var/lib/gforge/chroot/home/groups/pkg-shadow/htdocs
echo done


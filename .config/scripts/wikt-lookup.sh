word=$(rofi -dmenu -p "Wiktionary" -theme-str 'window {width: 400px;} mainbox {children:["inputbar"]; padding: 15px;} inputbar {children:["prompt","entry"];}' -lines 0 2>/dev/null)

[ -z "$word" ] && exit 0

encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$word'))")
xdg-open "https://en.wiktionary.org/wiki/$encoded"

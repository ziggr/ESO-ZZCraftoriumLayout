.PHONY: put get data poll

put:
	cp -f ./ZZCraftoriumLayout.txt      /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/
	cp -f ./ZZCraftoriumLayout.lua      /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/
	cp -f ./ZZCraftoriumLayout_Data.lua /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZCraftoriumLayout.lua data/

getpts:
	cp -f /Volumes/Elder\ Scrolls\ Online/pts/SavedVariables/ZZCraftoriumLayout.lua data/


data: ZZCraftoriumLayout_Data.lua

poll: data

ZZCraftoriumLayout_Data.lua: ZZCraftoriumLayout_Parser.py furn.txt ZZCraftoriumLayout_Script.txt
	python3 ZZCraftoriumLayout_Parser.py furn.txt ZZCraftoriumLayout_Script.txt ZZCraftoriumLayout_Data.lua > log.txt

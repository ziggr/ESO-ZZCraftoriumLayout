.PHONY: send get csv

put:
	cp -f ./ZZCraftoriumLayout.lua /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZCraftoriumLayout.lua ../../SavedVariables/
	cp -f ../../SavedVariables/ZZCraftoriumLayout.lua data/


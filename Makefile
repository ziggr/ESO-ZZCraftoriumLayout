.PHONY: put get data poll

poll: data

# 1 get or getpts 	Copies SavedVariables from gaming rig.
get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZCraftoriumLayout.lua data/

getpts:
	cp -f /Volumes/Elder\ Scrolls\ Online/pts/SavedVariables/ZZCraftoriumLayout.lua data/

# 2 furn 	Extracts unique id and names from above
# 			SavedVariables and into furn.txt, which is
# 			the sorted list of stations that we eventually
# 			reposition. Order in this file controls order
#			within the house.
furn:
	lua gen_furn.lua > furn.txt

# 3 		hand-edit ZZCraftoriumLayout_Script.txt
# 			This file contains the Logo-like turtle movement
# 			that draws the lines of stations through the house.

# 4 data	Uses the above ZZCraftoriumLayout_Script.txt to generate
# 			actual xyz+rotate positions for items. Writes result
# 			to ZZCraftoriumLayout_Data.lua.

data: ZZCraftoriumLayout_Data.lua

ZZCraftoriumLayout_Data.lua: ZZCraftoriumLayout_Parser.py furn.txt ZZCraftoriumLayout_Script.txt
	python3 ZZCraftoriumLayout_Parser.py furn.txt ZZCraftoriumLayout_Script.txt ZZCraftoriumLayout_Data.lua > log.txt

# 5 put		Copy above ZZCraftoriumLayout_Data.lua input file to
#			gaming rig as source for this add-on.
put:
	cp -f ./ZZCraftoriumLayout.txt      /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/
	cp -f ./ZZCraftoriumLayout.lua      /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/
	cp -f ./ZZCraftoriumLayout_Data.lua /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZCraftoriumLayout/

# 6 /clayset
#			Use above ZZCraftoriumLayout_Data.lua to move everything.


# X 		An aborted attempt to lay out all stations in a
#			double-sided spiral in the Coldharbour Surreal Estate.
#		    Nobody likes the gloomy skies in that house, do not use.
spiral:
	lua Spiral.lua > ZZCraftoriumLayout_Data.lua



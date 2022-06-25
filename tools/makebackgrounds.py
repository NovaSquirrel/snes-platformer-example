#!/usr/bin/env python3
from nts2shared import *

# Globals
aliases = {}
background = None
all_backgrounds = []

# Read and process the file
with open("tools/backgrounds.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBackground():
	if background == None:
		return
	all_backgrounds.append(background)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new background
		saveBackground()
		# Reset to prepare for the new actor
		background = {"name": line[1:], "map": "", "size": "small"}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Attributes
	elif word in ["map", "size"]:
		background[word] = arg

# Save the last one
saveBackground()

#######################################

# Generate the output that's actually usable in the game
outfile = open("src/backgrounddata.s", "w")

outfile.write('; This is automatically generated. Edit "backgrounds.txt" instead\n')
outfile.write('.include "snes.inc"\n.include "global.inc"\n.include "graphicsenum.s"\n')

outfile.write('.export BackgroundMap, BackgroundFlags\n')

outfile.write('\n.segment "BackgroundData"\n\n')

outfile.write('.proc BackgroundMap\n  .byt 0\n')
for b in all_backgrounds:
	outfile.write('  .byt GraphicsUpload::Map%s ; %s\n' % (b["map"], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc BackgroundFlags\n  .byt 0\n')
for b in all_backgrounds:
	flags = 0
	if b['size'] == 'wide':
		flags = 1
	elif b['size'] == 'tall':
		flags = 2
	outfile.write('  .byt %d\n' % flags)
outfile.write('.endproc\n\n')

outfile.close()

# Generate the enum in a separate file
outfile = open("src/backgroundenum.s", "w")
outfile.write('; This is automatically generated. Edit "backgrounds.txt" instead\n')
outfile.write('.enum LevelBackground\n  Empty\n')
for b in all_backgrounds:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.close()

#!/usr/bin/env python3
# Helper functions
from nts2shared import *

# Globals
aliases = {}
actor = None
all_actors = []
all_particles = []
all_owdecorations = []
all_subroutines = []

# Read and process the file
with open("tools/actors.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveActor():
	if actor == None:
		return
	# Put it in the appropriate list
	if actor["particle"]:
		all_particles.append(actor)
	elif actor["owdecoration"]:
		all_owdecorations.append(actor)
	else:
		all_actors.append(actor)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new actor
		saveActor()
		# Reset to prepare for the new actor
		actor = {"name": line[1:], "particle": False, "owdecoration": False, "size": [16, 16],
			"run": "ActorNothing", "draw": "ActorNothing", "flags": [],
			"essential": False, "secondary": False}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Attributes
	elif word == "size":
		actor["size"] = arg.split("x")
	elif word == "flag":
		actor["flags"] = arg.split()
	elif word in ["run", "draw"]:
		actor[word] = arg
		all_subroutines.append(arg)
	elif word in ["particle"]:
		actor[word] = True

# Save the last one
saveActor()

#######################################

# Generate the output that's actually usable in the game
outfile = open("src/actordata.s", "w")

outfile.write('; This is automatically generated. Edit "actors.txt" instead\n')
outfile.write('.include "snes.inc"\n.include "global.inc"\n.include "graphicsenum.s"\n.include "paletteenum.s"\n')

outfile.write('.export ActorBank, ActorRun, ActorDraw, ActorWidthTable, ActorHeightTable\n')
outfile.write('.export ParticleRun, ParticleDraw\n')

outfile.write('.import %s\n' % str(", ".join(all_subroutines)))
outfile.write('\n.segment "ActorData"\n\n')

# no-operation routine
outfile.write(".pushseg\n.segment \"C_ActorCommon\"\n.proc ActorNothing\n  rtl\n.endproc\n.popseg\n\n")

# Actors
outfile.write('.proc ActorDraw\n  .addr .loword(ActorNothing)\n')
for b in all_actors:
	outfile.write('  .addr .loword(%s)\n' % b["draw"])
outfile.write('.endproc\n\n')

outfile.write('.proc ActorRun\n  .addr .loword(ActorNothing)\n')
for b in all_actors:
	outfile.write('  .addr .loword(%s)\n' % b["run"])
outfile.write('.endproc\n\n')

outfile.write('.proc ActorBank\n  .byt ^ActorNothing, ^ActorNothing\n')
for b in all_actors:
	outfile.write('  .byt ^%s, ^%s\n' % (b["run"], b["draw"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ActorWidthTable\n  .word 0\n')
for b in all_actors:
	outfile.write('  .word %s<<4 ; %s\n' % (b["size"][0], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ActorHeightTable\n  .word 0\n')
for b in all_actors:
	outfile.write('  .word %s<<4 ; %s\n' % (b["size"][1], b["name"]))
outfile.write('.endproc\n\n')

# Particles
outfile.write('.segment "C_ParticleCode"\n')
outfile.write(".proc ParticleNothing\n  rts\n.endproc\n\n")

outfile.write('.proc ParticleDraw\n  .addr .loword(ParticleNothing-1)\n')
for b in all_particles:
	outfile.write('  .addr .loword(%s-1)\n' % b["draw"])
outfile.write('.endproc\n\n')

outfile.write('.proc ParticleRun\n  .addr .loword(ParticleNothing-1)\n')
for b in all_particles:
	outfile.write('  .addr .loword(%s-1)\n' % b["run"])
outfile.write('.endproc\n\n')

# Shared routine table
outfile.write('.segment "C_ActorCommon"\n')
outfile.write('.proc SharedNone\n  rts\n.endproc\n')


outfile.close()

# Generate the enum in a separate file
outfile = open("src/actorenum.s", "w")
outfile.write('; This is automatically generated. Edit "actors.txt" instead\n')
outfile.write('.enum Actor\n  Empty\n')
for b in all_actors:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.write('.enum Particle\n  Empty\n')
for b in all_particles:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.close()

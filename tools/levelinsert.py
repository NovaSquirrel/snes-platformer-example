#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import glob, os
from readtiled import *

outfile = open("src/leveldata.s", "w")
outfile.write('; This is automatically generated. Edit the files in the levels directory instead.\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "actorenum.s"\n')
outfile.write('.segment "LevelData"\n\n')

for f in sorted(glob.glob("levels/*.tmx")):
	plain_name = os.path.splitext(os.path.basename(f))[0]
	compressed_name = os.path.splitext(f)[0]+'.lz4'

	map = TiledMap(f)
	print(map.map_width)
	print(map.map_height)
	print(map.name)
	print(map.bgcolor)

	outfile.write('.export level_%s\n' % plain_name)
	outfile.write('level_%s:\n' % plain_name)

	# Write the level data
	outfile.write('  .byt 0 ; Music\n')
	outfile.write('  .byt %d, %d ; X and Y\n' % (map.start_x, map.start_y))
	outfile.write('  .byt 0 ; Flags\n')
	outfile.write('  .word RGB8(%d,%d,%d)\n' % (map.bgcolor[0], map.bgcolor[1], map.bgcolor[2]))
	outfile.write('  .word .loword(level_%s_sp)\n' % plain_name)
	outfile.write('  .word .loword(level_%s_fg)\n' % plain_name)
	outfile.write('level_%s_fg:\n' % plain_name)
	outfile.write('  .incbin "../%s"\n' % compressed_name.replace('\\', '/'))
	outfile.write('level_%s_sp:\n' % plain_name)

	actor_tilesets = {}
	for actor in sorted(map.actor_list, key=lambda r: r[1]):
		actor_tile, actor_x, actor_y, actor_xflip, actor_yflip = actor
		tileset_name, tileset_offset = actor_tile

		# Load if the tileset isn't realdy loaded
		if tileset_name not in actor_tilesets:
			actor_tilesets[tileset_name] = TiledMapTileset(os.path.dirname(f) + '/' + tileset_name)
		tileset_data = actor_tilesets[tileset_name].tiles[tileset_offset]

		outfile.write("  .byt %d, %d|%d, Actor::%s, 0\n" % (actor_x, (128 if actor_xflip else 0), actor_y, tileset_data['Name']))

	outfile.write('  .byt 255\n')

	outfile.write('\n')
outfile.close()

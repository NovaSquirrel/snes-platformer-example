#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import PIL, os, glob
from PIL import Image

def tilestring_hflip(ts):
	out = []
	for i in range(64):
		out.append(ts[i^7])
	return ''.join(out)

def tilestring_vflip(ts):
	out = []
	for i in range(64):
		out.append(ts[i^(7*8)])
	return ''.join(out)

def tilestring_bytes(ts):
	# First get the data for each plane
	plane_data = []
	for plane in range(4):
		p = []
		for row in range(8):
			rowbyte = 0
			for column in range(8):
				# Get the actual binary value
				nybble = int(ts[row*8+column],16)
				# Extract the desired bit from it
				if nybble & (1 << plane):
					rowbyte |= 1 << (7-column)
			p.append(rowbyte)
		plane_data.append(p)

	# Interleave the planes together
	a,b = [], []
	for i in range(8):
		a.append(plane_data[0][i])
		a.append(plane_data[1][i])
		b.append(plane_data[2][i])
		b.append(plane_data[3][i])
	return a+b

class TiledMap():
	# name
	# map_width
	# map_height
	# map_data
	# actor_list
	# bgcolor

	# map_tiles_used
	# map_tilesets_used
	def __init__(self, filename):
		print("Parsing %s" % filename)

		tree = ET.parse(filename)
		root = tree.getroot()

		map_width  = int(root.attrib['width'])
		map_height = int(root.attrib['height'])
		self.map_width = map_width
		self.map_height = map_height
		self.name = os.path.splitext(os.path.basename(filename))[0]

		if 'backgroundcolor' in root.attrib:
			bgcolor = root.attrib['backgroundcolor'][1:]
			self.bgcolor = (int(bgcolor[0:2], 16), int(bgcolor[2:4], 16), int(bgcolor[4:6], 16))
		else:
			self.bgcolor = (255, 255, 255)

		self.map_tiles_used = set()
		self.map_tilesets_used = set()

		# Lists to store the read map data
		map_data   = []
		actor_list = []

		# Keep track of the mapping between the tile numbers and different tilesets
		tileset_first = []
		tileset_data  = []

		# Find what tileset a tile belongs to, and the offset within it
		def identify_gid(tilenum):
			if tilenum > 0:
				for i in range(len(tileset_first)):
					if tilenum >= tileset_first[i]:
						within = tilenum-tileset_first[i]
						data = (tileset_data[i], within)
						self.map_tiles_used.add(data)
						self.map_tilesets_used.add(tileset_data[i])
						return data
			return None

		# Parse the map file
		for e in root:
			if e.tag == 'tileset':
				# Keep track of what tile numbers belong to what tile sheets
				tileset_first.insert(0, int(e.attrib['firstgid']))
				tileset_data.insert(0, e.attrib['source'])
			elif e.tag == 'layer':
				# Parse tile layers
				map_out = map_data

				for d in e: # Go through the layer's data
					if d.tag == 'properties':
						for p in d:
							pass
							# p.attrib['name']
					elif d.tag == 'data':
						assert d.attrib['encoding'] == 'csv'
						for line in [x for x in d.text.splitlines() if len(x)]:
							row = []
							for t in line.split(','):
								if not len(t):
									continue
								row.append(identify_gid(int(t)))
							map_out.append(row)
			elif e.tag == 'objectgroup':
				if e.attrib['name'].lower() == 'actors':
					for sprite in e:
						assert sprite.tag == 'object'
						gid = int(sprite.attrib['gid'])
						xflip = (gid & 0x80000000) != 0
						yflip = (gid & 0x40000000) != 0
						gid   =  gid & 0x0fffffff
						width   = int(sprite.attrib['width'])
						height  = int(sprite.attrib['height'])
						tile    = identify_gid(gid)
						data = (tile, int(sprite.attrib['x'])//16, int(sprite.attrib['y'])//16, xflip, yflip)
						actor_list.append(data)
				elif e.attrib['name'].lower() == 'meta':
					for cmd in e:
						assert cmd.tag == 'object'
						x = int(cmd.attrib['x'])//16
						y = int(cmd.attrib['y'])//16
						name = cmd.attrib['name']
						if name.lower() == 'playerstart':
							self.start_x, self.start_y = x, y
				else:
					print("Unknown object group named %s" % e.attrib['name'])

		self.map_data = map_data
		self.actor_list = actor_list

class TiledMapTileset():
	# tiles
	# columns
	# image

	def __init__(self, filename):
		print("Parsing %s" % filename)

		tree = ET.parse(filename)
		root = tree.getroot()

		self.tiles = {}
		self.columns = int(root.attrib['columns'])

		for e in root:
			if e.tag == 'image':
				self.image = e.attrib['source']
			elif e.tag == 'tile':
				id = int(e.attrib['id'])
				if len(e) == 0:
					continue
				assert e[0].tag == 'properties'

				tile_properties = {}
				for p in e[0]:
					assert p.tag == 'property'
					name = p.attrib['name']
					type = 'string'
					if 'type' in p.attrib:
						type = p.attrib['type']
					value = p.attrib['value']
					if type == 'bool':
						tile_properties[name] = value == 'true'
					elif type == 'string' and value != '':
						tile_properties[name] = value
				self.tiles[id] = tile_properties

class TiledMapSet():
	# maps					list of maps
	# map_palettes			up to eight background palettes
	# map_chr				list of background tiles (32 ints in a list together) in SNES format
	# blocks				list of map blocks and their metadata

	# map_tiles_used		list of tiles used in (tileset.tsx, index within) format
	# map_tilesets_used		list of tilesets used

	def __init__(self, base, files):
		self.map_tiles_used = set()
		self.map_tilesets_used = set()
		self.maps = []			# Every map in order
		tilesets = {}			# Information about each tileset, pre-parsed
		self.map_palettes = []

		# Parse each map
		for f in files:
			map = TiledMap(base+f)
			self.maps.append(map)
			# Keep track of what tiles and tilesets are used across all of the maps
			self.map_tiles_used = self.map_tiles_used.union(map.map_tiles_used)
			self.map_tilesets_used = self.map_tilesets_used.union(map.map_tilesets_used)

		# Build up the actual set of used tiles
		# and open the source images
		images = {}
		palette_for_tileset = {}
		for f in self.map_tilesets_used:
			tilesets[f] = TiledMapTileset(base+f)
			images[f] = Image.open(base+tilesets[f].image)

			# Extract the palette
			pal = images[f].getpalette()[3:]
			triplets = []
			for i in range(15):
				r = pal.pop(0)
				g = pal.pop(0)
				b = pal.pop(0)
				triplets.append((r,g,b))

			# Find the palette (or add it if it hasn't been used yet)
			if triplets not in self.map_palettes:
				self.map_palettes.append(triplets)
				assert len(self.map_palettes) <= 8
				palette_for_tileset[f] = len(self.map_palettes) - 1
			else:
				palette_for_tileset[f] = self.map_palettes.index(triplets)

		# Get all of the palettes and pixel data
		self.map_chr = [tilestring_bytes('0'*64)]
		self.blocks = {}
		tilestrings = ['0'*64]
		for tileset, within in self.map_tiles_used:
			block = {'palette': palette_for_tileset[tileset],
					 'chr': [[None, None],[None, None]],
					 'xflip': [[False, False], [False, False]],
					 'yflip': [[False, False], [False, False]],
					 'data': None}
			if within in tilesets[tileset].tiles:
				block['data'] = tilesets[tileset].tiles[within]
			im = images[tileset]

			base_x = (within % tilesets[tileset].columns) * 16
			base_y = (within // tilesets[tileset].columns) * 16
			for th in range(2):
				for tw in range(2):
					imtile = im.crop((base_x+tw*8, base_y+th*8, base_x+tw*8+8, base_y+th*8+8))
					tilestring = ''.join(['%x' % p for p in imtile.getdata()])

					# Is this a preexisting tile?
					chr, xflip, yflip = None, False, False
					hflip = tilestring_hflip(tilestring)
					vflip = tilestring_vflip(tilestring)
					hvflip = tilestring_hflip(tilestring_vflip(tilestring))
					if tilestring in tilestrings:
						chr = tilestrings.index(tilestring)
					elif hflip in tilestrings:
						chr = tilestrings.index(hflip)
						xflip = True
					elif vflip in tilestrings:
						chr = tilestrings.index(vflip)
						yflip = True
					elif hvflip in tilestrings:
						chr = tilestrings.index(hvflip)
						xflip = True
						yflip = True
					else:
						chr = len(tilestrings)
						tilestrings.append(tilestring)
						self.map_chr.append(tilestring_bytes(tilestring))

					block['chr'][th][tw] = chr
					block['xflip'][th][tw] = xflip
					block['yflip'][th][tw] = yflip
			self.blocks[(tileset, within)] = block

		# Close the images again
		for i in images:
			images[i].close()

class AnimationSheet():
	# columns		columns 
	# tiles			dict with the name of each animation as the keys
	# tilewidth		width of each tile
	# tileheight	height of each tile
	# image			source image used

	def __init__(self, filename):
		print("Parsing %s" % filename)

		tree = ET.parse(filename)
		root = tree.getroot()

		self.tiles = {}
		self.columns = int(root.attrib['columns'])
		self.tilewidth = int(root.attrib['tilewidth'])
		self.tileheight = int(root.attrib['tileheight'])

		for e in root:
			if e.tag == 'image':
				self.image = e.attrib['source']
			elif e.tag == 'tile':
				tile_properties = {'id': int(e.attrib['id'])}
				tile_name = None

				for metadata in e:
					if metadata.tag == 'properties':
						for p in e[0]:
							assert p.tag == 'property'

							# Don't put the name in the properties dict
							name = p.attrib['name']
							if name == 'name':
								tile_name = p.attrib['value']
								continue

							# But other properties can go in there
							type = 'string'
							if 'type' in p.attrib:
								type = p.attrib['type']
							value = p.attrib['value']
							if type == 'bool':
								tile_properties[name] = value == 'true'
							elif type == 'string':
								tile_properties[name] = value
					elif metadata.tag == 'animation':
						assert metadata[0].tag == 'frame'
						frames = []
						for frame in metadata:
							tileid = int(frame.attrib['tileid'])
							duration = int(frame.attrib['duration'])
							frames.append((tileid, duration))
						tile_properties['frames'] = frames
				# Use the name as the key
				if tile_name:
					self.tiles[tile_name] = tile_properties
	
class AnimationSet():
	# sheets			all of the animation sheets
	# sheet_for_name	the sheet for a given animation name
	# chr8				list of tiles as bytes
	# chr16				list of (tile, tile, tile tile) as bytes
	# palettes			up to 8 sprite palettes
	# animations		dict of animation names and information

	def __init__(self, base, used_animations):
		self.sheets = []
		self.sheet_for_name = {}
		self.palettes = []
		self.animations = {}

		# Track the opened images
		images = []
		image_for_name = {}
		palette_for_name = {}

		# Read all of the tilesets and open their images
		for filename in glob.glob(base+"actor/*.tsx"):
			sheet = AnimationSheet(filename)
			self.sheets.append(sheet)
			image = Image.open(base+"actor/"+sheet.image)

			# Extract the palette
			pal = image.getpalette()[3:]
			triplets = []
			for i in range(15):
				r = pal.pop(0)
				g = pal.pop(0)
				b = pal.pop(0)
				triplets.append((r,g,b))

			# Find the palette (or add it if it hasn't been used yet)
			this_palette = None
			if triplets not in self.palettes:
				self.palettes.append(triplets)
				assert len(self.palettes) <= 8
				this_palette = len(self.palettes) - 1
			else:
				this_palette = self.palettes.index(triplets)

			# Mark off the sheets, images and palettes for each animation name
			for tile in sheet.tiles:
				assert tile not in self.sheet_for_name
				self.sheet_for_name[tile] = sheet
				image_for_name[tile] = image
				palette_for_name[tile] = this_palette

		# Tiles
		self.chr8 = []
		self.chr16 = []
		tilestrings8 = []
		tilestrings16 = []

		# Only include the used animations
		for anim in used_animations:
			# Output with the animation information
			out = {'size': sheet.tilewidth, 'palette': palette_for_name[anim]}

			sheet = self.sheet_for_name[anim]
			assert sheet.tilewidth == sheet.tileheight
			info = sheet.tiles[anim]
			image = image_for_name[anim]

			# --------------------------------------------------------------

			out_frames = []
			for within in [info['id']]:
				base_x = (within % sheet.columns) * sheet.tilewidth
				base_y = (within // sheet.columns) * sheet.tileheight

				# Get the tiles
				if sheet.tilewidth == 8:
					imtile = image.crop((base_x, base_y, base_x+8, base_y+8))
					tilestring = ''.join(['%x' % p for p in imtile.getdata()])

					if tilestring in tilestrings8:
						out_frames.append(tilestrings8.index(tilestring))
					else:
						out_frames.append(len(tilestrings))
						tilestrings8.append(tilestring)
						self.chr8.append(tilestring_bytes(tilestring))

				elif sheet.tilewidth == 16:
					imtile1 = image.crop((base_x,   base_y,   base_x+8,   base_y+8))
					imtile2 = image.crop((base_x+8, base_y,   base_x+8+8, base_y+8))
					imtile3 = image.crop((base_x,   base_y+8, base_x+8,   base_y+8+8))
					imtile4 = image.crop((base_x+8, base_y+8, base_x+8+8, base_y+8+8))
					tilestring1 = ''.join(['%x' % p for p in imtile1.getdata()])
					tilestring2 = ''.join(['%x' % p for p in imtile2.getdata()])
					tilestring3 = ''.join(['%x' % p for p in imtile3.getdata()])
					tilestring4 = ''.join(['%x' % p for p in imtile4.getdata()])
					quad = (tilestring1, tilestring2, tilestring3, tilestring4)

					if quad in tilestrings16:
						out_frames.append(tilestrings16.index(tilestring))
					else:
						out_frames.append(len(tilestrings16))
						tilestrings16.append(quad)
						self.chr16.append([tilestring_bytes(x) for x in quad])

				else:
					print("Bad tile size %d" % sheet.tilewidth)
			out['frames'] = out_frames
			self.animations[anim] = out

		# Close the images again
		for i in images:
			i.close()

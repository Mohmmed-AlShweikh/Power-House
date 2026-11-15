#!/usr/bin/env python3
"""Render approved SVG splash assets and a 2/3-circle crop proof.

Build-time tooling only; requires Pillow and CairoSVG, no app dependencies.
SVG luminance masks are applied explicitly to preserve approved negative space.
"""
from pathlib import Path
from io import BytesIO
from copy import deepcopy
import xml.etree.ElementTree as ET
import json,math
import cairosvg
from PIL import Image,ImageChops,ImageDraw
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'assets/brand/approved-a';OUT=ROOT/'docs/validation'
NS='{http://www.w3.org/2000/svg}'
def render(nodes):
 root=ET.Element(NS+'svg',{'width':'96','height':'96','viewBox':'0 0 96 96'})
 for node in nodes: root.append(node)
 return Image.open(BytesIO(cairosvg.svg2png(bytestring=ET.tostring(root),output_width=1536,output_height=1536))).convert('RGBA')
def mark(name):
 root=ET.parse(ART/name).getroot();result=Image.new('RGBA',(1536,1536))
 for node in root:
  mask=node.get('mask')
  if not mask:continue
  node=deepcopy(node);del node.attrib['mask'];layer=render([node])
  mask_id=mask[5:-1]
  source=root.find(f".//{NS}mask[@id='{mask_id}']")
  holes=[]
  for path in source.findall(NS+'path'):
   path=deepcopy(path);path.set('fill','white');holes.append(path)
  hole_image=render(holes)
  layer.putalpha(ImageChops.subtract(layer.getchannel('A'),hole_image.getchannel('A')))
  result.alpha_composite(layer)
 return result
def canvas(art,size,width,offset_y=0):
 art=art.resize((width,round(width*art.height/art.width)),Image.Resampling.LANCZOS)
 im=Image.new('RGBA',(size,size));im.alpha_composite(art,((size-art.width)//2,(size-art.height)//2+offset_y));return im
size=1152;radius=size/3
records=[];panels=[]
for mode,source,bg in [('light','mark-white.svg','#14756B'),('dark','mark-reversed.svg','#13262A')]:
 im=canvas(mark(source),size,648,-24)
 a=im.getchannel('A');coords=[(i%size+.5-size/2,i//size+.5-size/2) for i,v in enumerate(a.tobytes()) if v]
 max_r=max(math.hypot(x,y) for x,y in coords)
 assert max_r<radius,(mode,max_r)
 path=ART/f'splash-android12-{mode}-1152.png';im.save(path)
 mask=Image.new('L',(size,size));ImageDraw.Draw(mask).ellipse((192,192,959,959),fill=255)
 masked=im.copy();masked.putalpha(ImageChops.multiply(a,mask))
 assert ImageChops.difference(a,masked.getchannel('A')).getbbox() is None
 panel=Image.new('RGBA',(size,size),bg);panel.alpha_composite(masked)
 ImageDraw.Draw(panel).ellipse((192,192,959,959),outline='#8AD8C7',width=3)
 panels.append(panel)
 records.append({'mode':mode,'canvas':[size,size],'mark_alpha_bounds':list(im.getbbox()),'mark_design_box_width_fraction':648/size,'safe_circle_diameter':768,'maximum_opaque_radius':max_r,'safe_circle_radius':radius,'cropped_alpha_pixels':0,'background':bg})
for mode,source in [('light','mark-primary.svg'),('dark','mark-reversed.svg')]:
 canvas(mark(source),768,384).save(ART/f'splash-legacy-{mode}-768.png')
proof=Image.new('RGB',(2304,1152));proof.paste(panels[0].convert('RGB'),(0,0));proof.paste(panels[1].convert('RGB'),(1152,0));proof.save(OUT/'splash-mask.png')
(OUT/'splash-mask.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))

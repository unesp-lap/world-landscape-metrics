# Neo Jaguar Database - WGS84

# os.chdir(r'H:\_neojaguardatabase\Envdatabase\30m\Neotropic\Water frequency\2010')
# grass.run_command('r.import', input = 'p001r050_WF_2010.tif', output = 'p001r050_WF_2010')
python

# Load modules
import os
import subprocess
import grass.script as grass
from grass.pygrass.modules.shortcuts import general as g
from grass.pygrass.modules.shortcuts import vector as v
from grass.pygrass.modules.shortcuts import raster as r

# 1. Outros Hansens
# 1.2 Treecover loss Hansen 2001-2017 - 30m
folder_path = r'F:\_neojaguardatabase\Envdatabase\30m\Neotropic\Hansen_treecoverlossperyear_2017'
os.chdir(folder_path) # Change to this folder

ff = os.listdir('.')

for i in ff:
    if i.startswith('Hansen'):
        print i
        name = i.replace('.tif', '')
        try:
            grass.run_command('r.in.gdal', input = i, output = i, overwrite = True)

grass.run_command('r.import', input = 'Neotropical_Hansen_treecoverlossperyear_wgs84_2017.tif', 
	output = 'Neotropical_Hansen_treecoverlossperyear_wgs84_2017', overwrite = True)


# 2. Water Frequency 2000 - 30m

# Import map
folder_path = r'F:\_neojaguardatabase\Envdatabase\30m\Neotropic\Water frequency\2010'
os.chdir(folder_path) # Change to this folder
files = os.listdir(folder_path) # List files in the folder
for i in files:
    if i[-3:] == 'tif': # Select tif files
        print i
        name = i.replace('.tif', '_rast')  
        grass.run_command('r.import', input = i, output = name, overwrite = True) # Import maps

# Mosaic of water frequency maps

# List of maps
maps_water = grass.list_grouped('rast', pattern = 'p*2010_rast')['PERMANENT']

# Region of study
grass.run_command('g.region', rast = map_for_define_region, flags = 'ap')

# Combine maps
water_map_mosaic = 'water_frequency_2010_30m_tif_exp'
grass.run_command('r.patch', input = maps_water, output = water_map_mosaic, overwrite = True)

# Delete input maps
grass.run_command('g.remove', type = 'raster', pattern = 'p*2010_rast', flags = 'f')

# transformar em 1/0 e 1/null


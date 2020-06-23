#' ---
#' title: landscape metrics
#' author: mauricio vancine
#' date: 2020-06-23
#' ---

# prepare r -------------------------------------------------------------
# memory
rm(list = ls())

# packages
library(raster)
library(sf)
library(rgdal)
library(landscapemetrics)
library(landscapetools)
library(tidyverse)
library(tmap)

# directory
path <- "/home/mude/data/onedrive/manuscritos/03_preparacao/lucas/02_data"
setwd(path)
dir()

# import data -------------------------------------------------------------
# raster
ra <- raster::raster("flo.tif") > .9
ra

# map
tm_shape(ra) +
  tm_raster()

# import points
po <- sf::st_read("amostra_pontos_neotropicos.shp", quiet = TRUE)
po

tm_shape(po) +
  tm_bubbles()

# import utm grids
utm <- sf::st_read("utm_zones_final.shp") %>% 
  dplyr::rename(id = CATID, 
                lon = LON, 
                lat = LAT,
                code = CODE) %>% 
  dplyr::mutate(zone = stringr::str_extract(code, "[0-9]+"),
                prj4 = dplyr::if_else(lat < 0, 
                                      paste0("+proj=utm +zone=", zone, " +south +datum=WGS84 +units=m +no_defs +type=crs"),
                                      paste0("+proj=utm +zone=", zone, " +datum=WGS84 +units=m +no_defs +type=crs")))
utm

tm_shape(utm) +
  tm_polygons()

# epsg
epsg <- rgdal::make_EPSG() %>% 
  tibble::as_tibble() %>% 
  dplyr::rename(epsg_code = code) %>% 
  dplyr::filter(str_detect(note, "WGS 84 / UTM zone"))
epsg

# join
utm_epsg <- utm %>% 
  dplyr::left_join(epsg, by = "prj4")
utm_epsg  

# export
sf::st_write(utm_epsg, "utm_zones_final_epsg.shp", append = FALSE)

# metrics -----------------------------------------------------------------
# metrics
metrics <- NULL

# for
for(i in 1:nrow(po)){

  # info
  print(i)
  
  # filter
  po_i <- po %>% 
    dplyr::slice(i) %>% 
    sf::st_join(utm_epsg)
    
  # transform and buffer
  po_i_tb <- sf::st_transform(po_i, crs = po_i$epsg_code) %>% 
    sf::st_buffer(dist = 1000)
  
  # crop and mask
  ra_i <- ra %>%
    raster::projectRaster(crs = po_i$prj4) %>% 
    raster::crop(po_i_tb) %>% 
    raster::mask(po_i_tb)
  
  # 1. percentage of landscape
  pl <- landscapemetrics::lsm_c_pland(ra_i)

  # 2. patch density
  pd <-  landscapemetrics::lsm_c_pd(ra_i)
  
  # 3. edge density
  ed <- landscapemetrics::lsm_c_ed(ra_i)
  
  # 4. splitting index
  si <- landscapemetrics::lsm_c_split(ra_i)
  
  # combine
  metrics <- dplyr::bind_rows(pl, pd, ed, si) %>%
    dplyr::mutate(id = i) %>% 
    dplyr::select(id, class, metric, value) %>% 
    dplyr::bind_rows(metrics)
  
}

# end ---------------------------------------------------------------------
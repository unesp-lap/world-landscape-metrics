#' ---
#' title: landscape metrics
#' author: mauricio vancine
#' date: 2020-06-24
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
path <- "/home/mude/data/github/world-landscape-metrics"
setwd(path)
dir()

# import data -------------------------------------------------------------
# raster
ra <- raster::raster("01_data/flo.tif") > .9
ra

# map
plot(ra)

# import points
po <- sf::st_read("01_data/amostra_pontos_neotropicos.shp", quiet = TRUE)
po

tm_shape(po) +
  tm_bubbles()

# import utm grids
utm_epsg <- sf::st_read("01_data/utm_zones_epsg.shp")
utm_epsg

tm_shape(utm_epsg) +
  tm_polygons() +
  tm_text("zone", size = .7)

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
    
  for(j in seq(100, 2800, 300)){
  
    # info
    print(paste0("Buffer ", j, " m"))
    
    # transform and buffer
    po_i_tb <- sf::st_transform(po_i, crs = po_i$epsg_code) %>% 
    sf::st_buffer(dist = j)
  
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
    dplyr::mutate(id = i, buffer = j) %>% 
    dplyr::select(id, buffer, class, metric, value) %>% 
    dplyr::bind_rows(metrics)

    }

}

# end ---------------------------------------------------------------------
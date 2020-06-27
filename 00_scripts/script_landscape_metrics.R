#' ---
#' title: landscape metrics
#' author: mauricio vancine
#' date: 2020-06-27
#' ---

# prepare r -------------------------------------------------------------
# memory
rm(list = ls())

# packages
library(raster)
library(sf)
library(rgdal)
library(rnaturalearth)
library(landscapemetrics)
library(landscapetools)
library(tidyverse)
library(tmap)

# raster options
raster::rasterOptions(maxmemory = 1e+200, chunksize = 1e+200)
raster::beginCluster(n = parallel::detectCores() - 1)

# directory
setwd("/home/mude/data/github/world-landscape-metrics/01_data")

# import data -------------------------------------------------------------
# limits
li <- rnaturalearth::countries110 %>% 
  sf::st_as_sf()
li

# directory
setwd("forest_maps_cut_by_buffer")

# list files
fi <- dir(pattern = "deforestation_threshold70_binary_cgs_wgs84.tif")
fi

# landscapes
la <- purrr::map(fi, raster::brick)
la

# map
plot(la[[1]])

# import points
setwd("..")
po <- sf::st_read("community_locations/comm_data_neotro_checked_2020_d11_06.shp", quiet = TRUE)
po

tm_shape(li, bbox = po) +
  tm_polygons() +
  tm_shape(po) +
  tm_bubbles(size = .1, col = "red")

# import utm grids
utm_epsg <- sf::st_read("other_vector_data/utm_zones_epsg.shp")
utm_epsg

tm_shape(li, bbox = po) +
  tm_polygons() +
  tm_shape(utm_epsg, bbox = po) +
  tm_borders() +
  tm_text("zone", size = .5) +
  tm_shape(po) +
  tm_bubbles(size = .1, col = "red")

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
  
  # project landscape
  la_i <- la[[i]] %>%
    raster::projectRaster(crs = po_i$prj4, res = 30)
  
  for(j in seq(100, 2800, 300)){
    
    # info
    print(paste0("Buffer ", j, " m"))
    
    # transform and buffer
    po_i_j <- po_i %>% 
      sf::st_transform(crs = po_i$epsg_code) %>% 
      sf::st_buffer(dist = j)
    
    # crop and mask
    la_i_j <- la_i %>%
      raster::crop(po_i_j) %>% 
      raster::mask(po_i_j)
    
    # 1. percentage of landscape
    pl <- landscapemetrics::lsm_c_pland(la_i_j)
    
    # 2. patch density
    pd <-  landscapemetrics::lsm_c_pd(la_i_j)
    
    # 3. edge density
    ed <- landscapemetrics::lsm_l_ed(la_i_j)
    
    # 4. splitting index
    si <- landscapemetrics::lsm_c_split(la_i_j)
    
    # combine
    metrics <- dplyr::bind_rows(pl, pd, ed, si) %>%
      dplyr::mutate(id = i, buffer = j) %>% 
      dplyr::select(id, buffer, class, metric, value) %>% 
      dplyr::bind_rows(metrics)
    
  }
  
}

# export
dir.create("02_metrics")

readr::write_csv(metrics, "metrics.csv")

# end ---------------------------------------------------------------------
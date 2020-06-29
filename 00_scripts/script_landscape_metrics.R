#' ---
#' title: landscape metrics
#' author: mauricio vancine
#' date: 2020-06-29
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
raster::beginCluster(n = parallel::detectCores() - 6)

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
  tm_bubbles(size = .1, col = "red") +
  tm_graticules(lines = FALSE) +
  tm_compass(position = c("left", "bottom")) +
  tm_scale_bar(position = c("left", "bottom"))

# import utm grids
utm_epsg <- sf::st_read("other_vector_data/utm_zones_epsg.shp")
utm_epsg

tm_shape(li, bbox = po) +
  tm_polygons() +
  tm_shape(utm_epsg, bbox = po) +
  tm_borders() +
  tm_text("zone", size = .7, col = "blue") +
  tm_shape(po) +
  tm_bubbles(size = .1, col = "red") +
  tm_graticules(lines = FALSE) +
  tm_compass(position = c("left", "bottom")) +
  tm_scale_bar(position = c("left", "bottom"))

# metrics -----------------------------------------------------------------
# directory
setwd(".."); dir.create("02_metrics"); setwd("02_metrics")

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
    raster::projectRaster(crs = po_i$prj4, res = 30, method = "ngb")
  
  # buffers
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
    
    # values
    la_i_j_val <- la_i_j %>% 
      raster::freq() %>%
      tibble::as_tibble() %>% 
      dplyr::filter(value == 1)
    
    # 1. percentage of landscape
    if(nrow(la_i_j_val) == 1){
      pl <- landscapemetrics::lsm_c_pland(la_i_j) %>% 
        dplyr::filter(class == 1)
    } else{
      pl <- tibble::tibble(layer = i, 
                           level = "class",
                           class = 1,
                           id = NA,
                           metric = "pl",
                           value = 0)
    }
    
    # 2. patch density
    if(nrow(la_i_j_val) == 1){
      pd <-  landscapemetrics::lsm_c_pd(la_i_j) %>% 
        dplyr::filter(class == 1)
    } else{
      pd <- tibble::tibble(layer = i, 
                           level = "class",
                           class = 1,
                           id = NA,
                           metric = "pd",
                           value = 0)
    }
    
    
    # 3. edge density
    if(nrow(la_i_j_val) == 1 & pl$value < 100){
      ed <- landscapemetrics::lsm_c_ed(la_i_j) %>% 
        dplyr::filter(class == 1)
    } else{
      ed <- tibble::tibble(layer = i, 
                           level = "class",
                           class = 1,
                           id = NA,
                           metric = "ed",
                           value = 0)
    }
    
    # 4. splitting index
    if(nrow(la_i_j_val) == 1){
      si <- landscapemetrics::lsm_c_split(la_i_j) %>% 
        dplyr::filter(class == 1)
    } else{
      ed <- tibble::tibble(layer = i, 
                           level = "class",
                           class = 1,
                           id = NA,
                           metric = "si",
                           value = 0)
    }
    
    # map
    if(la_i_j[] %>% unique %>% na.omit %>% as.numeric %>% length == 2){
      pal <- c("palegreen", "forestgreen")
    }else if(la_i_j[] %>% unique %>% na.omit %>% as.numeric == 1){
      pal <- c("forestgreen")
    } else{
      pal <- c("palegreen")
    }
    
    pal
    
    # map <- tm_shape(po_i_j) +
    #   tm_borders() +
    #   tm_shape(la_i_j) +
    #   tm_raster(style = "cat", pal = pal) +
    #   tm_shape(po_i_j) +
    #   tm_borders() +
    #   tm_layout(legend.show = FALSE) +
    #   tm_credits(paste0("co=", i,"; bf=", j, "; pl=", round(pl$value, 2), 
    #                     "; pd=", round(pd$value, 2), "; ed=", round(ed$value, 2), 
    #                     "; si=", round(si$value, 2)), size = 1,
    #              position = c(.3, -.01))
    # map
    # tmap_save(map, paste0("map_com_", i, "_buf_", j, "m.png"))
    
    # combine
    metrics <- dplyr::bind_rows(pl, pd, ed, si) %>%
      dplyr::mutate(id = i, buffer = j) %>% 
      dplyr::select(id, buffer, class, metric, value) %>% 
      dplyr::bind_rows(metrics, .)
    
  }
  
}

# export table
readr::write_csv(metrics, "00_metrics.csv")

# end ---------------------------------------------------------------------
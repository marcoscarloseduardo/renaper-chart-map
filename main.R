# 1. Load necessary libraries
#    Cargar librerías necesarias
#----------------------------------------------------------------------
libs <- c("tidyverse", "sf", "ggiraph", "scales", "patchwork", "tigris", "geosphere")

# Install missing libraries
missing_libs <- libs[!libs %in% installed.packages()[, "Package"]]

if (length(missing_libs) > 0) {
  invisible(install.packages(missing_libs))
}

library(tidycensus)
library(tidyverse)
library(sf)
library(ggiraph)
library(scales)
library(patchwork)
library(tigris)
library(geosphere)


# 2. Check and create working directories if they don't exist
#    Verificar y crear directorios de trabajo si no existen
#----------------------------------------------------------------------
if (!file.exists("data")) {
  dir.create("data")
  print("Created 'data' directory.")
} else {
  print("'data' directory already exists.")
}


# 3. Load geospatial data: map_shp
#    Cargar datos geográficos: map_shp
#----------------------------------------------------------------------
map_shp <- st_read("data/saldo_migratorio_interdepartamental_relativo/saldo_migratorio_interdepartamental_relativo.shp")
st_crs(map_shp) <- "EPSG:4326"


# 4. Set centroids for departments
#    Establecer los centroides de los departamentos
#----------------------------------------------------------------------
map_shp <- map_shp |> 
  select(cde, nam, saldo_mil) |> 
  mutate(center_point = st_centroid(geometry))

map_shp <- cbind(map_shp, st_coordinates(st_centroid(map_shp$geometry)))


# 5. Set the department of interest and calculate its distance
#    Establecer el departamento de interés y calcular la distancia a este
#----------------------------------------------------------------------
doi <- map_shp |> filter(nam == "Trenque Lauquen")

map_shp <- map_shp |> mutate(distancia = as.numeric(sf::st_distance(center_point, doi)))


# 6. Filter departments within the influence zone (circle)
#    Filtrar los departamentos dentro de la zona de influencia (círculo)
#----------------------------------------------------------------------
r <- 196000 # meters
map_shp <- map_shp |> filter(distancia <= r)

map_shp <- map_shp |> mutate(nam = ifelse(nam == "Capital", "Santa Rosa", nam)) # fix department name

map_shp <- map_shp |> mutate(tooltip = paste(nam, round(saldo_mil, digits = 1), sep = ": "))


# 7. Plot the map
#    crear el mapa
#----------------------------------------------------------------------

# find out min and max values to configure appropriate color scale
min_val <- round(floor(min(map_shp$saldo_mil)/50), 0) * 50
max_val <- round(ceiling(max(map_shp$saldo_mil)/50), 0) * 50
step_val <- round((abs(max_val) + abs(min_val))/10, 0)

gg <- ggplot(map_shp) + 
  geom_sf_interactive(aes(tooltip = tooltip, data_id = cde, fill = saldo_mil),
                      size = 0.1) +
  scale_fill_viridis_c(
    option = "D",
    direction = -1,
    limits = c(min_val, max_val),
    breaks = seq(from = min_val, to = max_val, by = step_val)
  ) +
  labs(title = "Interdepartmental Migration Balance per 1,000 Inhabitants\nin the Trenque Lauquen Region (2012-2022)",
       fill = "") +
  theme_void() +
  theme(
    legend.position = "top",
    legend.text = element_text(size = 8, color = "grey20"),
    plot.caption = element_text(
      size = 8,
      color = "grey40",
      hjust = 0.5,
      vjust = 0
    ),
    plot.title.position = "panel",
    plot.caption.position = "plot",
    plot.title = element_text(hjust = 0.5)
  ) +
  guides(
    fill = guide_legend(
      direction = "horizontal",
      title.position = "top",
      keyheight = unit(5, "mm"),
      keywidth = unit(10, "mm"),
      label.position = "bottom",
      label.hjust = .5,
      label.vjust = 0,
      nrow = 1,
      byrow = TRUE,
      drop = TRUE
    )
  )

gg

gg_bar <-
  ggplot(map_shp, aes(
    y = saldo_mil,
    x = reorder(nam, -saldo_mil),
    fill = saldo_mil,
    tooltip = tooltip
  )) +
  geom_col_interactive(aes(data_id = cde)) +
  scale_fill_viridis_c(
    guide = "none",
    option = "D",
    direction = -1,
    labels = label_number(scale = 1, accuracy = NULL),
    breaks = seq(from = min_val, to = max_val, by = step_val),
  ) +
  scale_y_continuous(labels = label_number(scale = 1, accuracy = 0.1)) +
  theme_minimal(base_size = 8) +
  labs(x = "",
       y = "",
       caption = "Radius: 200 Km\nData: Direccion Nacional de Poblacion del RENAPER\n©2023 Carlos Marcos (https://github.com/marcoscarloseduardo)"
       ) +
  theme(
    axis.text.x = element_text(
      angle = 90,
      vjust = 0.5,
      hjust = 1
    ),
    legend.position = "bottom",
    legend.direction = "horizontal",
    plot.caption = element_text(
      color = "grey40",
      hjust = 1,
      vjust = 0
    ),
    plot.caption.position = "panel",
    panel.grid = element_blank()
  )

gg_bar

p <-
  girafe(
    ggobj = wrap_plots(
      gg,
      gg_bar,
      widths = c(8),
      heights = c(3, 1),
      ncol = 1,
      nrow = 2
    ),
    options = list(opts_hover(css = ""),
                   opts_hover_inv(css = "opacity:0.25;")
                   ),
    height = 8
  )

p

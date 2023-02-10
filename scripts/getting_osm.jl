using Agents
using LightOSM
using OSMMakie
using CairoMakie

# # define area boundaries
area = (
           minlat = -19.93984, minlon = -43.96163, # bottom left corner
           maxlat = -19.91317, maxlon = -43.91926 # top right corner
       )


# download_osm_network(:place_name;
#                    network_type = :drive,
#                    metadata = false,
#                    download_format=:json,
#                    save_to_file_location="plots/bh.json",
#                    place_name="Belo Horizonte")

download_osm_network(:bbox; # rectangular area
                   area..., # splat previously defined area boundaries
                   network_type = :drive, # download motorways
                   save_to_file_location = "plots/bh_min.json"
               );

# # use min and max latitude to calculate approximate aspect ratio for map projection
autolimitaspect = map_aspect(area.minlat, area.maxlat)

# # load as OSMGraph
osm = graph_from_file("plots/bh_min.json";
    graph_type = :light, # SimpleDiGraph
    weight_type = :distance
)

# # plot it

fig, ax, plot = osmplot(osm; axis = (; autolimitaspect))
fig
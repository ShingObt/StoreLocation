library(varhandle)
library(leaflet)
library(sp)
library(rgdal)
library(KernSmooth)
library(mapview)
library(crosstalk)
library(DT)
setwd("~/Desktop/dropbox/GEO/StoreLoc")
shp.orig=readOGR("japan_ver81.shp")
shp=spTransform(shp.orig,CRS("+proj=longlat +datum=WGS84"))
ras=raster(shp,res=10000)


sb=as.data.frame(t(read.csv("starbucks.csv",header=T)))
colnames(sb)=c("storeName","address","lon","lat")
sb=sb[2:nrow(sb),]
sb$lon=unfactor(sb$lon)
sb$lat=unfactor(sb$lat)
sb$chain="Starbucks"
sb$V1
yny=as.data.frame(t(read.csv("yoshinoya.csv",header=T)))
colnames(yny)=c("storeName","pref","city","subregion","address","lat","lon")
yny$lat=unfactor(yny$lat)
yny$lon=unfactor(yny$lon)
yny$chain="Yoshinoya"
yny=yny[2:nrow(yny),]


sb.temp=sb[,c("lat","lon","address","storeName","chain")]
yny.temp=yny[,c("lat","lon","address","storeName","chain")]
stores=rbind(sb.temp,yny.temp)
stores$chain=factor(stores$chain)

spdf <- sp::SpatialPointsDataFrame(
  cbind(stores$lon,  # lng
        stores$lat),# lat
  data.frame(stores[,c("chain","storeName","address","lon","lat")])
)
crs(spdf)=CRS("+proj=longlat +datum=WGS84")

pal <- colorFactor(c("green", "orange"), domain = c("Yoshinoya", "Starbucks"))

kdPlot=function(spdf,chain,bandwidth){
  spdf.select=spdf[spdf$chain==chain,]
  grd<- as.data.frame(spsample(spdf.select, "regular", n=100000))
  kde <- bkde2D(matrix(c(spdf.select@coords[,1],spdf.select@coords[,2]),ncol=2),
                bandwidth=c(bandwidth, bandwidth), gridsize = c(2000,2000))
  KernelDensityRaster <- raster(list(x=kde$x1 ,y=kde$x2 ,z = kde$fhat))
  shp.gunma=shp[shp$NAME=="Tokyo"|shp$NAME=="Chiba"|shp$NAME=="Saitama"|shp$NAME=="Kanagawa"|shp$NAME=="Ibaraki",]
  kdens=crop(KernelDensityRaster,shp)
  kdens=mask(kdens,shp,progress="text")
  # ext=extent(c(139.5,140,35.4,36))
  # kdens.crop=crop(KernelDensityRaster,ext)
  fun<-function(x){x[x<0.1]<-NA;return(x)}
  kd=calc(kdens,fun)
  plot(kd,
       zlim=c(0,40),
       main=chain)
  return(kd)
}
kd.sb=kdPlot(spdf,"Starbucks",0.05)
kd.yny=kdPlot(spdf,"Yoshinoya",0.05)
writeRaster(kd.sb,"kernerDensity_Starbucks.tif")
writeRaster(kd.yny,"kernerDensity_Yoshinoya.tif")
pal.sb <- colorNumeric(c("#2b83ba","#abdda4","#fdae61","#d7191c"), values(kd.sb),na.color = "transparent")



ch="Starbucks"
spdf.select=spdf[spdf$chain==ch,]
grd<- as.data.frame(spsample(spdf.select, "regular", n=100000))
kde <- bkde2D(
  matrix(
    c(spdf.select@coords[,1],spdf.select@coords[,2]),
    ncol=2
    ),
  bandwidth=c(.05, .05), 
  gridsize = c(2000,2000)
  )
KernelDensityRaster <- raster(list(x=kde$x1 ,y=kde$x2 ,z = kde$fhat))
shp.gunma=shp[shp$NAME=="Tokyo"|shp$NAME=="Chiba"|shp$NAME=="Saitama"|shp$NAME=="Kanagawa"|shp$NAME=="Ibaraki",]
kdens=crop(KernelDensityRaster,shp)
kdens=mask(kdens,shp,progress="text")
# ext=extent(c(139.5,140,35.4,36))
# kdens.crop=crop(KernelDensityRaster,ext)
fun<-function(x){x[x<0.1]<-NA;return(x)}
kd=calc(kdens,fun)
# plot(kdens,main=ch)
plot(kd,main=ch)


spdf@data$storeName=as.character(enc2native(as.character(spdf@data$storeName)))
writeOGR(spdf,".","locationdata.shp",driver="ESRI Shapefile",overwrite_layer = TRUE, encoding = "UTF-8")

m=leaflet(spdf)%>%addTiles()%>% 
  addCircleMarkers(color=~pal(chain),
                   popup=~storeName,
                   stroke=TRUE,
                   label=~storeName,
                   radius=4,
                   fillOpacity = 0.8,
                   opacity = 0,
                   group="Locations"
  )%>%
  addRasterImage(kd.yny,group = "Yoshinoya",opacity=0.8,colors = pal.sb)%>%
  addRasterImage(kd.sb,group = "Starbucks",opacity=0.8,colors = pal.sb)%>%
  addLegend(pal = pal.sb, values = values(kd.sb),
            title = "Store Density")%>%
    addProviderTiles("Esri.WorldImagery", group = "Satellite")%>%
  # Layers control
  addLayersControl(position = 'bottomright',
                   baseGroups = c("OSM", "Satellite"),
                   overlayGroups = c("Locations","Yoshinoya", "Starbucks"),
                   options = layersControlOptions(collapsed = FALSE))

m





#--------------------------------
#--------------------------------
df=spdf@data
sd <- SharedData$new(spdf@data)


bscols(widths =c(1,3),
  filter_checkbox("chain", "label", sd,~factor(chain), allLevels = FALSE),
  
leaflet(sd) %>%addTiles()%>%
  addCircleMarkers(
    # lat=sd$lat,
    # lng=sd$lon,
    popup=sd$storeName,
    clusterOptions = markerClusterOptions(showCoverageOnHover = TRUE,spiderfyOnMaxZoom = 19,spiderLegPolylineOptions = list(weight=5)),
    radius=5,
    label=~storeName,
    labelOptions=labelOptions(noHide = F, direction = "left"),
    popupOptions = popupOptions(closeOnClick = TRUE
                                # ,keepInView = TRUE
    )
    
  )%>%
  addProviderTiles("Esri.WorldImagery", group = "Satellite")%>%
  # Layers control
  addLayersControl(position = 'bottomright',
                   baseGroups = c("OpenStreetMap", "Satellite")),
datatable(sd, extensions="Scroller", style="bootstrap", class="compact", width="100%")
)













bscols(widths=c(3,1),
       filter_checkbox("chain", "label", sd,~factor(chain), allLevels = FALSE)
       ,
       map,
       datatable(sd, extensions="Scroller", style="bootstrap", class="compact", width="100%",options=list(deferRender=TRUE, scrollY=300, scroller=TRUE)))




rmarkdown::render(
  input = "flexashboard.Rmd", 
  output_file = "main.html",
  output_format = "flex_dashboard")

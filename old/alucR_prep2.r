

#lc | initial land cover categories. 
#p_raster | RasterStack of suitabilities (derived from suit earlier) for the specific land use classes to model. Layer names "lc1", "lc2"... with the numbers refering to the land cover classes in the initial land cover map lc
#nochange.lc | (optional) vector of charachter naming the land cover classes which do not change during the modelling experiment example c("lc5","lc6") when class 5 refers for example to water and 5 and 6 refer to water. Nochange classes should not be included in the suit RasterStack (will be dropped if any)
#natural.lc | (optional) vector of charachter naming the land cover classes which refer to natural vegetation. for example c("lc1","lc2") when landcover 1 refers to Forest and land cover 2 to secondary vegetation 
# spatial | (optional) RasterLayer defining Protected Areas (no change allowed within these areas). Locations of NA represent areas outside Protected areas, location != NA represent areas of Protection. If nessesary you can also provide a vector of RasterLayer Object names instead to define different Protected Areas for different sceanario years
#elas | (optional, but recomendet) matrix of values between 0 and 1 referring to the conversion/trajectory elasticity of the land use/cover classes. Rows: initial land use/cover (1 to n), Columns: following land use/cover (1 to n). Definition 0: no change due to elasticities, 0.5: incresed likelyness for the class or conversion, 1: very high likelyness for the class or conversion.
#traj | (optional, but recomendet) matrix describing the temporal trajectories of land use/cover. Rows: initial land use/cover (1 to n), Columns: following land use/cover (1 to n). Values define the years of transition, e.g. 0: no transition allowed, 1: transition allowed after first iteration, 10: transition allowed after 10 iterations. must be specified for all land_cover classes.

# init.years | (optional) RasterLayer, vales integer, referring to the number of years since the last lc change. 


alucR_prep2 <- function (lc, p_raster, spatial, init.years, var.list, epoche =epoche ,  elas, traj) {
  # extract variables from var.list
  lc_suit <-   var.list [[4]][["lc_suit"]]
  lc_slookup <- var.list [[4]] [["lc_slookup"]]
  nochange <- var.list [[5]][["nochange"]]
  lc_unique <- var.list [[3]][["lc_unique"]]
  lc_lookup <- var.list [[3]][["lc_lookup"]]
  natural <- var.list [[8]][["natural"]]
  naturallookup <-  var.list [[8]][["naturallookup"]]
  
  # check nochange.lc and p_raster - nochange.lc classes cannot be included in p_raster
  if (any(is.element (lc_suit,nochange))){
    drop.layer <- which(lc_suit == lc_suit[is.element (lc_suit,nochange)]) #which layer to drop cause defined as no change
    p_raster <- dropLayer (p_raster, drop.layer)
  }
  
  # read protected areas raster in case it it is defined differently for each epoche
  if (length (spatial)> 0){
    if (class(spatial)=="character"){
      spatial <- get(spatial[epoche])# in case different stacks for each episode are specified - possibly useful if the protected area network will be expanded during the modelling experiment
    } # else it is defined as raster in the input to the function 
  }
  
  # land use history 
  if (epoche == 1){
    if (class(init.years)!="RasterLayer" & class(init.years)!="numeric"){
      print ("init.years need to be either a RasterLayer or a single 'numeric value'")
      init.years <-  setValues (lc, 0)
    } else if (class(init.years) == "numeric" & length (init.years) > 1) { 
      print ("only first value of init.year is used")
    } else if (class( init.years) == "numeric"){
      init.years <-  setValues (lc, init.years[1])
    } 
  }
  
  
  # check if rasters belong to the same projection, have same extend and origine
  if (extent(lc) != extent (p_raster)){print ("Raster extents do not match (lc!=suit)")}
  if (projection(lc) != projection (p_raster)){print ("Raster projections do not match (lc!=suit)")}
  if (any(origin(lc) != origin(p_raster))){print ("Raster origine's do not match (lc!=suit)")}
  
  if (length (spatial)> 0){ 
    if (extent(lc) != extent (spatial)){print ("Raster extents do not match (lc!=spatial)")}
    if (projection(lc) != projection (spatial)){print ("Raster projections do not match (lc!=spatial)")}
    if (any(origin(lc) != origin (spatial))){print ("Raster origine's do not match (lc!=spatial)")}
  }
  
  if (extent(lc) != extent (init.years)){print ("Raster extents do not match (lc!=init.years)")}
  if (projection(lc) != projection(init.years)){print ("Raster projections do not match (lc!=init.years)")}
  if (any(origin(lc) != origin (init.years))){print ("Raster origine's do not match (lc!=init.years)")}
  
  # if natural suitability required 
  if (length (natural) > 0){ 
    out.n <- setValues(lc ,0.5) ; names(out.n)<- "lcN"
    p_raster <- addLayer (p_raster, out.n) 
  }
  
  # chunk prep
  out <- brick(p_raster, values=FALSE)
  
  small <- canProcessInMemory(out, 3)
  filename <- trim(filename)
  
  if (!small  & filename == '' ){
    filename <- rasterTmpFile()
  }
  if (filename != ''){
    out <- writeStart(out, filename, overwrite=TRUE)
    todisk <- TRUE
  } else{
    vv <- array(dim=dim(out)) 
    todisk <- FALSE
  }
  
  bs <- blockSize(out)
  pb <- pbCreate(nsteps= bs$n)
  
  # chunk processing	
  for (i in 1:bs$n) {
    #read chunks
    v.lc <- getValues(lc, row=bs$row[i], nrows=bs$nrows[i] )
    v.suit <- getValues(p_raster , row=bs$row[i], nrows=bs$nrows[i] )
    if (length (spatial) > 0) { v.spatial <- getValues(spatial, row=bs$row[i], nrows=bs$nrows[i] )}
    v.init.years <- getValues(init.years, row=bs$row[i], nrows=bs$nrows[i] )
    if(length (natural) > 0 ){
      v.natural<- getValues(out.n, row=bs$row[i], nrows=bs$nrows[i]) # natural vegetation vector 
      v.natural[is.na(v.lc)]<- NA
    }
    #process
    #no.change classes masked from suitability 
    if (length(nochange) > 0 ){
      nochange_index <- is.element(v.lc, nochange)  
      v.suit[nochange_index, ] <- NA
      if(length (natural) > 0 ){
        v.natural[nochange_index]  <- NA  # include if exists
      }
    }
    
    #spatial restrictions masked from suitability
    if (length (spatial)> 0){ # make sure to 
      sp.rest_index <- !is.na(v.spatial) # set those to NA which have a value in the restriction layer
      v.suit[sp.rest_index,] <- NA
      if(length (natural) > 0 ){
        v.natural [sp.rest_index] <- NA
      }
    } else { sp.rest_index <- c()}
    
    
    #####
    # elasticities Matrix for suitability classes 
    ####	
    # for suitabilities
    for (i in 1:length (lc_unique)){
      # identify classes changes in probaility due to elas
      elas_ind <-  which(elas[lc_lookup[i],lc_slookup] != 0) #
      # in case no elasticities apply for the conversion probability
      if (length(elas_ind) > 0){  
        # index cases where elasticities apply
        cat_index <- which(v.lc==lc_unique[i])
        if (length (cat_index) > 0 ){
          for (a in 1:length(elas_ind)){
            v.suit[cat_index, elas_ind[a]] <- v.suit[ cat_index, elas_ind[a]] + elas [lc_lookup[i], lc_slookup[elas_ind[a]]] 
          }
        }
      }
    }
    
    # for natural land cover
    if (length (natural) > 0 ){
      for (i in 1:length(lc_unique)){
        # identify classes with restricted trajectories to land use
        elas_ind <-  which(elas[lc_lookup[i],natural] != 0) # 
        # in case no elasticities apply for the conversion probability
        if (length(elas_ind) > 0){  
          # index cases where elasticities apply
          cat_index <- which(v.lc==lc_unique[i])  
          if (length (cat_index) > 0 ){
            v.natural[cat_index] <- v.natural[ cat_index] + max( elas [lc_unique[i],natural[elas_ind]])
          }
        }
      }
    } 
    
    
    #Trajectories of land use change
    #####
    # general:
    # transitions which are not allowed are set to NA in the respective suitability layer (target)
    # transitions different to 1, referring to transition possible after one iteration (year) are identified 
    # those identified are checked against the transition years vector. if years < transition years the target suitability is set to NA
    # specific steps: 
    
    # conversion restrictions from all land covers to the  land use classes (suitability layer)
    # for all unique land cover classes to land use classes 
    
    for (j in 1:length(lc_unique)){ 
      # identify classes with restricted trajectories to land use
      traj_ind <-  which(traj[lc_lookup[j],lc_slookup] != 1) # fuer 1 an der stelle 2 - lookup table in case classes start with 0
      # in case no restriction due to trajectories apply 
      if (length(traj_ind) > 0){  
        # index classes with restricted trajectories
        cat_index <- which(v.lc==lc_unique[j])  # fuer 2 an der stelle 1
        for (a in 1:length(traj_ind)){
          # set v.suit at the specific location for the specific layer  to NA if the amount of years is not reached
          v.suit[ cat_index, traj_ind[a]]<- ifelse (v.init.years[cat_index] < traj[lc_slookup [traj_ind[a]], lc_lookup[j]], NA, v.suit[ cat_index, traj_ind[a]])
        }
      }
    }
    if(length (natural) > 0 ){
      # conversion restrictions from any class to natural vegetation class 
      lc.nonatural <- lc_unique [-naturallookup]
      lc.nonalookup <- lc_lookup [-naturallookup] 
      for (j in 1:length(lc.nonalookup)){
        traj_ind <- which(is.element ( 1 ,  traj[naturallookup,lc.nonalookup[j]])==FALSE) # identify which trajectories are unequal 1 (are not allowed after one year) # lookup table in case classes start at 0
        if (length(traj_ind) > 0){ 
          cat_index <- which(v.lc==lc.nonatural[j])
          v.natural[cat_index] <- ifelse (v.init.years[cat_index] < min(traj[lc.nonalookup[j], naturallookup]), NA, v.natural[cat_index])
        }
      }	
    }
    #####
    #combine suit and natural
    ####
    if(length (natural) > 0 ){
      v <- cbind(v.suit, v.natural)
    } else {
      v <- v.suit
    }
    
    # write to raster
    if (todisk) {
      out <- writeValues(out, v, bs$row[i])
    } else {
      cols <- bs$row[i]:(bs$row[i]+bs$nrows[i]-1)
      for (k in 1:dim(out)[3]){
        vv.t <- t(matrix( v[, k], nrow=dim(out)[2]))
        vv [cols,, k] <- vv.t
      }
    }
    pbStep(pb, i)
  }
  if (todisk) {
    out <- writeStop(out)
  } else {
    out <- setValues(out, vv)
  }
  pbClose(pb)
  return(out)
}

	
	
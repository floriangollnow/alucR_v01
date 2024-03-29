#alucR_v01 - allocation of land use change Version 01

alucR - Project is a first step to implement a Land Use Change Model in R (http://www.r-project.org). We have been following the basic framework provided by Verburg et al. (2002). Land use is spatially allocated following the suitability of a certain cell for the specific land use. Amounts of land use (demand) for future (scenario) allocation have to be defined a priori within the scenario definition process. These amount usually refer to agricultural production needs and urban change translated into pixel numbers.        

The demand of future land use will be spatially allocated according to the highest suitability for each land use class. Here competition between land use is simulated by distributing the land use at those locations where the suitability is highest. Within this process the suitability layers are iteratively weighted until the demands of future land use (defined a priori) are meet.     

The suitability layers might be assessed using statistical methods (for example logistic regression), machine learning algorithms (for example boosted regression trees) or other modelling techniques (for example Multi Criteria Analysis).  
Natural land cover is generally defined to be equally probable for any location. Possible succession stages may be modelled based on the temporal trajectories of succession stages defined in the trajectories matrix. The code uses basic R-language and packages. This makes it possible to easily adapt the code to the user's specific needs.   

Please cite as:   
Gollnow, F.; G�pel, J.; Hissa, L.B.V.; Schaldach, R.; Lakes, T. (2017): Scenarios of land-use change in a deforestation corridor in the Brazilian Amazon: combining two scales of analysis, Regional Environmental Change, 1-17. doi:10.1007/s10113-017-1129-1      


A poster with an example application can be found here: [dx.doi.org/10.13140/RG.2.1.3711.9600](https://www.researchgate.net/publication/303924561_An_Open_and_Flexible_Land_Use_Model_for_Scenario_Assessments_alucR_Allocation_of_Land_UseCover_in_R?channel=doi&linkId=575ea5e608aec91374b3e778&showFulltext=true)    



##Difference to previous version of alucR
1. Processing RasterLayer in tiles if nessesary due to memory restriction.   
2. The version alucR_v01 takes a modular approach following a set of function with specified in and output. This approach makes it easier to add new submodules as for example nessesary when your suitability layers depend on the last landcover distribution from your sceanrios (i.e. if spatial lags are important).
3. The stopping criteria of the allocation routine has been changes. See description

##Submodules stucture
* initializing ('alucR_0wrapper.r')
* preprocessing ('alucR_1checkInput.r'; 'alucR_1prep_rule_mw.r'; 'alucR_1prep_varlist.r';'alucR_2prep_raster.r'; 'alucR_3prep_demand.r')
* allocation of change ('alucR_4competitive_function_in_prep.r')
* postprocessing ('alucR_5postprocess.r')
* saving results ('alucR_0wrapper.r')

Thes submodules are called from the wrapper function _'alucR_0wrapper.r'_ script. While all the required functions (above mentioned) need to be sourced (defined) seperately.   

To initialize the function: store all files in a folder and run the _'sourceFunction.r'_ Script, to source all nessesary scripts.


##Function

aluc(lc, suit, natural.lc=NULL, nochange.lc=NULL, spatial=NULL, demand, elas=matrix(data=0, ncol=max(lc_unique), nrow=max(lc_unique)), traj=matrix(data=1, ncol=max(lc_unique), nrow=max(lc_unique)), init.years= 5, method = "competitive", rule.mw = NULL, stop.crit=c(0.10 , 10), iter.max=100, ncores=(detectCores()-1), print.log=TRUE, print.plot=FALSE, write.raster=FALSE)

##the function returns a 'List' object:
[[1]] 'RasterStack' containing the categorical scenarios of land use allocation for the requested years (as defiend in the 'demand')
[[2]] 'data.frame' of log information

argument | description 
----- | ----- 
lc | initial land use/cover map 						
suit | either a RasterStack or a list of RasterStacks(for each year/epoche of sceanrio assessment) of the suitabilities for land use classes (ordered by preferences). These are usually the result of a suitability analysis. The data type should be Float (FLT4S). The names of the layers should correspond to the landuse classes, starting with "lc#", for example: "lc7", "lc4", "lc3",.. , only include suitabilities for landuses present in the initial land cover dataset and referenced in the 'demand' file. 						
natural.lc | character string defining land cover classes referring to natural vegetation ordered by succession states. For example: c("lc1", "lc2"). There should not be specific suitability layer for these classes. If suitability layers are provided they need to be defined in the suitability stack ('suit') and refered to in the 'demand' table			
nochange.lc | character string defining land cover/use classes wich are assumed to be stable during the sceanrio assessment. These classes cannot have a suitability layer in the 'suit' stack, neither be defined in the demand table or defined as 'natural.lc'. An example may be 'water' having land cover class 5. In this case you can indicate 'nochange.lc= c("lc5")'.			
spatial | either a RasterLayer or a list of RasterLayers(for each year/epoce of sceanrio assesment) of the locations where no land use change is allowed (i.e. Protected Areas).Definition: 'NA' for areas where conversions are allowed and 1 (or any other values) for areas where conversions are not allowed
demand | data.frame specifying the amount of pixel for each land use class (present in 'suit') for the subsequent modelling steps. Columns refer to the land use classes for which there is a suitability layer (same naming as for suitability layers), number of rows equal the number of modelling steps/epoches. Values should be integer.
elas | matrix of values between 0 and 1 referring to the conversion elasticity of the land use/cover classes. Rows: initial (t)land use/cover (1 to n), Columns: following (t+1) land use/cover (1 to n). Definition 0: no change to the original suitabilities, 0.5: incresed likelyness for the class or conversion (0.5 added to suitabilities at the specific location), 1: very high likelyness for the class or conversion (1 added to suitabilities at the specific location).
traj | matrix describing the temporal trajectories of land use/cover. Rows: initial (t) land use/cover (1 to n), Columns: following (t+1) land use/cover (1 to n). Values define the years/epoches of transition, e.g. 0: no transition allowed, 1: transition allowed after first iteration, 10: transition allowed after 10 iterations. must be specified for all land use/cover classes.
init.years | numeric value or RasterLayer to set the initial number of years the pixels are under the specific land use/cover at the beginning of the modelling.   
method | either "competitive" or "hierarchical" see description (so far only #competitive is avalable)
rule.mw | optional moving window algorithm. applies a moving window algorithm (circular) on the defined land use class(es) and weight the respective suitability layer accordingly (example: urban is more likely to expand around urban areas). Suitability layer will be multiplied with the neighborhood weights and 0 set to NA . Definition: data.frame containing name of land use class and radius of moving window. Example data.frame(name="lc7",radius=500)
stop.crit | (only applicable if method='competitive') stoping criteria defined as a vector with two values: first one refers to max percent difference from the land use changes 'demand'ed, second to the maximum pixel difference allowed. If the first & second is reached  or the second the allocation stops and saves the sceanario land cover
iter.max | (only applies for method='competitive') integer number specifying the maximum number of iteration until the allocation of land use/cover is stopped if the 'stop.crit' was not reached before. In that case the best out of the available allocation is returned)
ncores | (only applies for method="competitive")integer number specifying the number of cores to use during processing
print.log | TRUE/FALSE if tail of log file is printed during processing 
print.plot | TRUE/FALSE if iter and the final raster are plotted during model execution
write.raster | TRUE/FALSE if scenario output raster should be written to the working directory during iteration names 'scenario...tif'




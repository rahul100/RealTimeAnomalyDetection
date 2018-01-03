rm(list=ls()) # Removing unused R objects from RAM
# importing libraries
#------------------------------------------------
library(tseries)
library(data.table)
library(DMwR)
library(jsonlite)
#------------------------------------------------

# Parameters - General
#------------------------------------------------
server<-"http://localhost"
port<-"8086"
database<-"nyctaxi"
tablename<-"nyc_taxi_data"
chunksize<-"241"
DEBUG_MODE<-TRUE

if (DEBUG_MODE){
  PARAM_IGNORE_STDERR<- FALSE
}else {
  PARAM_IGNORE_STDERR<- TRUE
  
}

# Parameters - LOF Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE # set to true in debug mode
param_k<-200  ## number of neighbors to compare density with
param_max_anoms<-2  ## should be > 1 and less than 10% of the chunk size
#------------------------------------------------

# Helper functions
# trim function
#------------------------------------------------
trim <- function (x) gsub("^\\s+|\\s+$", "", x)
#------------------------------------------------

# Write to DB 
#------------------------------------------------
writedb <- function(x , table ) {
  timestamp <- x[1]
  value <- x[2]
  insert_db<-paste(table ," " , "value=" ,trim(value) , " " , timestamp ,sep="")
  command<-paste("curl -i -XPOST '" , server , ":"  , port ,"/write?db=" , database , "' --data-binary '" , insert_db , "'" , sep="")
  system(command ,  ignore.stderr = PARAM_IGNORE_STDERR)
}
#-------------------------------------------------

# Read from DB and return json
#-------------------------------------------------
readdb <- function() {
  query<-paste("curl -GET 'http://localhost:8086/query?pretty=true' --data-urlencode 'db=" ,database , "' --data-urlencode 'epoch=ns' --data-urlencode 'q=SELECT value FROM " , tablename ," where time > now() - ",chunksize ,"s '" , sep="")
  result_json<-system(query , intern=TRUE , ignore.stderr = PARAM_IGNORE_STDERR)
  result_json
}
#-------------------------------------------------


while(1){
  
  ptm<- proc.time() # get current time
  result_json<-readdb() # read chunk from influx

  # format resuts from json to dataframe
  #-------------------------------------------------
  final<-fromJSON(result_json)
  final_2dlist<-final[[1]]$series[[1]]$values[[1]][,]
  nyc_taxi_chunk<-as.data.frame(final_2dlist)
  options(scipen = 999)
  colnames(nyc_taxi_chunk) <- c('timestamp' , 'count')
  nyc_taxi_chunk$count<-as.numeric(trim(as.character(nyc_taxi_chunk$count)))
  nyc_taxi_chunk$timestamp<-as.character(nyc_taxi_chunk$timestamp)
  
  if(nrow(nyc_taxi_chunk)< param_k){
    print("Not enough data")
    next
  }

  #-------------------------------------------------
  # Run LOF anomaly detection  algorithm
  #-------------------------------------------------

  outlier.scores <- lofactor(nyc_taxi_chunk[,"count" , drop=FALSE], k=param_k)
  outlier.scores1<- outlier.scores[!is.na(outlier.scores)]
  outliers <- order(outlier.scores1, decreasing=T)[1:param_max_anoms]
  anomalies<-nyc_taxi_chunk[outliers,]
  if(plotting_flag){  
    plot(nyc_taxi_chunk ,type="l" ,col="blue")
    points(nyc_taxi_chunk[outliers,] , col="red")
  }

  #-------------------------------------------------
  #Write results to db
  #-------------------------------------------------
  if(nrow(anomalies) >=1 ){
    apply(anomalies, 1, writedb ,"lof")
  }
  
  #-------------------------------------------------
  
  time_elapsed<-proc.time() - ptm
  if(time_elapsed>0 && time_elapsed[3]<1) { Sys.sleep(1 - time_elapsed[3]) }  #  sleep for remaining time (algorithm needs to run exactly after 1sec)
  
}

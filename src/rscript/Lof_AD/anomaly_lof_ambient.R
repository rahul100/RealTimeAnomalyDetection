rm(list=ls()) # Removing unused R objects from RAM
# importing libraries
#------------------------------------------------
library(tseries)
library(data.table)
library(DMwR)
library(jsonlite)
suppressPackageStartupMessages(library("argparse"))
#------------------------------------------------
# Taking input from user

parser <- ArgumentParser()	
parser$add_argument("-d", "--db", type="character", default="nyctaxi", help="DB name")
parser$add_argument("-m", "--measurement", type="character", default="nyc_taxi_data", help="Measurement name")
args <- parser$parse_args()
#------------------------------------------------

# Parameters - General
#------------------------------------------------
server<-"10.34.12.155"	
port<-"8086"
database<-args$db
tablename<-args$measurement
# database<-"ambient_temp_real_time"
# tablename<-"ambient_temp_data"

chunksize<-"101"
DEBUG_MODE<-TRUE

if (DEBUG_MODE){
  PARAM_IGNORE_STDERR<- FALSE
}else {
  PARAM_IGNORE_STDERR<- TRUE
  
}

# Parameters - LOF Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE # set to true in debug mode
param_k<-50  ## number of neighbors to compare density with
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
  time <- x[1]
  value <- x[2]
  timestamp <- x[3]
  anomalyScore <- x[5]
  anomaly<-x[6]
  insert_db<-paste(table ,","  ,"anomaly=",trim(anomaly) , " " , "value=" ,trim(value) , "," , "timestamp=" , '"', trim(timestamp) ,'"',"," , "anomalyScore=" ,anomalyScore," " ,time,sep="")
  command<-paste("curl -i -XPOST '" , server , ":"  , port ,"/write?db=" , database , "' --data-binary '" , insert_db , "'" , sep="")
  system(command ,  ignore.stderr = PARAM_IGNORE_STDERR)
}
#-------------------------------------------------

# Read from DB and return json
#-------------------------------------------------
readdb <- function() {
  query<-paste("curl -GET 'http://localhost:8086/query?pretty=true' --data-urlencode 'db=" ,database , "' --data-urlencode 'epoch=ns' --data-urlencode 'q=SELECT value,timestamp FROM " , tablename ," where time > now() - ",chunksize ,"s '" , sep="")
  result_json<-system(query , intern=TRUE , ignore.stderr = PARAM_IGNORE_STDERR)
  result_json
}
#-------------------------------------------------

while(1){
  options(scipen = 999)
  ptm<- proc.time() # get current time
  result_json<-readdb() # read chunk from influx
  
  # format resuts from json to dataframe
  #-------------------------------------------------
  final<-fromJSON(result_json)
  final_2dlist<-final[[1]]$series[[1]]$values[[1]][,]
  chunk<-as.data.frame(final_2dlist)
  colnames(chunk) <- c('time' , 'count', 'timestamp')
  #head(chunk)
  chunk$count<-as.numeric(trim(as.character(chunk$count)))
  chunk$timestamp<-as.character(chunk$timestamp)
  chunk$time<-as.character(chunk$time)
  
  if(nrow(chunk)< param_k){
    print("Not enough data")
    next
  }
  

  #-------------------------------------------------
  # Run LOF anomaly detection  algorithm
  #-------------------------------------------------

  outlier.scores <- lofactor(chunk[,"count" , drop=FALSE], k=param_k)
  anomalies<-cbind(chunk , outlier.scores)
  colnames(anomalies) = c("time", "count"  , "timestamp"  , "anomalyScore")
  min_chunk<-min(anomalies[,"anomalyScore"])
  max_chunk<-max(anomalies[,"anomalyScore"])
  if(plotting_flag){
    plot(chunk ,type="l" ,col="blue")
    points(chunk[outliers,] , col="red")
  }
  anomalies[,'anomalyScore_norm'] <- (anomalies[,'anomalyScore']  - min_chunk)/(max_chunk-min_chunk)
  anomalies<-tail(anomalies,1)
  anomalies[ , 'anomaly'] <- ifelse(anomalies[,'anomalyScore_norm'] >0.90 , 'Y' , 'N')
 # print(anomalies)
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

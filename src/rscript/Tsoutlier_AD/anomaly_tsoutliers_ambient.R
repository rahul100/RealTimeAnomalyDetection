rm(list=ls()) # Removing unused R objects from RAM
# importing libraries
#------------------------------------------------
library(tseries)
library(data.table)
library(tsoutliers)
library(expsmooth)
library(fma)
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
chunksize<-"20"
DEBUG_MODE<-TRUE

if (DEBUG_MODE){
  PARAM_IGNORE_STDERR<- FALSE
}else {
  PARAM_IGNORE_STDERR<- TRUE
  
}

# Parameters - TS outliers Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE
param_k<-10
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
  query<-paste("curl -GET 'http://" , server,":8086/query?pretty=true' --data-urlencode 'db=" ,database , "' --data-urlencode 'epoch=ns' --data-urlencode 'q=SELECT value FROM " , tablename ," where time > now() - ",chunksize ,"s '" , sep="")
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
  chunk<-as.data.frame(final_2dlist)
  options(scipen = 999)
  colnames(chunk) <- c('timestamp' , 'count')
  chunk$count<-as.numeric(trim(as.character(chunk$count)))
  chunk$timestamp<-as.character(chunk$timestamp)
  #chunk
  if(nrow(chunk)< param_k){
    print("Not enough data")
    next
  }
  
  #-------------------------------------------------
  # Run TS Outliers(Chen and Liu's time series outlier detection) anomaly detection  algorithm
  #-------------------------------------------------
  chunk_ts=ts(chunk[,"count" , drop=FALSE],frequency=1)  
  adftest=adf.test(chunk_ts, alternative="stationary", k=0)   
  if (adftest$alternative!="stationary"){
    print("Chunk is not stationary , moving to next chunk")
    next
  }
  
  cond <- simpleError("error")
  find_anomaly =tryCatch( tsoutliers::tso(chunk_ts,types = c("AO","LS","TC"),maxit.iloop=10),error=function(cond) NULL)
  if(is.null(find_anomaly)) next
  
  if(plotting_flag){  
    plot(find_anomaly)
  }
  anomalies<-chunk[find_anomaly$outliers$time,]
  
  #-------------------------------------------------
  #Write results to db
  #-------------------------------------------------
  if(nrow(anomalies) >=1 ){
    apply(anomalies, 1, writedb ,"tsoutlier")
  }
  
  #-------------------------------------------------
  
  time_elapsed<-proc.time() - ptm
  if(time_elapsed>0 && time_elapsed[3]<1) { Sys.sleep(1 - time_elapsed[3]) }  #  sleep for remaining time (algorithm needs to run exactly after 1sec)
  
}

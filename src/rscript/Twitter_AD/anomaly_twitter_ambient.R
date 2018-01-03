rm(list=ls()) # Removing unused R objects from RAM
# importing libraries
#------------------------------------------------
library(jsonlite)
library(data.table)
library(AnomalyDetection)
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
chunksize<-"216"
DEBUG_MODE<-TRUE
if (DEBUG_MODE){
  PARAM_IGNORE_STDERR<- FALSE
}else {
  PARAM_IGNORE_STDERR<- TRUE
  
}

# Parameters - Twitter Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE
param_period<-24
param_max_anomalies<-0.1
param_k<-100

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
proc.time() - ptm

# format resuts from json to dataframe
#-------------------------------------------------
final<-fromJSON(result_json )
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
# Run twitter anomaly detection  algorithm
#-------------------------------------------------
cond <- simpleError("error")
res =tryCatch(AnomalyDetectionVec(nyc_taxi_chunk[,2 , drop=FALSE], max_anoms=param_max_anomalies , direction='both',  period = param_period, plot=plotting_flag) ,error=function(cond) NULL)
#print(nrow(res$anoms))
if(is.null(res)) next
#res = AnomalyDetectionVec(nyc_taxi_chunk[,2 , drop=FALSE], max_anoms=param_max_anomalies , direction='both',  period = param_period, plot=plotting_flag)
#res
anomalies<-nyc_taxi_chunk[res$anoms$index,]

#-------------------------------------------------
#Write results to db
#-------------------------------------------------
if(nrow(anomalies)>=1){
apply(anomalies, 1, writedb ,"twitter")
}
#-------------------------------------------------

time_elapsed<-proc.time() - ptm
if(time_elapsed[3]>0 && time_elapsed[3]<1) { Sys.sleep(1 - time_elapsed[3]) }  #  sleep for remaining time (algorithm needs to run exactly after 1sec)

}

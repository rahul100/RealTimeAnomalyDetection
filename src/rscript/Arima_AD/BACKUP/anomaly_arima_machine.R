rm(list=ls()) # Removing unused R objects from RAM
# importing libraries
#------------------------------------------------
library(tseries)
library(data.table)
library(forecast)
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
chunksize<-"241"
DEBUG_MODE<-TRUE

if (DEBUG_MODE){
        PARAM_IGNORE_STDERR<- FALSE
}else {
        PARAM_IGNORE_STDERR<- TRUE
        
}


# Parameters - Arima Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE
param_period<-48
threshold_sd<-2
p<-1
d<-1
q<-1
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
        #result_json
        #proc.time() - ptm
        
        # format resuts from json to dataframe
        #-------------------------------------------------
        final<-fromJSON(result_json)
        final_2dlist<-final[[1]]$series[[1]]$values[[1]][,]
        nyc_taxi_chunk<-as.data.frame(final_2dlist)
        options(scipen = 999)
        colnames(nyc_taxi_chunk) <- c('timestamp' , 'count')
        nyc_taxi_chunk$count<-as.numeric(trim(as.character(nyc_taxi_chunk$count)))
        nyc_taxi_chunk$timestamp<-as.character(nyc_taxi_chunk$timestamp)
        if(nrow(nyc_taxi_chunk)< 100){
        print("Not enough data")
        next
        }

        x=log(nyc_taxi_chunk[1:(nrow(nyc_taxi_chunk)-param_period),2 , drop=FALSE])
        y=ts(x$count,frequency=param_period)
        adftest=adf.test(y, alternative="stationary", k=0)   
        if (adftest$alternative!="stationary"){
	print("Chunk is not stationary , moving to next chunk")
	next
	}
        
          
        #-------------------------------------------------
        # Run Arima anomaly detection  algorithm
        #-------------------------------------------------
        #x<-auto.arima(log(nyc_taxi_chunk[1:(as.numeric(chunksize)-param_period),2 , drop=FALSE]),trace=TRUE,allowdrift=TRUE,ic = "aic")
        #str(x)
        #x$model
        
        #str(x)
	cond <- simpleError("error")
        fit =tryCatch( arima(y, c(p, d, q),seasonal = list(order = c(p, d, q), period = param_period), method="ML"),error=function(cond) NULL)
	if(is.null(fit)) next

#        fit <- arima(y, c(p, d, q),seasonal = list(order = c(p, d, q), period = 48), method="CSS")
        pred <- predict(fit, n.ahead = 1*param_period)
        #pred$pred
        actual <-nyc_taxi_chunk[(nrow(nyc_taxi_chunk)-param_period+1):nrow(nyc_taxi_chunk) ,2 , drop=FALSE]
        #actual
        #data.frame(2.718^pred$pred)
        #actual - data.frame(2.718^pred$pred)
        threshold<-threshold_sd*sd(nyc_taxi_chunk[1:(nrow(nyc_taxi_chunk)-param_period),2])      
#        threshold
        anomalies_logical<- (abs(actual - data.frame(2.718^pred$pred)) > threshold)
        anom<-actual[anomalies_logical, , drop=FALSE]
        anom<-anom[!is.na(anom) , , drop=FALSE]
        anom
#        ts.plot(actual,2.718^pred$pred, log = "y", lty = c(1,3))
        
        anomalies<- actual[rownames(anom), , drop=FALSE]
#        anomalies
        #nyc_taxi_chunk
        anomalies_1<-nyc_taxi_chunk[as.numeric(rownames(anomalies)),]
        
#        lines(anomalies_1[ , 'count' , drop=FALSE],col='red')
#        anomalies_1
        #-------------------------------------------------
        #Write results to db
        #-------------------------------------------------
        if(nrow(anomalies_1) >=1 ){
        apply(anomalies_1, 1, writedb ,"arima")
        }
        
        #-------------------------------------------------
        
        time_elapsed<-proc.time() - ptm
        if(time_elapsed[3]>0 && time_elapsed[3]<1) { Sys.sleep(1 - time_elapsed[3]) }  #  sleep for remaining time (algorithm needs to run exactly after 1sec)
        
}

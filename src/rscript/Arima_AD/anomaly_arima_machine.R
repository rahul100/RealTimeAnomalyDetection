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


# Parameters - Arma Anomaly Detection algorithm
#------------------------------------------------
plotting_flag<-FALSE
param_period<-24
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
  time <- x[1]
  value <- x[2]
  timestamp <- x[3]
  anomalyScore <- x[4]
  anomaly<-x[5]
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
        colnames(chunk) <- c('timestamp' , 'count')
        chunk$count<-as.numeric(trim(as.character(chunk$count)))
        chunk$timestamp<-as.character(chunk$timestamp)

	if(nrow(chunk)< 100){
	print("Not enough data")
	next
	}
        x=log(chunk[1:(nrow(chunk)-1),2 , drop=FALSE])
        y=ts(x$count,frequency=param_period)
        adftest=adf.test(y, alternative="stationary", k=0)   
        if (adftest$alternative!="stationary"){
	print("Chunk is not stationary , moving to next chunk")
	next
        }
        #print (adftest$alternative)
        #z=auto.arima(y,trace=TRUE,allowdrift=TRUE)
        #str(z$arma)
        #arimaorder(z)
          
        #-------------------------------------------------
        # Run Arma anomaly detection  algorithm
        #-------------------------------------------------
	cond <- simpleError("error")
        fit =tryCatch( arima(y, c(p, d, q),seasonal = list(order = c(p, d, q), period = param_period), method="ML"),error=function(cond) NULL)
        if(is.null(fit)) next
        pred <- predict(fit, n.ahead = 1)
        #pred$pred
        actual <-tail(chunk[,2 ],1)
        threshold<-sd(chunk[1:(nrow(chunk)),2])      
#        threshold
        predicted<-2.718^pred$pred
        final<-tail(chunk,1)
        anomalyScore= 1 - (1/((abs(predicted - actual)/(0.2*threshold)) + 1))
        print(anomalyScore)
#        ts.plot(actual,2.718^pred$pred, log = "y", lty = c(1,3))
        if(anomalyScore > 0.75){
            anomaly = "Y"
	}
        else{
            anomaly = "N"
        }
        final[,"anomalyScore"]<- anomalyScore
         
        final[,"anomaly"]<- anomaly

        #-------------------------------------------------
        #Write results to db
        #-------------------------------------------------
        if(nrow(final) >=1 ){
        apply(final, 1, writedb ,"arima")
        }
        
        #-------------------------------------------------
        
        time_elapsed<-proc.time() - ptm
        if(time_elapsed[3]>0 && time_elapsed[3]<1) { Sys.sleep(1 - time_elapsed[3]) }  #  sleep for remaining time (algorithm needs to run exactly after 1sec)
        
}

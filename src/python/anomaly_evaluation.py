#libraries
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.metrics import roc_curve, auc
import sys
from datetime import datetime
import json
import time
import argparse
import os
# influx
from influxdb import InfluxDBClient

def parse_args():
	parser = argparse.ArgumentParser( description='Select Evaluation parameters')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi_eval', help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='nyc_taxi_data', help='Measurement Name')
	return parser.parse_args()

args = parse_args()
# influx configuration
user = 'root'
password = 'root'
dbname = args.db
measurement = args.measurement
dbuser = 'root'
dbuser_password = 'root'
client = InfluxDBClient('10.34.12.155', '8086', user, password, dbname)
data = None
def read_main_data_from_influx():
	global data
	query = 'select value,anomaly from ' + measurement
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [[point[0] ,point[1] , int(float(point[2]))] for point in data]
	data = pd.DataFrame(data)
	data.columns = ["time","value","actual_anomaly"]

def get_anomalies_by_algo(measurement_algo):
	query1 = 'select value from ' + measurement_algo
	result1 = client.query(query1)
	anomalies = result1.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	anomalies = [[point[0] ,point[1]] for point in anomalies]
	anomalies = pd.DataFrame(anomalies)
	anomalies.columns = ["time","value"]
	return anomalies
def get_auc_score(measurement_algo):
	anomalies=merged=fpr=tpr=thresholds=auc_score = None
	anomalies = get_anomalies_by_algo(measurement_algo)
	merged=pd.merge(data,anomalies , how='left', on="time", left_on=None, right_on=None,left_index=False, right_index=False, sort=True, suffixes=('_x', '_y'), copy=True, indicator=True)
	merged['detected_anomaly'] = merged.apply(lambda x: 1 if x['_merge']=="both" else 0 , axis=1)
	merged = merged[['time','value_x' , 'actual_anomaly' , 'detected_anomaly']]
	fpr, tpr, thresholds = roc_curve(merged['actual_anomaly'].values , merged['detected_anomaly'].values)
	auc_score=auc(fpr,tpr)
	return auc_score

def main():
	dataset_tag = measurement[0: measurement.find( "_")]
	filename  = '../../data/auc_' + dataset_tag + '.csv'
	file =open(filename , 'a')
	if os.stat(filename).st_size == 0:
		file =open(filename , 'w')
		file.write('Algorithms' + ',' +'AUC Score on ' + dataset_tag + ' dataset'+ '\n')
	file.write('Running on :' + str(datetime.now())+ '\n')
	# Step 1 Read Data from Influx
	read_main_data_from_influx()
	# Algorithms measurement names list 
	algorithms_measurement_names = [ "elliptic_envlope", "expose", "kalman","lof","skyline","tsoutlier", "twitter","arima","arma","WindowedGaussian"]
	# Step 2 Read the detected anomalies by each algorithm and compute AUC score
	for algo in algorithms_measurement_names:
		try:
			auc_score = get_auc_score(algo)
		except e:
			print "Error for " + algo + " -----> " + str(e)
		print algo , " : " , auc_score
		file.write( algo + "," + str(auc_score) + "\n")

if __name__ == '__main__':
	main()

#libraries
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.metrics import roc_curve, auc
import matplotlib
# Force matplotlib to not use any Xwindows backend.
matplotlib.use('Agg')
import matplotlib.pyplot as plt
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
	query1 = 'select value,score from ' + measurement_algo
	result1 = client.query(query1)
	anomalies = result1.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	anomalies = [[point[0] ,point[1],point[2]] for point in anomalies]
	anomalies = pd.DataFrame(anomalies)
	anomalies.columns = ["time","value","score"]
	return anomalies
def get_auc_score(measurement_algo):
	anomalies=merged=fpr=tpr=thresholds=auc_score = None
	anomalies = get_anomalies_by_algo(measurement_algo)
	merged=pd.merge(data,anomalies , how='inner', on="time", left_on=None, right_on=None,left_index=False, right_index=False, sort=True, suffixes=('_x', '_y'), copy=True, indicator=True)
#	merged['detected_anomaly'] = merged.apply(lambda x: 1 if x['_merge']=="both" else 0 , axis=1)

	merged['detected_anomaly'] = merged['score']
	merged = merged[['time','value_x' , 'actual_anomaly' , 'detected_anomaly']]
	fpr, tpr, thresholds = roc_curve(merged['actual_anomaly'].values , merged['detected_anomaly'].values)
	auc_score=auc(fpr,tpr)
	return fpr , tpr , auc_score
def create_roc_curve(algo , dataset_tag , fpr , tpr, roc_auc,col ):
	plt.title('Receiver Operating Characteristic for %s'%(dataset_tag))
	plt.plot(fpr , tpr, 'b',label='AUC for %s = %0.2f'% (algo , roc_auc), color=col) 
	plt.legend(loc='lower right', prop={'size':8})
	plt.plot([0,1],[0,1],'r--')
	plt.xlim([-0.1,1.2])
	plt.ylim([-0.1,1.2])
	plt.ylabel('True Positive Rate')
	plt.xlabel('False Positive Rate')
	plt.savefig('roc_curves_for_%s.jpg' %(dataset_tag) , type='jpg')

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
	colors = ['red' , 'blue' , 'black' , 'green' , 'brown' , 'yellow' , 'orange' , 'pink' , 'purple' , 'magenta']
	# Step 2 Read the detected anomalies by each algorithm and compute AUC score
	for pos , algo in enumerate(algorithms_measurement_names):
		if algo != "expose":
			continue
		try:
			fpr , tpr  , auc_score = get_auc_score(algo)
		except e:	
			print "Error for " + algo + " -----> " + str(e)
		create_roc_curve(algo , dataset_tag , fpr , tpr,auc_score , colors[pos] )
#		print algo , " : " , auc_score
#		file.write( algo + "," + str(auc_score) + "\n")

if __name__ == '__main__':
	main()

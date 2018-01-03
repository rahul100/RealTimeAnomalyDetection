# libraries
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.covariance import EllipticEnvelope
import sys
from datetime import datetime
import json
import time
import argparse
# influx
from influxdb import InfluxDBClient

def parse_args():
	parser = argparse.ArgumentParser( description='Elliptical Envelope arguments')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi', help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='nyc_taxi_data', help='Measurement Name')
	parser.add_argument('--outlier_fraction', type=float, required=False, default=0.1, help='outlier fraction')
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
outliers_fraction = args.outlier_fraction # Lesser value lesser number of outliers
# Create Elliptic Envelope object
clf = EllipticEnvelope(contamination=args.outlier_fraction) # Contanimation is how much percentage of the data is anomaly
min1= 0 
max1=0 
while(1):
	start_time= time.time()
	query = 'select value from ' + measurement + ' where time > now() - 40s;'
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [[point[0] ,point[1]] for point in data]
	data = pd.DataFrame(data)
	data.columns = ["time","value"]
	data_val = data[["value"]]
	#Convert pandas to numpy matrix
	X=data_val.as_matrix()
	#fit the model   
	clf.fit(X)
	y_pred = clf.decision_function(X).ravel()
	if min(y_pred) < min1 :
		min1 = min(y_pred)
	if max(y_pred) >  max1:
		max1 = max(y_pred)
	anomalies=pd.DataFrame(y_pred)
	anomalies.columns = ["score"]
	anomalies['score_norm'] = 1.0 - ((anomalies['score'] - min1 ) / (max1 - min1) )
	anomalies['anomalies_flg'] = anomalies['score_norm'] >= 0.9
	final1 = pd.concat([data, anomalies], axis=1)
	final1.columns = ["time","value","score" , "score_norm" , "anomalies_flg"] 
	# We are only interested in only the latest point
	final1= final1[-1:]
	# Push the final anomalies to grafana
	for i, row in final1.iterrows():
		inputData = row.to_dict()
		if (inputData['anomalies_flg'] == True):
			anomaly = 'Y'
		else:
			anomaly = 'N'
		temp = {"value" : inputData["value"] , "anomalyScore" : inputData["score_norm"] }
		json_body = [{
				   "measurement": "elliptic_envlope",
				   "tags": {
				   "anomaly": anomaly
				},
			   "time": inputData["time"],
				   "fields": temp
				}
					]
		client.write_points(json_body)
	end_time = time.time()
	time_elapsed = end_time - start_time
	if time_elapsed > 0 and time_elapsed < 1:
		time.sleep((1.0  - time_elapsed))

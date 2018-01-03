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
	parser.add_argument('--outlier_fraction', type=float, required=False, default=0.01, help='outlier fraction')
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
clf = EllipticEnvelope(contamination=.1)
while(1):
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
	#print  y_pred
	#create threhold from pred_data for outlier fraction
	threshold = stats.scoreatpercentile(y_pred,100 * outliers_fraction)
	#Tag outliers and normal data
	y_pred = y_pred > -0.5
	anomalies=pd.DataFrame(y_pred)
	final1 = pd.concat([data, anomalies], axis=1)
	final1.columns = ["time","value","normal"]
	final = final1[final1["normal"]==False]
	# Push the final anomalies to grafana
	for i, row in final.iterrows():
		inputData = row.to_dict()
		temp = {"value" : inputData["value"]}
		json_body = [{
				   "measurement": "elliptic_envlope",
				   "tags": {
				   "anomaly": "Y"
				},
				   "time": inputData["time"],
				   "fields": temp
				}
					]
		client.write_points(json_body)
		time.sleep(1.0)

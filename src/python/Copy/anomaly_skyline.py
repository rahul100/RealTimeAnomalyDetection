# libraries
import numpy as np
import pandas as pd
from scipy import stats
import sys
from datetime import datetime
import json 
import time
import argparse
# influx
from influxdb import InfluxDBClient
from algos_skyline import *
# influx configuration
def parse_args():
	parser = argparse.ArgumentParser(description='Skyline algorithm arguments')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi', help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='nyc_taxi_data', help='Measurement Name')
	parser.add_argument('--threshold', type=int, required=False, default=2, help='threshold')
	return parser.parse_args()
args = parse_args()
user = 'root'
password = 'root'
dbname = args.db
measurement = args.measurement
dbuser = 'root'
dbuser_password = 'root'
client = InfluxDBClient('10.34.12.155', '8086', user, password, dbname)

# ----------------------------Parameters--------------------------

recordCount = 0
algorithms =[median_absolute_deviation,
			#stddev_from_average,
			#stddev_from_moving_average,
			#mean_subtraction_cumulation,
			least_squares,
			histogram_bins]
anomaly_score_threshold = args.threshold
while(1):
	timeseries = []
	query = 'select value from ' + measurement + ' where time > now() - 10s;'
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [[point[0] ,point[1]] for point in data]
	data = pd.DataFrame(data)
	data.columns = ["time","value"]
	count = 0

	for i, row in data.iterrows():
		inputData = row.to_dict()
		score = 0.0
		inputRow = [datetime.strptime(inputData["time"],"%Y-%m-%dT%H:%M:%SZ"), inputData["value"]]
		timeseries.append(inputRow)
		for algo in algorithms:
			score += algo(timeseries)
		if(score >= anomaly_score_threshold):
			temp = {"value" : inputData["value"]}
			json_body = [
				{
				"measurement": "skyline",
				"tags": {
				"anomaly": "Y"
					},
				"time": inputData["time"],
				"fields": temp
					}
					 ]	
			client.write_points(json_body)

	


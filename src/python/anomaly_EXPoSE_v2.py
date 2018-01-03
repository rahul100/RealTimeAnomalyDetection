# libraries
import numpy as np
import pandas as pd
from sklearn.kernel_approximation import RBFSampler
import sys
from datetime import datetime
import json
import time
import argparse
# influx
from influxdb import InfluxDBClient

def parse_args():
	parser = argparse.ArgumentParser( description='Expose arguments')
	parser.add_argument('--db', type=str, required=True, default='', help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='', help='Measurement Name')
	parser.add_argument('--threshold', type=float, required=False, default=0.95, help='threshold')
	parser.add_argument('--decay', type=float, required=False, default=0.005,help='decay')
	parser.add_argument('--chunksize', type=int, required=False, default=40,help='chunksize')
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


# ----------------------------Variables----------------------------
kernel = None
previousExposeModel = []
timestep = 0
# ----------------------------Parameters--------------------------
kernel = RBFSampler(gamma=0.5,n_components=20000,random_state=290)
decay = args.decay
anomaly_score_threshold = args.threshold
chunksize = args.chunksize
while(1):
	start_time  = time.time()
	timestep = 0 
	query = 'select value,timestamp from ' + measurement + ' where time > now() - ' + str(chunksize)  + 's;'
	#print query
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [[point[0] ,point[1], point[2]] for point in data]
	data = pd.DataFrame(data)
	data.columns = ["time","value", "timestamp"]
	for i, row in data.iterrows():
		inputData = row.to_dict()
		inputFeature = kernel.fit_transform(np.array([[inputData["value"]]]))
		if timestep == 0:
			exposeModel = inputFeature
		else:
			exposeModel = ((decay * inputFeature) + (1 - decay) * previousExposeModel)
		previousExposeModel = exposeModel
		anomalyScore = np.asscalar(1 - np.inner(inputFeature, exposeModel))
#		print anomalyScore
		timestep += 1
		outputRow = list(row) + list([anomalyScore])
		if i==(len(data)-1):
			print outputRow
			if(anomalyScore > anomaly_score_threshold):
				anomaly = "Y"
			else:
				anomaly = "N"
			current_time = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
			temp = {"value" : inputData["value"], "anomalyScore" : anomalyScore}
			json_body = [
				{
				"measurement": "expose",
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
	if (time_elapsed < 1.0):
		time.sleep((1.0-time_elapsed))




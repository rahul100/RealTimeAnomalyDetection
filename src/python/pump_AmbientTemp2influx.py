import argparse
import pandas as pd
import pickle as pl
import numpy as np
import json
import time
from influxdb import InfluxDBClient
from datetime import datetime

def main(db , measurement, host='10.34.12.155', port=8086):
	# Read Data
	A = pd.read_csv("../data/ambient_temperature_system_failure.csv")
	data = np.array(A['value'])
		
	# InfluxDB
	user = 'root'
	password = 'root'
	dbname =  db
	#dbuser = 'root'
	#dbuser_password = 'my_secret_password'
	#query = 'select value from cpu_load_short;'
	client = InfluxDBClient(host, port, user, password, dbname)
	client.create_database(dbname)
	#print host, port, user, password, dbname
		
	# Insert data in every 1 second of rideid
	count = 0 
	while(count < 1):
		for i in range(data.shape[0]):
			current_time = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
			pass_num = data
			temp = A.iloc[i,0:2].to_json(orient='index')
			anomaly = A.iloc[i,2]
			temp = json.loads(temp)
			json_body = [
				{
				"measurement": measurement,
				"tags": {
				"anomaly": anomaly,
						},
				"time": current_time,
				"fields": temp
					}
					]
			print json_body
			client.write_points(json_body)
			time.sleep(1)
		count+=1
def parse_args():
	parser = argparse.ArgumentParser(description='example code to play with InfluxDB')
	parser.add_argument('--host', type=str, required=False, default='10.34.12.155', help='hostname of InfluxDB http API')
	parser.add_argument('--port', type=int, required=False, default=8086, help='port of InfluxDB http API')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi', help='Influxdb name')
        parser.add_argument('--measurement', type=str, required=True, default='nyc_taxi_data', help='Measurement Name')
	return parser.parse_args()


if __name__ == '__main__':
	args = parse_args()
	main(db=args.db, measurement=args.measurement, host=args.host, port=args.port)

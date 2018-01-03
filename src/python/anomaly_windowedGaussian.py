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
import math
# influx configuration

def parse_args():
	parser = argparse.ArgumentParser(description='Windowed gaussian arguments')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi', help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='nyctaxi_temp_data', help='Measurement Name')
	parser.add_argument('--threshold', type=float, required=False, default=0.98, help='threshold')
	parser.add_argument('--window', type=int, required=False, default=500, help='sliding window')
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
windowSize = args.window
windowData = []
stepBuffer = []
stepSize = 100
mean = 0
std = 1
anomaly_score_threshold = args.threshold # 0.98 by default
def normalProbability(x, mean, std):
	"""
	Given the normal distribution specified by the mean and standard deviation
	args, return the probability of getting samples > x. This is the
	Q-function: the tail probability of the normal distribution.
	"""
	if x < mean:
		# Gaussian is symmetrical around mean, so flip to get the tail probability
		xp = 2*mean - x
		return 1.0 - normalProbability(xp, mean, std)

		# Calculate the Q function with the complementary error function, explained
		# here: http://www.gaussianwaves.com/2012/07/q-function-and-error-functions
	z = (x - mean) / std
	return 0.5 * math.erfc(z/math.sqrt(2))

def updateWindow():
	global mean , std , windowData
	mean = np.mean(windowData)
#	print mean
	std = np.std(windowData)
	if std == 0.0:
		std = 0.000001
#	print "sd" ,  std
#	print "len window " , len(windowData)

while(1):
	start_time = time.time()
	query = 'select last(value) from ' + measurement + ' where time > now() - 100s;'
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [[point[0] ,point[1]] for point in data]
	data = pd.DataFrame(data)
	data.columns = ["time","value"]
	count = 0


	for i, row in data.iterrows():
		inputData = row.to_dict()
		anomalyScore = 0.0
		inputValue = inputData["value"]
		if len(windowData) > 0:
			anomalyScore = 1 - normalProbability(inputValue, mean, std)
			if (normalProbability(inputValue , mean , std) < .0001):
				print inputValue
				print mean
				print std
				print "----------------------------------------------"
		if len(windowData) < windowSize:
			windowData.append(inputValue)
			updateWindow()
		else:
			stepBuffer.append(inputValue)
			if len(stepBuffer) == stepSize:
				# slide window forward by stepSize
				windowData = windowData[stepSize:]
				windowData.extend(stepBuffer)
				# reset stepBuffer
				stepBuffer = []
				updateWindow()
		if(anomalyScore >= anomaly_score_threshold):
			anomaly="Y"
		else:
			anomaly="N"

		#	print anomalyScore
		temp = {"value" : inputData["value"] , "anomalyScore" : anomalyScore}
		json_body =[
			{
			"measurement": "WindowedGaussian",
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
			time.sleep(1 - time_elapsed)

	


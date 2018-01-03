'''
==================================
Kalman Filter tracking a sine wave
==================================
This example shows how to use the Kalman Filter for state estimation.
In this example, we generate a fake target trajectory using a sine wave.
Instead of observing those positions exactly, we observe the position plus some
random noise.  We then use a Kalman Filter to estimate the velocity of the
system as well.
The figure drawn illustrates the observations, and the position and velocity
estimates predicted by the Kalman Smoother.
'''
import numpy as np
import pylab as pl
import pandas as pd
#import matplotlib.pyplot as plt
from datetime import datetime
from pykalman import KalmanFilter
import math
import argparse
# influx
import json
import time
from influxdb import InfluxDBClient

def parse_args():
	parser = argparse.ArgumentParser(description='kalman arguments')
	parser.add_argument('--db', type=str, required=True, default='nyctaxi',help='Influxdb name')
	parser.add_argument('--measurement', type=str, required=True, default='nyctaxi_temp_data',help='Measurement Name')
	parser.add_argument('--threshold', type=float, required=False, default=2.0,help='threshold')
	parser.add_argument('--max', type=int, required=False, default=30000, help='max value for the dataset in integer')
	return parser.parse_args()
args = parse_args()



# influx configuration
user = 'root'
password = 'root'
dbname = args.db
measurement = args.measurement
dbuser = 'yasu'
dbuser_password = 'my_secret_password'
client = InfluxDBClient('10.34.12.155', '8086', user, password, dbname)

# endless analysis
while(1):
	
	# query to get data
	query = 'select value from ' + measurement + ' where time > now() - 40s;'
	result = client.query(query)
	data = result.raw[u'series'][0]['values'] #search "influxdb.resultset.ResultSet"
	data = [point[1] for point in data]
	data = np.array(data)
	
	# specify the time axis
	y_obs_t  = data[:-1]
	y_obs_t1 = data[-1]
#    print y_obs_t1
	T_obs_t  = range(len(y_obs_t))
	T_obs_t1= len(T_obs_t)

	# Kalman Filter model
	deltaT = 1.0 # This can be 1.0 for the over 1.0 sampling case, in Yasu's understanding
	try:
	 kf = KalmanFilter(transition_matrices=np.array([[1, deltaT], [0, 1]]),
					  transition_covariance=0.01 * np.eye(2))
	except:
		print "Problem running Kalman Filter algorithm"
	# filter : online, recursively
	# smooth : batch process
	# Computation Cost O(Td^3) in this case, d = 2, 
	(filtered_state_means, filtered_state_covariances) = kf.filter(y_obs_t)
	#(smoothed_state_means, smoothed_state_covariances) = kf.smooth(y_obs)
#    print filtered_state_covariances
	#print smoothed_state_covariances

	# Prediction
	means, covariances = kf.em(y_obs_t).filter(y_obs_t)
	new_measurement = data[len(y_obs_t)]
	next_mean, next_covariance = kf.filter_update(
		means[-1],
		covariances[-1],
		new_measurement
	)
	y_pred_t  = means[:,0]
	y_pred_t1 = next_mean[0]
	
	# update influxDB
	std_t1 = math.sqrt(next_covariance[0][0])
	thres  = args.threshold #2.0  Parameters... but some theory is here.
#    print abs(y_pred_t1 - y_obs_t1)
#    print thres*std_t1
#    print "---------------------------------------------------------------"
	if abs(y_pred_t1 - y_obs_t1) >= thres * std_t1:
		current_time = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
		temp = {"value" : y_obs_t1}
		json_body = [
			{
				"measurement": "kalman",
				"tags": {
					"host": "server01",
					"region": "us-west"
				},
				"time": current_time,
				"fields": temp
			}
		]
		client.write_points(json_body)
	
	# DEBUG : check graph
	# Plot lines for the observations without noise, the estimated position of the
	# target before fitting, and the estimated position after fitting.
	#pl.figure(figsize=(10, 10))
#    pl.clf()
#    obs_scatter = pl.scatter(T_obs_t, y_obs_t,
#                             marker='x',
#                             color='black',
#                             label='real sensor value')
	
#    pred_position_line = pl.plot(T_obs_t, y_pred_t,
#                                 linestyle='-',
#                                 marker='o',
#                                 color='magenta',
#                                 label='past predicted values')
	
	#plt.errorbar(X, means, yerr=covariances)
#    true_scatter = pl.scatter(T_obs_t1, y_obs_t1,
#                              marker='x',
#                              color='blue',
#                              label='real sensor value at t+1')
	
#    prediction_scatter = pl.scatter(T_obs_t1, y_pred_t1,
#                                    marker='o',
#                                    color='black',
#                                    label='prediction value at t+1')

#    prediction_scatter = pl.errorbar(T_obs_t1, y_pred_t1,
#                                     yerr=math.sqrt(next_covariance[0][0]),
#                                     color = 'red',
#                                     fmt='o',
#                                     label='predicted value at t+1'
#    )
	
	#velocity_line = pl.plot(X, states_pred[:, 1],
	#                        linestyle='-', marker='o', color='g',
	#                        label='velocity est.')
	
#    pl.legend(loc='lower left')
#    pl.grid()
	#pl.xlim(xmin=X_obs[0], xmax=pred_X)
	#pl.xlabel('time')
	#pl.show()
#    pl.pause(.01)
	
	time.sleep(1.0)
	
	
# # You can use the Kalman Filter immediately without fitting, but its estimates
# # may not be as good as if you fit first.
# #states_pred = kf.em(observations).smooth(observations)[0]
# #print('fitted model: {0}'.format(kf))
# 
# # Plot lines for the observations without noise, the estimated position of the
# # target before fitting, and the estimated position after fitting.
# #pl.figure(figsize=(10, 10))
# print X_obs
# print pred_X
# obs_scatter = pl.scatter(X_obs, observations,
#                          marker='x',
#                          color='b',
#                          label='observations')
# 
# print means
# position_line = pl.plot(X_obs, means[:,0],
#                         linestyle='-',
#                         marker='o',
#                         color='r',
#                         label='position est.')
# 
# #plt.errorbar(X, means, yerr=covariances)
# true_scatter = pl.scatter(pred_X, pred_t1,
#                           marker='x',
#                           color='g',
#                           label='true value at t+1')
# 
# prediction_scatter = pl.scatter(pred_X, next_mean[0],
#                                 marker='o',
#                                 color='black',
#                                 label='prediction value at t+1')
# 
# #velocity_line = pl.plot(X, states_pred[:, 1],
# #                        linestyle='-', marker='o', color='g',
# #                        label='velocity est.')
# 
# pl.legend(loc='lower right')
# pl.xlim(xmin=X_obs[0], xmax=pred_X)
# #pl.xlabel('time')
# pl.show()
#     
#     
#     
	
	

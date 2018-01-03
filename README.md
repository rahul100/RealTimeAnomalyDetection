# RealTimeAnomalyDetection
This is project to find anomalies in real time data using multiple algorithms and finally a voting mechanism was created to decide whether or not the the data point represented anomaly.

# Technology Stack
R and Python were used for creating the algorithms.The pipeline of the system is built in python.  
InfluxDB is used to store incoming realtime data.Graphana is used as the tool for visualization.

# About the data:
The data represents the various measurements taken from the human body like temp,eeg,ecg etc in realtime via t-shirt with various sensors attached. All these readings are transmitted to a server which predicts whether there are any anomalous signs in this data.

The various algorithms used in this project are as below:

- ARIMA (Auto Recursive Integrated Moving Averages) algorithm
- ARMA (Auto Recursive Moving Averages) algorithm
- Elliptic Envelope
- Kalman Filter
- ExPOse Algorithm
- Twitter Anomaly detection using SHED algorithm
- Bayesian anomaly detection
- LOF (Local Outlier Function ) anomaly detection
- TS Outliers ( R library)
- Skyline Algoritm
- Windowed Gaussian


Evaluation

The evaluation of the data was done using ROC curves and AUC as the parameter. Accuracy TPR and FPR were the other evalution metrics used.

PS: Using the scrpits requires InfluxDB setup and then using scripts in the repository to pump data into the influxDB

If you have any ideas or you need to understand any piece , please write to me on the below email address:
rahulagarwal.iet@gmail.com







echo "Running the NYC_TAXI anomaly detection demo"
echo "Step 1: Pumping data into influxdb"

/usr/bin/python2.7 ../src/python/pump_NYtaxi2influx-2.py --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/nyc_taxi_pump.log 2>&1 &
pump_pid=$!
sleep 60
#echo $pump_pid
echo "Step 2: RUnning Anomaly detection algorithms"
echo "Kalman Filter  anomaly detection"
/usr/bin/python2.7 ../src/python/anomaly_kalman.py --db="nyctaxi" --measurement="nyc_taxi_data" --threshold=2.0 > ../log/anomaly_kalman_nyc.log 2>&1 &
kalman_pid=$!
echo "Arma anomaly detection"
Rscript ../src/rscript/Arma_AD/anomaly_arma_nyctaxi.R --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/anomaly_arma_nyc.log 2>&1 &
arma_pid=$!
echo "Arima anomaly detection"
Rscript ../src/rscript/Arima_AD/anomaly_arima_nyctaxi.R --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/anomaly_arima_nyc.log 2>&1 &
arima_pid=$!
echo "LOF anomaly detection"
Rscript ../src/rscript/Lof_AD/anomaly_lof_nyctaxi.R --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/anomaly_lof_nyc.log 2>&1 &
lof_pid=$!
echo "Twitter's anomaly detection"
Rscript ../src/rscript/Twitter_AD/anomaly_twitter_nyctaxi.R --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/anomaly_twitter_nyc.log 2>&1 &
twitter_pid=$!
echo "Elliptic Envelope's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_elliptic_envlope.py --db="nyctaxi" --measurement="nyc_taxi_data" --outlier_fraction=0.1 > ../log/anomaly_elliptic_nyc.log 2>&1 & 
elliptic_pid=$!
echo "Expose's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_EXPoSE.py --db='nyctaxi' --measurement='nyc_taxi_data' --threshold=0.997 --decay=0.005 > ../log/anomaly_expose_nyc.log 2>&1 &
expose_pid=$!
echo "Gaussian's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_windowedGaussian.py --db="nyctaxi" --measurement="nyc_taxi_data" --threshold=0.98 --window=500 > ../log/anomaly_gaussian_nyc.log 2>&1 &
gaussian_pid=$!
echo "Tsoutlier's Anomaly Detection"
Rscript ../src/rscript/Tsoutlier_AD/anomaly_tsoutliers_nyctaxi.R --db="nyctaxi" --measurement="nyc_taxi_data" > ../log/anomaly_tsoutliers_nyc.log 2>&1 &
tsoutlier_pid=$!
echo "Skyline's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_skyline.py --db="nyctaxi" --measurement="nyc_taxi_data" --threshold=2 > ../log/anomaly_skyline_nyc.log 2>&1 &
skyline_pid=$!
while true; do
    read -p "Do you wish to stop the demo?" yn
    case $yn in
        [Yy] ) kill -9 $pump_pid;kill -9 $kalman_pid;kill -9 $arma_pid;kill -9 $arima_pid;kill -9 $lof_pid;kill -9 $twitter_pid;kill -9 $elliptic_pid;kill -9 $expose_pid;kill -9 $gaussian_pid;kill -9 $tsoutlier_pid;kill -9 $skyline_pid;exit;;
        [Nn] ) sleep 30;;
        *) echo "Please answer yes or no.";;
    esac
done



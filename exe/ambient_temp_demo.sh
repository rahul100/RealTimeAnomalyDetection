echo "Running the Ambient temp anomaly detection demo"
echo "Step 1: Pumping data into influxdb"
/usr/bin/python2.7 ../src/python/pump_AmbientTemp2influx.py --db="ambient_temp_real_time" --measurement="ambient_temp_data" >> ../log/ambient_temp_pump.log 2>&1 &
pump_pid=$!
sleep 60
#echo $pump_pid
echo "Step 2: Running Anomaly detection algorithms"
echo "Kalman Filter  anomaly detection"
/usr/bin/python2.7 ../src/python/anomaly_kalman.py --db="ambient_temp_real_time" --measurement="ambient_temp_data" --threshold=0.5 > ../log/anomaly_kalman_ambient.log 2>&1 &
kalman_pid=$!
echo "Arma anomaly detection"
Rscript ../src/rscript/Arma_AD/anomaly_arma_ambient.R --db="ambient_temp_real_time" --measurement="ambient_temp_data" > ../log/anomaly_arma_ambient.log 2>&1 &
arma_pid=$!
echo "Arima anomaly detection"
Rscript ../src/rscript/Arima_AD/anomaly_arima_ambient.R --db="ambient_temp_real_time" --measurement="ambient_temp_data" > ../log/anomaly_arima_ambient.log 2>&1 &
arima_pid=$!
echo "LOF anomaly detection"
Rscript ../src/rscript/Lof_AD/anomaly_lof_ambient.R --db="ambient_temp_real_time" --measurement="ambient_temp_data" > ../log/anomaly_lof_ambient.log 2>&1 &
lof_pid=$!
echo "Twitter's anomaly detection"
Rscript ../src/rscript/Twitter_AD/anomaly_twitter_ambient.R --db="ambient_temp_real_time" --measurement="ambient_temp_data" > ../log/anomaly_twitter_ambient.log 2>&1 &
twitter_pid=$!
echo "Elliptic Envelope's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_elliptic_envlope.py --db="ambient_temp_real_time" --measurement="ambient_temp_data" --outlier_fraction=0.1 > ../log/anomaly_elliptic_ambient.log 2>&1 & 
elliptic_pid=$!
echo "Expose's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_EXPoSE.py --db='ambient_temp_real_time' --measurement='ambient_temp_data' --threshold=0.95 --decay=0.005 > ../log/anomaly_expose_ambient.log 2>&1 &
expose_pid=$!
echo "Gaussian's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_windowedGaussian.py --db="ambient_temp_real_time" --measurement="ambient_temp_data" --threshold=0.98 --window=500 > ../log/anomaly_gaussian_ambient.log 2>&1 &
gaussian_pid=$!
echo "Tsoutlier's Anomaly Detection"
Rscript ../src/rscript/Tsoutlier_AD/anomaly_tsoutliers_ambient.R --db="ambient_temp_real_time" --measurement="ambient_temp_data" > ../log/anomaly_tsoutliers_ambient.log 2>&1 &
tsoutlier_pid=$!
echo "Skyline's Anomaly Detection"
/usr/bin/python2.7 ../src/python/anomaly_skyline.py --db="ambient_temp_real_time" --measurement="ambient_temp_data" --threshold=2 > ../log/anomaly_skyline_ambient.log 2>&1 &
skyline_pid=$!
while true; do
    read -p "Do you wish to stop the demo?" yn
    case $yn in
        [Yy] ) kill -9 $pump_pid;kill -9 $kalman_pid;kill -9 $arma_pid;kill -9 $arima_pid;kill -9 $lof_pid;kill -9 $twitter_pid;kill -9 $elliptic_pid;kill -9 $expose_pid;kill -9 $gaussian_pid;kill -9 $tsoutlier_pid;kill -9 $skyline_pid;exit;;
        [Nn] ) sleep 30;;
        *) echo "Please answer yes or no.";;
    esac
done



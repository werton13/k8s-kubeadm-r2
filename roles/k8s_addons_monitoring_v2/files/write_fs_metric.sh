#!/bin/bash 
# writed by SPopov 
#v.1.1

# Save the original IFS 
OLD_IFS="$IFS" 
TIMESTAMP=$(date +%s) 
IFS=$'\n' 
 
#TMP_FILE="/tmp/search_raw_tmp"  #TO_REMOVE 
TMP_VARSIZE_FILE="/tmp/search_vardirs_raw_tmp" 
TMP_VARLIB_CONTENT_FILE="/tmp/varlib_content_raw_tmp" 
TMP_VARLIB_SNAPSHOTS_FILE="/tmp/varlib_snapshots_raw_tmp" 
METRIC_VARSIZE_PATH="/var/lib/prometheus_metrics_txt/var_dirs_sizes.prom" 
METRIC_VARLIB_CONTENT_PATH="/var/lib/prometheus_metrics_txt/varlib_content_sizes.prom" 
METRIC_VARLIB_SNAPSHOTS_PATH="/var/lib/prometheus_metrics_txt/varlib_snapshot_sizes.prom" 
 
# --------------------------------------------------------------------------------------------------- 
# WRITE METRICS FOR DIRS SIZE INSIDE /VAR  wo /var/lib 
rm -rf $TMP_VARSIZE_FILE 
du -x --max-depth=0 /var/* >> $TMP_VARSIZE_FILE 
cat  /dev/null > $METRIC_VARSIZE_PATH 
for line in $(cat $TMP_VARSIZE_FILE); do 
    path="$(echo $line | awk '{print $2}')" 
    size="$(echo $line | awk '{print $1}')" 
    echo "var_dirs_size{file=\"$path\"} $size" >> $METRIC_VARSIZE_PATH 
done 
 
# --------------------------------------------------------------------------------------------------- 
# WRITE METRICS FOR DIRS INSIDE /var/lib/containerd/io.containerd.content.v1.content 
# currently containers image ownership information not provided 
rm -rf $TMP_VARLIB_CONTENT_FILE 
du -x --max-depth=0 /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/* >> $TMP_VARLIB_CONTENT_FILE 
cat  /dev/null > $METRIC_VARLIB_CONTENT_PATH 
for line in $(cat $TMP_VARLIB_CONTENT_FILE); do 
    path="$(echo $line | awk '{print $2}')" 
    size="$(echo $line | awk '{print $1}')" 
    echo "varlib_content_file_size{file=\"$path\"} $size" >> $METRIC_VARLIB_CONTENT_PATH 
done 
 
 
# --------------------------------------------------------------------------------------------------- 
#  WRITE METRICS FOR DIRS INSIDE /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/ 
 
 
SEARCH_PATH="/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/" 
#main 
# Delete tmp file 
#echo "removing old temp_file" 
rm -rf $TMP_VARLIB_SNAPSHOTS_FILE 
#ensure file is empty 
#head -n 5 $TMP_FILE 
#sleep 5 
 
#echo "getting files sizes in search directory" 
find $SEARCH_PATH -maxdepth 1 -type d -exec  du --max-depth=0 {} >> $TMP_VARLIB_SNAPSHOTS_FILE  \;  
#echo "processing temp file to generate metrics file in prometheus format" 
cat  /dev/null > $METRIC_VARLIB_SNAPSHOTS_PATH 
 
for line in $(cat $TMP_VARLIB_SNAPSHOTS_FILE); do 
#    echo "varlib_snapshots_file_size{file=\"$(echo $line | awk '{print $2}')\"} $(echo $line | awk '{print $1}') $TIMESTAMP" >> /var/lib/prometheus_metrics_txt/varlib_snapshot_sizes.prom 
     path="$(echo $line | awk '{print $2}')" 
     size="$(echo $line | awk '{print $1}')" 
#    echo "$path" 
     #GET CONTAINER ID IN WHICH OUR SEARCH_PATH IS MOUNTED 
 
     # SOME SEARCH_PATHs ARE MOUNTED IN MORE THEN ONE CONTAINER 
     # USUALLY THESE CONTAINERS BELONG TO THE SAME POD 
     # SO WE CAN GET ONLY FIRST CONTAINER_ID FROM THE "mount" COMMAND OUTPUT TO FIND A RELATED  POD 
     cont_id_arr=$(mount | grep -w "$path" | grep  -oP "(\/run\/containerd\/io\.containerd\.runtime\.v2\.task\/k8s\.io)(\/)\K(.{64})" | grep -v -e "^$" ) 
     cont_id=$(echo $cont_id_arr | cut -d" " -f1) 
     # echo $cont_id 
 
     if [[ ! -z "$cont_id" ]]; then 
         echo "PATH: $path" 
         echo "CONTAINER_ID:  $cont_id" 
#        #searching podSandboxId using known $cont_id 
         pod_id=$(crictl ps -o json | jq   --arg cont_id_jq $cont_id  '.containers.[] | select(.id==$cont_id_jq).podSandboxId'| tr -d '"')  >/dev/null 
          
         #searching pod name via it pod_id 
         echo "POD_ID: $pod_id" 
         if [[ ! -z "$pod_id" ]]; then 
           echo   "trying to query a pod name with POD_ID: $pod_id" 
           # crictl pods -o json | jq --arg pod_id_jq $pod_id '.items[]  | select(.id==$pod_id_jq) | .id'  
           pod_name=$(crictl pods --no-trunc --id  $pod_id -o json  | jq '.items[] | .metadata.name'| tr -d '"') 
           echo "varlib_snapshots_file_size{file=\"$path\",pod_name=\"$pod_name\"} $size" >> $METRIC_VARLIB_SNAPSHOTS_PATH 
 
           #   echo $pod_name 
           echo "-----" 
         fi
     else 
         # No container ID found - snapshot not currently mounted
         echo "varlib_snapshots_file_size{file=\"$path\",pod_name=\"not_mounted\"} $size" >> $METRIC_VARLIB_SNAPSHOTS_PATH 
         echo "PATH: $path - NOT MOUNTED"       
     fi  
done 
# Restore the original IFS 
IFS="$OLD_IFS"

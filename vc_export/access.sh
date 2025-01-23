#!/bin/bash

# Create CSV header
echo "Pattern,Average Time (seconds)" > results.csv

# Process each directory
while read PATH_PREFIX; do
    # Extract pattern (W-1-N) from path
    pattern=$(echo $PATH_PREFIX | grep -o 'W-1-[0-9]\+')
    
    # Extract number of processes from path suffix
    num_processes=$(echo $PATH_PREFIX | awk -F'-' '{print $NF}')
    sum=0

    echo "Processing $PATH_PREFIX..."

    for i in $(seq 0 $(($num_processes - 1))); do
        # Extract timestamps
        client_timestamp=$(grep "Sending request:" ${PATH_PREFIX}/client/process_${i}.log | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{6\}')
        server_timestamp=$(grep "GET /http_server/send-object.php?ID=${i}[^0-9]" ${PATH_PREFIX}/server/access_log | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{6\}')

        # Skip if timestamps not found
        if [ -z "$client_timestamp" ] || [ -z "$server_timestamp" ]; then
            echo "Warning: Could not find timestamps for process $i in $PATH_PREFIX"
            continue
        fi

        # Extract hours, minutes, seconds, and microseconds separately
        client_hour=$(echo $client_timestamp | cut -d: -f1)
        client_min=$(echo $client_timestamp | cut -d: -f2)
        client_sec=$(echo $client_timestamp | cut -d: -f3 | cut -d. -f1)
        client_micro=$(echo $client_timestamp | cut -d. -f2)

        server_hour=$(echo $server_timestamp | cut -d: -f1)
        server_min=$(echo $server_timestamp | cut -d: -f2)
        server_sec=$(echo $server_timestamp | cut -d: -f3 | cut -d. -f1)
        server_micro=$(echo $server_timestamp | cut -d. -f2)

        # Calculate total microseconds for each timestamp
        client_total=$(echo "$client_hour * 3600000000 + $client_min * 60000000 + $client_sec * 1000000 + $client_micro" | bc)
        server_total=$(echo "$server_hour * 3600000000 + $server_min * 60000000 + $server_sec * 1000000 + $server_micro" | bc)

        # Calculate difference in microseconds and convert to seconds
        diff=$(echo "scale=6; ($server_total - $client_total) / 1000000" | bc)

        # Add to sum for average calculation
        sum=$(echo "scale=6; $sum + $diff" | bc)
    done

    # Calculate average
    avg=$(echo "scale=6; $sum / $num_processes" | bc)
    
    # Format the average with leading zero and append to CSV
    formatted_avg=$(printf "%.6f" $avg)
    echo "$pattern,$formatted_avg" >> results.csv

    echo "Completed processing $PATH_PREFIX"
    echo "Average time difference: $formatted_avg seconds"
    echo "----------------------------------------"

done < directories.txt

echo "Results have been saved to results.csv"

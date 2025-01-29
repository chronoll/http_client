#!/bin/bash

# Create main CSV header
echo "Pattern,Average Time (seconds)" > results.csv

# Process each directory
while read PATH_PREFIX; do
    # Extract pattern (W-1-N) from path
    pattern=$(echo "$PATH_PREFIX" | grep -o 'W-1-[0-9]\+')
    
    # Extract number of processes from path suffix
    num_processes=$(echo "$PATH_PREFIX" | awk -F'-' '{print $NF}')
    
    echo "Processing $PATH_PREFIX..."

    # Create a temporary file to store individual time differences
    temp_diffs=$(mktemp)
    
    # Create access CSV file for this number of processes
    access_csv="access_${num_processes}.csv"
    echo "Time Difference (seconds)" > "$access_csv"

    # Process each log file and store differences
    i=0
    while [ $i -lt "$num_processes" ]; do
        # Extract timestamps
        # Changed to look in send_object log file and extract timestamp after "Program started at"
        client_timestamp=$(grep "Program started at" "${PATH_PREFIX}/server/send_object/send_object_${i}.log" | head -n 1 | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{4\}')
        server_timestamp=$(grep "GET /http_server/send-object.php?ID=${i}[^0-9]" "${PATH_PREFIX}/server/access_log" | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{6\}')

        # Skip if timestamps not found
        if [ -z "$client_timestamp" ] || [ -z "$server_timestamp" ]; then
            echo "Warning: Could not find timestamps for process $i in $PATH_PREFIX"
            i=$((i + 1))
            continue
        fi

        # Pad the client timestamp microseconds to match server format (4 digits to 6 digits)
        client_timestamp="${client_timestamp}00"

        # Extract hours, minutes, seconds, and microseconds separately
        client_hour=$(echo "$client_timestamp" | cut -d: -f1)
        client_min=$(echo "$client_timestamp" | cut -d: -f2)
        client_sec=$(echo "$client_timestamp" | cut -d: -f3 | cut -d. -f1)
        client_micro=$(echo "$client_timestamp" | cut -d. -f2)

        server_hour=$(echo "$server_timestamp" | cut -d: -f1)
        server_min=$(echo "$server_timestamp" | cut -d: -f2)
        server_sec=$(echo "$server_timestamp" | cut -d: -f3 | cut -d. -f1)
        server_micro=$(echo "$server_timestamp" | cut -d. -f2)

        # Calculate total microseconds for each timestamp
        client_total=$(echo "$client_hour * 3600000000 + $client_min * 60000000 + $client_sec * 1000000 + $client_micro" | bc)
        server_total=$(echo "$server_hour * 3600000000 + $server_min * 60000000 + $server_sec * 1000000 + $server_micro" | bc)

        # Calculate difference in microseconds and convert to seconds
        diff=$(echo "scale=6; ($server_total - $client_total) / 1000000" | bc)
        
        # Store the formatted difference in temporary file
        printf "%.6f\n" "$diff" >> "$temp_diffs"
        
        i=$((i + 1))
    done

    echo "Individual time differences (sorted):"
    # Sort the values and display them
    sort -n "$temp_diffs" | tee /dev/tty | while read -r line; do
        printf "%.6f\n" "$line" >> "$access_csv"
    done
    echo "----------------------------------------"

    # Calculate sum and average using the sorted values
    sum=$(awk '{sum += $1} END {print sum}' "$temp_diffs")
    count=$(wc -l < "$temp_diffs")
    if [ "$count" -gt 0 ]; then
        avg=$(echo "scale=6; $sum / $count" | bc)
        # Format the average with leading zero and append to CSV
        formatted_avg=$(printf "%.6f" "$avg")
    else
        formatted_avg="0.000000"
    fi
    
    echo "$pattern,$formatted_avg" >> results.csv

    echo "Completed processing $PATH_PREFIX"
    echo "Average time difference: $formatted_avg seconds"
    echo "Time differences have been saved to $access_csv"
    echo "----------------------------------------"

    # Clean up temporary file
    rm -f "$temp_diffs"

done < directories.txt

echo "Results have been saved to results.csv"

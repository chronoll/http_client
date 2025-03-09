#!/bin/bash

# Create main CSV header
echo "Pattern,Average Request Time (seconds),Average PHP Time (seconds)" > apache.csv

# Process each directory
while read PATH_PREFIX; do
    # Extract pattern (W-1-N) from path
    pattern=$(echo "$PATH_PREFIX" | grep -o 'W-1-[0-9]\+')
    
    # Extract number of processes from path suffix
    num_processes=$(echo "$PATH_PREFIX" | awk -F'-' '{print $NF}')
    
    echo "Processing $PATH_PREFIX..."

    # Create detailed CSV file for this number of processes
    detailed_csv="apache_${num_processes}.csv"
    echo "Pattern,Request Time (seconds),PHP Time (seconds)" > "$detailed_csv"
    
    # Create temporary files to store individual time differences
    temp_request_diffs=$(mktemp)
    temp_php_diffs=$(mktemp)
    
    # Process each log file and store differences
    i=0
    while [ $i -lt "$num_processes" ]; do
        # Extract timestamps for request time
        client_timestamp=$(grep "Sending request:" "${PATH_PREFIX}/client/process_${i}.log" | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{6\}')
        server_timestamp=$(grep "GET /http_server/send-object.php?ID=${i}[^0-9]" "${PATH_PREFIX}/server/access_log" | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{6\}')

        # Extract timestamps for PHP time
        php_start_timestamp=$(grep "Program started at" "${PATH_PREFIX}/server/send_object/send_object_${i}.log" | head -n 1 | grep -o '[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\+')

        # Skip if any timestamps not found
        if [ -z "$client_timestamp" ] || [ -z "$server_timestamp" ] || [ -z "$php_start_timestamp" ]; then
            echo "Warning: Could not find timestamps for process $i in $PATH_PREFIX"
            i=$((i + 1))
            continue
        fi

        # Pad or truncate the PHP start timestamp microseconds to match server format (6 digits)
        micro_part=$(echo "$php_start_timestamp" | cut -d. -f2)
        time_part=$(echo "$php_start_timestamp" | cut -d. -f1)
        
        # Pad with zeros if less than 6 digits
        while [ ${#micro_part} -lt 6 ]
        do
            micro_part="${micro_part}0"
        done

        # Truncate if more than 6 digits
        if [ ${#micro_part} -gt 6 ]; then
            micro_part=${micro_part:0:6}
        fi
        
        php_start_timestamp="${time_part}.${micro_part}"

        # Process request time
        client_hour=$(echo "$client_timestamp" | cut -d: -f1)
        client_min=$(echo "$client_timestamp" | cut -d: -f2)
        client_sec=$(echo "$client_timestamp" | cut -d: -f3 | cut -d. -f1)
        client_micro=$(echo "$client_timestamp" | cut -d. -f2)

        server_hour=$(echo "$server_timestamp" | cut -d: -f1)
        server_min=$(echo "$server_timestamp" | cut -d: -f2)
        server_sec=$(echo "$server_timestamp" | cut -d: -f3 | cut -d. -f1)
        server_micro=$(echo "$server_timestamp" | cut -d. -f2)

        # Process PHP time
        php_hour=$(echo "$php_start_timestamp" | cut -d: -f1)
        php_min=$(echo "$php_start_timestamp" | cut -d: -f2)
        php_sec=$(echo "$php_start_timestamp" | cut -d: -f3 | cut -d. -f1)
        php_micro=$(echo "$php_start_timestamp" | cut -d. -f2)

        # Calculate total microseconds
        client_total=$(echo "$client_hour * 3600000000 + $client_min * 60000000 + $client_sec * 1000000 + $client_micro" | bc)
        server_total=$(echo "$server_hour * 3600000000 + $server_min * 60000000 + $server_sec * 1000000 + $server_micro" | bc)
        php_total=$(echo "$php_hour * 3600000000 + $php_min * 60000000 + $php_sec * 1000000 + $php_micro" | bc)

        # Calculate differences in microseconds and convert to seconds
        request_diff=$(echo "scale=6; ($server_total - $client_total) / 1000000" | bc)
        php_diff=$(echo "scale=6; ($php_total - $server_total) / 1000000" | bc)
        
        # Store the formatted differences for averaging
        printf "%.6f\n" "$request_diff" >> "$temp_request_diffs"
        printf "%.6f\n" "$php_diff" >> "$temp_php_diffs"
        
        # Write the current values to detailed CSV
        printf "%s,%.6f,%.6f\n" "$pattern" "$request_diff" "$php_diff" >> "$detailed_csv"
        
        i=$((i + 1))
    done

    # Calculate averages
    request_sum=$(awk '{sum += $1} END {print sum}' "$temp_request_diffs")
    php_sum=$(awk '{sum += $1} END {print sum}' "$temp_php_diffs")
    count=$(wc -l < "$temp_request_diffs")
    
    if [ "$count" -gt 0 ]; then
        request_avg=$(echo "scale=6; $request_sum / $count" | bc)
        php_avg=$(echo "scale=6; $php_sum / $count" | bc)
        formatted_request_avg=$(printf "%.6f" "$request_avg")
        formatted_php_avg=$(printf "%.6f" "$php_avg")
    else
        formatted_request_avg="0.000000"
        formatted_php_avg="0.000000"
    fi
    
    # Write averages to main CSV
    echo "$pattern,$formatted_request_avg,$formatted_php_avg" >> apache.csv

    echo "Completed processing $PATH_PREFIX"
    echo "Average request time: $formatted_request_avg seconds"
    echo "Average PHP time: $formatted_php_avg seconds"
    echo "Detailed results have been saved to $detailed_csv"
    echo "----------------------------------------"

    # Clean up temporary files
    rm -f "$temp_request_diffs" "$temp_php_diffs"

done < directories.txt

echo "Summary results have been saved to apache.csv"

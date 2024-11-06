#!/bin/bash
# Create all required directories
mkdir -p /var/log/nginx_backend
mkdir -p /var/log/nginx_frontend  
mkdir -p /var/log/mysql

# Check if log type argument is provided
if [ "$#" -lt 1 ] || [[ ! "$1" =~ ^(full|truncated)$ ]]; then
    echo "Usage: $0 [full|truncated] [--no-timestamp-processing]"
    exit 1
fi

LOG_TYPE="$1"
PROCESS_TIMESTAMPS=true
[[ "$2" == "--no-timestamp-processing" ]] && PROCESS_TIMESTAMPS=false

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Hardcoded S3 base URL and timestamps
S3_BASE="https://david-hope-elastic-snapshots.s3.us-east-2.amazonaws.com"
TIMESTAMP_FULL="20241028_133026"
TIMESTAMP_TRUNCATED="20241028_133026"
TIMESTAMP="${LOG_TYPE}_${TIMESTAMP_FULL}"
[[ "$LOG_TYPE" == "truncated" ]] && TIMESTAMP="${LOG_TYPE}_${TIMESTAMP_TRUNCATED}"

S3_URL="${S3_BASE}/logs_${TIMESTAMP}.tar.gz"

# Use home directory for temporary storage
TEMP_DIR="${HOME}/log_extract_${TIMESTAMP}"

echo "Found logs at $S3_URL"

echo "Downloading ${LOG_TYPE} logs..."

# Create temporary directories for processing
mkdir -p "$TEMP_DIR/process"
cd "$TEMP_DIR" || exit 1

# Download and extract to temp processing directory
curl -O "$S3_URL"
FILENAME=$(basename "$S3_URL")

echo "Extracting logs to temporary directory for processing..."
# Extract to process directory, maintaining full path
tar xzf "$FILENAME" -C "$TEMP_DIR/process"

if [ "$PROCESS_TIMESTAMPS" = true ]; then
    echo "Adjusting dates in log files..."

    # Dates in the logs (source dates)
    LOG_DATES=("2024-10-28" "2024-10-27" "2024-10-26" "2024-10-25")
    LOG_YEAR=2024
    LOG_YEAR_SHORT=24

    # Calculate the offset days between the latest log date and today
    LATEST_LOG_DATE="${LOG_DATES[0]}"
    CURRENT_DATE=$(date +%Y-%m-%d)
    OFFSET_DAYS=$(( ($(date -d "$CURRENT_DATE" +%s) - $(date -d "$LATEST_LOG_DATE" +%s)) / 86400 ))

    # Ensure the offset is non-negative to avoid future dates
    if [ "$OFFSET_DAYS" -lt 0 ]; then
        echo "Log dates are in the future relative to today. Adjusting OFFSET_DAYS to 0."
        OFFSET_DAYS=0
    fi

    # Function to adjust dates in files
    adjust_dates() {
        local file="$1"
        echo "Processing $file"

        # Create a temporary file in a controlled location
        local temp_file="${file}.tmp"

        if [[ $file == *"access.log" ]]; then
            echo "Found access log, updating dates..."
            sed_script=""
            for date in "${LOG_DATES[@]}"; do
                log_date_formatted=$(date -d "$date" "+\[%d/%b/%Y:")
                target_date=$(date -d "$date + $OFFSET_DAYS days" "+\[%d/%b/%Y:")
                sed_script+="s|$log_date_formatted|$target_date|g;"
            done
            sed -e "$sed_script" "$file" > "$temp_file" && mv "$temp_file" "$file"
        elif [[ $file == *"mysql.log" ]]; then
            sed_script=""
            for date in "${LOG_DATES[@]}"; do
                log_date_formatted=$(date -d "$date" "+%Y-%m-%d")
                target_date=$(date -d "$date + $OFFSET_DAYS days" "+%Y-%m-%d")
                sed_script+="s|$log_date_formatted|$target_date|g;"
            done
            sed -e "$sed_script" "$file" > "$temp_file" && mv "$temp_file" "$file"
        elif [[ $file == *"mysql-slow.log" ]]; then
            echo "Processing mysql-slow.log"
            echo "Adjusting dates in $file..."

            # Create a temporary file in a controlled location
            local temp_file="${file}.tmp"

            # Read the entire file into memory (assuming the file isn't too large)
            # Alternatively, you can process line by line if the file is large
            awk -v log_dates="${LOG_DATES[*]}" '
            BEGIN {
                split(log_dates, dates, " ")
                for (i in dates) {
                    log_date = dates[i]
                    # Convert log_date to UNIX timestamp at midnight
                    log_date_ts = mktime(gensub(/-/, " ", "g", log_date) " 00 00 00")
                    # Calculate the target date timestamp at midnight
                    target_date_ts = systime() - (systime() % 86400)
                    date_offset_seconds = target_date_ts - log_date_ts
                    date_offsets[log_date] = date_offset_seconds
                }
            }
            {
                if ($0 ~ /^# Time: /) {
                    # Extract the date and time
                    match($0, /^# Time: ([0-9]{4}-[0-9]{2}-[0-9]{2})\s+([0-9:]+)/, arr)
                    if (arr[0] != "") {
                        orig_date = arr[1]
                        orig_time = arr[2]
                        orig_datetime = orig_date " " orig_time
                        # Convert original datetime to timestamp
                        orig_ts = mktime(gensub(/-/, " ", "g", orig_datetime))
                        # Get the offset for this date
                        offset = date_offsets[orig_date]
                        if (offset == "") {
                            # If date not in LOG_DATES, no offset
                            offset = 0
                        }
                        new_ts = orig_ts + offset
                        new_datetime = strftime("%Y-%m-%d %H:%M:%S", new_ts)
                        sub(/^# Time: .*/, "# Time: " new_datetime)
                    }
                } else if ($0 ~ /^SET timestamp=/) {
                    # Extract the timestamp
                    match($0, /SET timestamp=([0-9]+);/, arr)
                    if (arr[1] != "") {
                        orig_timestamp = arr[1]
                        # Determine which date this timestamp corresponds to
                        orig_date = strftime("%Y-%m-%d", orig_timestamp)
                        offset = date_offsets[orig_date]
                        if (offset == "") {
                            offset = 0
                        }
                        new_timestamp = orig_timestamp + offset
                        sub(/SET timestamp=[0-9]+;/, "SET timestamp=" new_timestamp ";")
                    }
                }
                print
            }' "$file" > "$temp_file" && mv "$temp_file" "$file"
        elif [[ $file == *"error.log" ]]; then
            if [[ $file == *"mysql"* ]]; then
                sed_script=""
                for date in "${LOG_DATES[@]}"; do
                    log_date_formatted=$(date -d "$date" "+%y%m%d")
                    target_date=$(date -d "$date + $OFFSET_DAYS days" "+%y%m%d")
                    sed_script+="s|$log_date_formatted|$target_date|g;"
                done
                sed -e "$sed_script" "$file" > "$temp_file" && mv "$temp_file" "$file"
            else
                sed_script=""
                for date in "${LOG_DATES[@]}"; do
                    log_date_formatted=$(date -d "$date" "+%Y/%m/%d")
                    target_date=$(date -d "$date + $OFFSET_DAYS days" "+%Y/%m/%d")
                    sed_script+="s|$log_date_formatted|$target_date|g;"
                done
                sed -e "$sed_script" "$file" > "$temp_file" && mv "$temp_file" "$file"
            fi
        fi

        # Clean up any stray temporary files
        rm -f "$temp_file"
    }

    # List of directories to process
    DIRS=(
        "$TEMP_DIR/process/var/log/nginx_backend"
        "$TEMP_DIR/process/var/log/nginx_frontend"
        "$TEMP_DIR/process/var/log/mysql"
    )

    echo "Available directories:"
    ls -la "$TEMP_DIR/process/var/log/"

    # Process files in each directory
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "Processing directory: $dir"
            find "$dir" -type f 2>/dev/null | while read -r file; do
                adjust_dates "$file"
            done
        else
            echo "Directory $dir does not exist, skipping."
        fi
    done
else
    echo "Skipping timestamp processing..."
fi

echo "Moving files to /var/log..."
if [[ "$LOG_TYPE" == "full" ]]; then
    # For full logs, move with overwrite
    mv -f "$TEMP_DIR/process/var/log/nginx_backend/"* /var/log/nginx_backend/
    mv -f "$TEMP_DIR/process/var/log/nginx_frontend/"* /var/log/nginx_frontend/
    mv -f "$TEMP_DIR/process/var/log/mysql/"* /var/log/mysql/
else
    # For truncated logs, be more careful
    mv -n "$TEMP_DIR/process/var/log/nginx_backend/"* /var/log/nginx_backend/
    mv -n "$TEMP_DIR/process/var/log/nginx_frontend/"* /var/log/nginx_frontend/
    mv -n "$TEMP_DIR/process/var/log/mysql/"* /var/log/mysql/
fi

# Clean up
cd / || exit 1
rm -rf "$TEMP_DIR"

echo "${LOG_TYPE^} logs have been downloaded, extracted, and dates adjusted in /var/log"
echo "Files processed:"
find /var/log/nginx_* /var/log/mysql -type f 2>/dev/null | sort

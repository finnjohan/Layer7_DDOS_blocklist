#!/bin/bash

# Block individual IPs from specified countries using ipset and log IPs based on status
# Modify the country list as needed

# Path to your Apache log directory
log_dir="/var/log/apache2"

# Path to output files
blocked_file="ips_from_last_minute.txt"          # Blocked IPs from target countries
non_blocked_file="non_blocked_ips.txt"           # IPs not in target countries
already_blocked_file="already_blocked_ips.txt"   # IPs already in ipset

# Ensure the output files exist (but don't truncate them)
touch "$blocked_file" "$non_blocked_file" "$already_blocked_file"

# List of target countries (modify as needed)
target_countries=("Mauritius" "Puerto Rico" "Poland" "Malta" "Mongolia" "Guatemala" "Republic of the Congo" "Cambodia" "Malaysia" "Canada" "Togo" "Angola" "El Salvador" "Botswana" "Trinidad and Tobago" "Greece" "Nigeria" "Palestinian Territory" "Serbia" "Congo Republic" "Qatar" "Kosovo" "Gabon" "Cyprus" "Panama" "Thailand" "Syria" "Ivory Coast" "Costa Rica" "Peru" "Iran" "North Macedonia" "Hungary" "Tunisia" "Slovakia" "United Arab Emirates" "Nicaragua" "Saudi Arabia" "Kazakhstan" "Jamaica" "Czechia" "Kazakhstan" "Brunei" "Honduras" "Belarus" "Romania" "Moldova" "Dominican Republic" "Nepal" "Oman" "Mali" "Ireland" "Jordan" "Palestine" "Iraq" "Lebanon" "Chile" "Venezuela" "Latvia" "Kyrgyzstan" "Bolivia" "Paraguay" "Vietnam" "Uzbekistan" "Egypt" "Philippines" "Turkey" "Indonesia" "Bangladesh" "India" "Azerbaijan" "Kenya" "Bahrain" "Bosnia and Herzegovina" "Argentina" "Algeria" "Morocco" "Bulgaria" "Ecuador" "Nepal" "Albania" "Israel" "Colombia" "South Africa" "Senegal" "Hong Kong" "Mexico" "Uruguay" "Kuwait" "Pakistan" "Türkiye" "Armenia" "Brazil" "Japan" "Taiwan" "Singapore" "Russia" "Ukraine" "Sri Lanka" "Georgia")

# Function to check if the IP belongs to a target country
check_ip_country() {
    local ip="$1"
    
    # Skip if IP is empty or invalid
    if [[ -z "$ip" || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[INFO] Invalid IP: $ip, skipping"
        return
    fi

    # Query ip-api for country information about the IP
    country=$(curl -s "http://ip-api.com/json/$ip" | jq -r '.country')
    
    # Handle cases where country lookup fails
    if [ -z "$country" ] || [ "$country" == "null" ]; then
        country="Unknown"
    fi

    # Flag to track if the IP is from a target country
    is_target=false
    
    # Check if the country is in the target list
    for target in "${target_countries[@]}"; do
        if [[ "$country" == "$target" ]]; then
            is_target=true
            # Check if the IP is already in the ipset
            if sudo ipset test blocked_ips "$ip" 2>/dev/null; then
                echo "[INFO] IP $ip already in blocked_ips. Skipping."
                # Log to already_blocked_ips.txt if not already there
                if ! grep -q "^$ip$" "$already_blocked_file"; then
                    echo "$ip # $country" >> "$already_blocked_file"
                fi
            else
                echo "[INFO] Blocking IP $ip (from $country)"
                if sudo ipset add blocked_ips "$ip" -exist; then
                    echo "[SUCCESS] Added $ip to blocked_ips successfully."
                    # Log to blocked_file if not already there
                    if ! grep -q "^$ip$" "$blocked_file"; then
                        echo "$ip # $country" >> "$blocked_file"
                    fi
                else
                    echo "[ERROR] Failed to add $ip to blocked_ips."
                fi
            fi
            break
        fi
    done

    # If not a target country, log to non_blocked_file
    if [[ "$is_target" == "false" ]]; then
        echo "[INFO] IP $ip is from $country (not blocked)"
        if ! grep -q "^$ip$" "$non_blocked_file"; then
            echo "$ip # $country" >> "$non_blocked_file"
        fi
    fi
    
    # Introduce a delay to avoid rate limiting (1 second)
    sleep 1
}

# Ensure ipset command is available
if ! command -v ipset &> /dev/null; then
    echo "[ERROR] ipset not found. Please install ipset."
    exit 1
fi

# Create the ipset if it doesn't exist
if ! sudo ipset list blocked_ips &> /dev/null; then
    echo "[INFO] Creating ipset blocked_ips"
    sudo ipset create blocked_ips hash:ip
fi

# Monitor the latest Apache log file in real-time
latest_log=$(ls -t $log_dir/access*.log | head -n 1)

if [ -z "$latest_log" ]; then
    echo "[ERROR] No Apache log files found in $log_dir"
    exit 1
fi

echo "[INFO] Monitoring log file: $latest_log"

# Use a temporary file to track processed IPs and avoid duplicates
processed_ips="/tmp/processed_ips_$$.txt"
touch "$processed_ips"

# Monitor logs and process IPs
tail -F "$latest_log" | awk '{ print $1 }' | while read ip; do
    # Skip if IP has already been processed
    if grep -q "^$ip$" "$processed_ips"; then
        continue
    fi

    echo "[INFO] Checking IP: $ip"
    check_ip_country "$ip"
    
    # Add IP to processed list to avoid rechecking
    echo "$ip" >> "$processed_ips"
done

# Clean up on script exit
trap 'rm -f $processed_ips' EXIT

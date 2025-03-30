#!/bin/bash
#Insert your own key below!!!!!!!!!!!!!!!!!!!!!!!!!

log_dir="/var/log/apache2"
blocked_file="ips_from_last_minute.txt"
non_blocked_file="non_blocked_ips.txt"
already_blocked_file="already_blocked_ips.txt"

touch "$blocked_file" "$non_blocked_file" "$already_blocked_file"

target_countries=("Seychelles" "Guyana" "Namibia" "Macao" "Zimbabwe" "China" "Argentina" "South Korea" "Namibia" "Uganda" "Mauritius" "Puerto Rico" "Poland" "Malta" "Mongolia" "Guatemala" "Republic of the Congo" "Cambodia" "Malaysia" "Canada" "Togo" "Angola" "El Salvador" "Botswana" "Trinidad and Tobago" "Greece" "Nigeria" "Palestinian Territory" "Serbia" "Congo Republic" "Qatar" "Kosovo" "Gabon" "Cyprus" "Panama" "Thailand" "Syria" "Ivory Coast" "Costa Rica" "Peru" "Iran" "North Macedonia" "Hungary" "Tunisia" "Slovakia" "United Arab Emirates" "Nicaragua" "Saudi Arabia" "Kazakhstan" "Jamaica" "Czechia" "Kazakhstan" "Brunei" "Honduras" "Belarus" "Romania" "Moldova" "Dominican Republic" "Nepal" "Oman" "Mali" "Ireland" "Jordan" "Palestine" "Iraq" "Lebanon" "Chile" "Venezuela" "Latvia" "Kyrgyzstan" "Bolivia" "Paraguay" "Vietnam" "Uzbekistan" "Egypt" "Philippines" "Turkey" "Indonesia" "Bangladesh" "India" "Azerbaijan" "Kenya" "Bahrain" "Bosnia and Herzegovina" "Argentina" "Algeria" "Morocco" "Bulgaria" "Ecuador" "Nepal" "Albania" "Israel" "Colombia" "South Africa" "Senegal" "Hong Kong" "Mexico" "Uruguay" "Kuwait" "Pakistan" "Türkiye" "Armenia" "Brazil" "Japan" "Taiwan" "Singapore" "Russia" "Ukraine" "Sri Lanka" "Georgia")

# AbuseIPDB API Key from abuseip.com (replace with your own key)
ABUSEIPDB_API_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

check_ip_country_and_abuse() {
    local ip="$1"
    
    if [[ -z "$ip" || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[INFO] Invalid IP: $ip, skipping"
        return
    fi

    country=$(curl -s "http://ip-api.com/json/$ip" | jq -r '.country')
    if [ -z "$country" ] || [ "$country" == "null" ]; then
        country="Unknown"
    fi

    is_target=false
    for target in "${target_countries[@]}"; do
        if [[ "$country" == "$target" ]]; then
            is_target=true
            if sudo ipset test blocked_ips "$ip" 2>/dev/null; then
                echo "[INFO] IP $ip already in blocked_ips. Skipping."
                if ! grep -q "^$ip$" "$already_blocked_file"; then
                    echo "$ip # $country" >> "$already_blocked_file"
                fi
            else
                echo "[INFO] Blocking IP $ip (from $country)"
                if sudo ipset add blocked_ips "$ip" -exist; then
                    echo "[SUCCESS] Added $ip to blocked_ips successfully."
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

    if [[ "$is_target" == "false" ]]; then
        echo "[INFO] IP $ip is from $country (not in target countries), checking AbuseIPDB"
        abuse_response=$(curl -s -G "https://api.abuseipdb.com/api/v2/check" \
            --data-urlencode "ipAddress=$ip" \
            -d "maxAgeInDays=90" \
            -H "Key: $ABUSEIPDB_API_KEY" \
            -H "Accept: application/json")
        
        confidence_score=$(echo "$abuse_response" | jq -r '.data.abuseConfidenceScore')
        if [ -z "$confidence_score" ] || [ "$confidence_score" == "null" ]; then
            confidence_score=0
        fi

        if (( confidence_score > 1 )); then
            if sudo ipset test blocked_ips "$ip" 2>/dev/null; then
                echo "[INFO] IP $ip already in blocked_ips (Abuse Confidence: $confidence_score%). Skipping."
                if ! grep -q "^$ip$" "$already_blocked_file"; then
                    echo "$ip # $country # Abuse Confidence: $confidence_score%" >> "$already_blocked_file"
                fi
            else
                echo "[INFO] Blocking IP $ip (Abuse Confidence: $confidence_score%)"
                if sudo ipset add blocked_ips "$ip" -exist; then
                    echo "[SUCCESS] Added $ip to blocked_ips due to Abuse Confidence Score > 1%"
                    if ! grep -q "^$ip$" "$blocked_file"; then
                        echo "$ip # $country # Abuse Confidence: $confidence_score%" >> "$blocked_file"
                    fi
                else
                    echo "[ERROR] Failed to add $ip to blocked_ips."
                fi
            fi
        else
            echo "[INFO] IP $ip not blocked (Abuse Confidence: $confidence_score%)"
            if ! grep -q "^$ip$" "$non_blocked_file"; then
                echo "$ip # $country # Abuse Confidence: $confidence_score%" >> "$non_blocked_file"
            fi
        fi
    fi
    
    sleep 1
}

if ! command -v ipset &> /dev/null; then
    echo "[ERROR] ipset not found. Please install ipset."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "[ERROR] jq not found. Please install jq."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "[ERROR] curl not found. Please install curl."
    exit 1
fi

if ! sudo ipset list blocked_ips &> /dev/null; then
    echo "[INFO] Creating ipset blocked_ips"
    sudo ipset create blocked_ips hash:ip
fi

latest_log=$(ls -t $log_dir/access*.log | head -n 1)

if [ -z "$latest_log" ]; then
    echo "[ERROR] No Apache log files found in $log_dir"
    exit 1
fi

echo "[INFO] Monitoring log file: $latest_log"

processed_ips="/tmp/processed_ips_$$.txt"
touch "$processed_ips"

tail -F "$latest_log" | awk '{ print $1 }' | while read ip; do
    if grep -q "^$ip$" "$processed_ips"; then
        continue
    fi

    echo "[INFO] Checking IP: $ip"
    check_ip_country_and_abuse "$ip"
    
    echo "$ip" >> "$processed_ips"
done

trap 'rm -f $processed_ips' EXIT

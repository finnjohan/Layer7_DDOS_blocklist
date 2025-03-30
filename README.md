# Layer7_DDOS_blocklist
List of IPs in DDOS Layer7 network.

Countries where the IPs origin from.

(Seychelles" "Guyana" "Namibia" "Macao" "Zimbabwe" "China" "Argentina" "South Korea" "Namibia" "Uganda" "Mauritius" "Puerto Rico" "Poland" "Malta" "Mongolia" "Guatemala" "Republic of the Congo" "Cambodia" "Malaysia" "Canada" "Togo" "Angola" "El Salvador" "Botswana" "Trinidad and Tobago" "Greece" "Nigeria" "Palestinian Territory" "Serbia" "Congo Republic" "Qatar" "Kosovo" "Gabon" "Cyprus" "Panama" "Thailand" "Syria" "Ivory Coast" "Costa Rica" "Peru" "Iran" "North Macedonia" "Hungary" "Tunisia" "Slovakia" "United Arab Emirates" "Nicaragua" "Saudi Arabia" "Kazakhstan" "Jamaica" "Czechia" "Kazakhstan" "Brunei" "Honduras" "Belarus" "Romania" "Moldova" "Dominican Republic" "Nepal" "Oman" "Mali" "Ireland" "Jordan" "Palestine" "Iraq" "Lebanon" "Chile" "Venezuela" "Latvia" "Kyrgyzstan" "Bolivia" "Paraguay" "Vietnam" "Uzbekistan" "Egypt" "Philippines" "Turkey" "Indonesia" "Bangladesh" "India" "Azerbaijan" "Kenya" "Bahrain" "Bosnia and Herzegovina" "Argentina" "Algeria" "Morocco" "Bulgaria" "Ecuador" "Nepal" "Albania" "Israel" "Colombia" "South Africa" "Senegal" "Hong Kong" "Mexico" "Uruguay" "Kuwait" "Pakistan" "Türkiye" "Armenia" "Brazil" "Japan" "Taiwan" "Singapore" "Russia" "Ukraine" "Sri Lanka" "Georgia")



ipset for Ubuntu to insert the IPs in the firewall with ipset. The ipset is above ufw firewall. So the list is blocked regardels of the ufw settings.
#You can also insert the rules in other ways, ufw, iptables, nftables and so on. But ipset should hanlde large amount of IPs better then ufw, iptables....

#Create an IP set from text file:

sudo ipset create blocked_ips hash:ip maxelem 5000000

#load IPs to set from text file.

while read -r ip; do if [[ -z "$ip" || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "[INFO] Skipping invalid IP: '$ip'"; continue; fi; sudo ipset add blocked_ips "$ip" -exist; done < full.txt

#create the rule -I creates the rule at the top in iptables

#Dont do this if you already set up the service, then it is already there. check with iptables -L INPUT -v -n before  
iptables -I INPUT 1 -m set --match-set blocked_ips src -j DROP  
<br/>

#Save the rules, over reboots  
ipset save > /etc/ipset.conf

&nbsp;

#List the ipset  
ipset list blocked_ips

#list chain  
iptables -L INPUT -v -n

#Drop the chain  
iptables -D INPUT -m set --match-set blocked_ips src -j DROP

#list chain  
iptables -L INPUT -v -n

#Delete the IP list  
ipset destroy blocked_ips

#List the ipset  
ipset list blocked_ips

==Create a service that insert the ipset after reboot==

nano /etc/systemd/system/ipset-restore.service  
[Unit]  
Description=Restore IP sets and apply iptables rules  
After=network.target  
Before=ufw.service  
Before=netfilter-persistent.service  
ConditionFileNotEmpty=/etc/ipset.conf

[Service]  
Type=oneshot  
RemainAfterExit=yes  
ExecStart=/sbin/ipset restore -exist -file /etc/ipset.conf  
ExecStartPost=/sbin/iptables -I INPUT 1 -m set --match-set blocked_ips src -j DROP  
ExecStop=/sbin/iptables -D INPUT -m set --match-set blocked_ips src -j DROP  
ExecStop=/sbin/ipset flush  
ExecStopPost=/sbin/ipset destroy

[Install]  
WantedBy=multi-user.target

systemctl daemon-reload  
systemctl enable ipset-restore.service  
sudo systemctl start ipset-restore.service  
sudo systemctl status ipset-restore.service

&nbsp;

#Nice to have commands

#Save  
ipset save > /etc/ipset.conf  
#Flush the IPs from ipset  
sudo ipset flush  
#Destroy  
sudo ipset destroy  
#Restore  
sudo ipset restore -exist -file /etc/ipset.conf  
#List  
sudo ipset list blocked_ips  
iptables -L INPUT -v -n

  
<br/>

&nbsp;

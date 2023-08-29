#!/bin/bash

echo "This honeypot script will turn your old linux into a shiny vulnerable machine for hackers"

W=$(whoami)

function update_packages() {
    sudo apt update
    sudo apt install gnome-terminal -y
    sudo apt install ssh -y
    sudo apt install vsftpd -y
    sudo apt install samba -y
    sudo apt install rsyslog -y
    sudo service rsyslog start
}

function start_ssh() {
    sudo touch /var/log/auth.log
    if systemctl is-active --quiet ssh; then
        echo "SSH is already running."
    else
        sudo service ssh start
        if systemctl is-active --quiet ssh; then
            echo "SSH server is up and running."
        else
            echo "Failed to start SSH."
        fi
    fi
}

function start_ftp() {
    sudo touch /var/log/vsftpd.log
    if systemctl is-active --quiet vsftpd; then
        echo "FTP is already running."
    else
        sudo service vsftpd start
        if systemctl is-active --quiet vsftpd; then
            echo "FTP server is up and running."
        else
            echo "Failed to start FTP."
        fi
    fi
}

function start_smb() {
    if systemctl is-active --quiet smbd; then
        echo "SMB is already running."
    else
        sudo service smbd start
        if systemctl is-active --quiet smbd; then
            echo "SMB server is up and running."
            echo "Creating backup of smb.conf file..."
            sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
            echo "Creating a share and making changes in smb.conf file..."
            sudo chmod 777 /etc/samba/smb.conf
            mkdir -p /home/$W/share
            sudo echo "[share]" >> /etc/samba/smb.conf
            sudo echo "path = /home/$W/share" >> /etc/samba/smb.conf
            sudo echo "browseable =yes" >> /etc/samba/smb.conf
            sudo echo "read only = no" >> /etc/samba/smb.conf
            sudo echo "guest ok = yes" >> /etc/samba/smb.conf
            sudo sed -i '32i\log level = 3 auth:10' /etc/samba/smb.conf
        else
            echo "Failed to start SMB."
        fi
    fi
}

function start_all_servers() {
    start_ssh
    start_ftp
    start_smb
}

function read_logs(){
    echo "Would you like to read logs? (yes/no)"
    read read_choice
    if [[ $read_choice == "yes" ]]; then
        echo "Reading logs..."
        if [[ $choice -eq 1 || $choice -eq 4 ]]; then
            # SSH
            cat /var/log/auth.log | grep -i 'Failed password\|Accepted password' > /home/$W/Desktop/SSH_Intruders.txt
        fi

        if [[ $choice -eq 2 || $choice -eq 4 ]]; then
            # FTP
            cat /var/log/vsftpd.log | grep -i 'FAIL LOGIN\|OK LOGIN' > /home/$W/Desktop/FTP_Intruders.txt
        fi

        if [[ $choice -eq 3 || $choice -eq 4 ]]; then
            # SMB
            # Check main log file
            cat /var/log/samba/log.smbd | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' > /home/$W/Desktop/SMB_Intruders_IPs.txt

            # Look for all client-based logs in the Samba directory
            for log_file in /var/log/samba/log.*; do
                if [[ $log_file =~ /var/log/samba/log\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ]]; then
                    cat "$log_file" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' >> /home/$W/Desktop/SMB_Intruders_IPs.txt
                fi
            done
        fi
    fi
}

function recon(){
    echo "Would you like to perform recon? (yes/no)"
    read recon_choice
    if [[ $recon_choice == "yes" ]]; then
        echo "Running WHOIS and Nmap..."
        # Extract IPs from all log files and remove duplicates
        R=$(cat /home/$W/Desktop/SSH_Intruders.txt /home/$W/Desktop/FTP_Intruders.txt /home/$W/Desktop/SMB_Intruders_IPs.txt | grep -oP '\d+\.\d+\.\d+\.\d+' | sort | uniq)
        # Run WHOIS and Nmap on each unique IP
        for i in $R; do 
            echo $i >> IPresults.txt
            whois $i >> IPresults.txt
            echo $i >> NmapResults.txt 
            nmap $i -sV >> NmapResults.txt
        done
    fi
}

function enter_live_mode() {
    echo "Would you like to enter live mode? (yes/no)"
    read live_choice
    if [[ $live_choice == "yes" ]]; then
        echo "Entering live mode..."
        if [[ $choice -eq 1 || $choice -eq 4 ]]; then
            # SSH
            gnome-terminal -- watch -n 1 "cat /var/log/auth.log | grep -i 'Failed password\|Accepted password'" &
        fi

        if [[ $choice -eq 2 || $choice -eq 4 ]]; then
            # FTP
            gnome-terminal -- watch -n 1 "cat /var/log/vsftpd.log | grep -i 'FAIL LOGIN\|OK LOGIN'" &
        fi

        if [[ $choice -eq 3 || $choice -eq 4 ]]; then
            # SMB
            # Check main log file
            gnome-terminal -- watch -n 1 "cat /var/log/samba/log.smbd | grep -i 'NT_STATUS_NO_SUCH_USER\|NT_STATUS_WRONG_PASSWORD\|succeeded\|allowed'" &

            # Look for all client-based logs in the Samba directory
            for log_file in /var/log/samba/log.*; do
                if [[ $log_file =~ /var/log/samba/log\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ]]; then
                    gnome-terminal -- watch -n 1 "cat $log_file | grep -i 'NT_STATUS_NO_SUCH_USER\|NT_STATUS_WRONG_PASSWORD\|succeeded\|allowed'" &
                fi
            done
        fi
    fi
}

function main_menu() {
    echo "You may now choose which service to start:"
    echo "1. SSH"
    echo "2. FTP"
    echo "3. SMB"
    echo "4. All"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            start_ssh
            ;;
        2)
            start_ftp
            ;;
        3)
            start_smb
            ;;
        4)
            start_all_servers
            ;;
        *)
            echo "Invalid choice. Exiting..."
            exit 1
            ;;
    esac
    enter_live_mode
}

function revert_changes() {
    echo "Would you like to revert changes? (yes/no)"
    read revert_choice

    if [[ $revert_choice == "yes" ]]; then
        echo "Reverting changes..."

        # Stop services
        echo "Stopping services..."
        sudo service smbd stop
        sudo service vsftpd stop
        sudo service ssh stop

        # Close terminal windows
        echo "Closing terminal windows..."
        killall gnome-terminal-server

        # Revert smb.conf file
        echo "Reverting smb.conf file..."
        sudo cp /etc/samba/smb.conf.bak /etc/samba/smb.conf

        echo "Changes reverted."
    else
        echo "No changes have been reverted."
    fi
}


# Execute the functions
function main() {
    update_packages
    main_menu
    read_logs
    recon
    revert_changes
}

main

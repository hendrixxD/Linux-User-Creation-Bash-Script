#!/bin/bash

# Script to create users and assign them to groups
# Reads from a text file containing usernames and group names
# Logs actions to /var/log/user_management.log
# Stores generated passwords securely in /var/secure/user_passwords.txt

# Basic Usage: bash create_users.sh name_of_file.txt

# Ensure execution with one argument: name of the text file
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 name_of_text_file" >&2
  exit 1
fi

# defines path variables
USER_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# setup of directories and files with appropriate permissions
mkdir -p /var/secure
touch $LOG_FILE $PASSWORD_FILE
chmod 600 $PASSWORD_FILE
chown root:root $PASSWORD_FILE

# Logger
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Function to create a user and assign to groups
create_user() {
  local username=$1
  local groups=$2

  # Create the personal group for the user if it does not exist
  if ! getent group "$username" > /dev/null; then
    groupadd "$username"
    log_message "Created group $username"
  fi

  # Create the user with the personal group if the user does not exist
  if ! id "$username" > /dev/null 2>&1; then
    useradd -m -g "$username" -s /bin/bash "$username"
    log_message "Created user $username"
  else
    log_message "User $username already exists"
    return
  fi

  # Assign user to additional groups
  if [ -n "$groups" ]; then
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
      # Create the group if it does not exist
      if ! getent group "$group" > /dev/null; then
        groupadd "$group"
        log_message "Created group $group"
      fi
      usermod -aG "$group" "$username"
      log_message "Added user $username to group $group"
    done
  fi

  # Generate a random password
  password=$(openssl rand -base64 12)
  echo "$username:$password" | chpasswd
  log_message "Set password for user $username"

  # Store the password securely
  echo "$username,$password" >> $PASSWORD_FILE
  log_message "Stored password for user $username in $PASSWORD_FILE"
}

# Read the user file and process each line
while IFS=';' read -r user groups; do
  user=$(echo $user | xargs)  # Trim leading/trailing whitespace
  groups=$(echo $groups | xargs)  # Trim leading/trailing whitespace
  create_user "$user" "$groups"
done < "$USER_FILE"

log_message "User creation script completed"

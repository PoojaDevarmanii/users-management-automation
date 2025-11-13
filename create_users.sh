# #!/usr/bin/env bash
# # create_users.sh
# #
# # Beginner-friendly script to create/manage users from a simple input file.
# # Input file format:
# #   username; group1,group2,group3
# # Lines beginning with # or empty lines are ignored.
# #
# # Requirements implemented:
# #  - Create user if not exists (with home directory).
# #  - Create / ensure groups exist.
# #  - Add additional groups for the user.
# #  - Create home directory if missing and set ownership and perms.
# #  - Generate random 12-char password for NEW users; set it; save to /var/secure/user_passwords.txt.
# #  - Log all actions to /var/log/user_management.log (permissions 600).
# #  - Save passwords to /var/secure/user_passwords.txt (permissions 600).
# #  - Provide clear messages and handle existing users/groups gracefully.
# #
# # Usage: sudo ./create_users.sh users.txt

# set -o errexit
# set -o nounset
# set -o pipefail

# # --- Configurable paths ---
# PASSWORD_DIR="/var/secure"
# PASSWORD_FILE="${PASSWORD_DIR}/user_passwords.txt"
# LOGFILE="C:/Users/pooja/OneDrive/Desktop/user manage automation/user_management.log"





# # --- Helpers ---
# log() {
#   local level="$1"; shift
#   local msg="$*"
#   local timestamp
#   timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
#   echo "${timestamp} [${level}] ${msg}" | tee -a "$LOGFILE"
# }

# trim() {
#   # remove leading/trailing whitespace
#   local var="$*"
#   # shell-safe trimming
#   var="${var#"${var%%[![:space:]]*}"}"
#   var="${var%"${var##*[![:space:]]}"}"
#   printf '%s' "$var"
# }

# generate_password() {
#   # generate a reasonably strong 12-character password with letters, digits and symbols
#   # Uses /dev/urandom and tr. If unavailable, falls back to openssl if installed.
#   local pass
#   if command -v tr >/dev/null 2>&1; then
#     pass=$(tr -dc 'A-Za-z0-9!@#$%&*()-_=+?{}[]' </dev/urandom 2>/dev/null | head -c 12 || true)
#   fi
#   if [ -z "$pass" ] && command -v openssl >/dev/null 2>&1; then
#     # openssl base64 will produce longer string; trim to 12
#     pass=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9!@#$%&*()-_=+?{}[]' | head -c 12 || true)
#   fi
#   # last-resort simple generator (should rarely be used)
#   if [ -z "$pass" ]; then
#     pass=$(date +%s%N | sha256sum | base64 | head -c 12)
#   fi
#   printf '%s' "$pass"
# }

# ensure_files_and_perms() {
#   # Ensure log and password directories/files exist with correct perms
#   if [ ! -d "$PASSWORD_DIR" ]; then
#     mkdir -p "$PASSWORD_DIR"
#     chmod 700 "$PASSWORD_DIR"
#   fi

#   if [ ! -f "$PASSWORD_FILE" ]; then
#     touch "$PASSWORD_FILE"
#     chmod 600 "$PASSWORD_FILE"
#   else
#     chmod 600 "$PASSWORD_FILE"
#   fi

#   if [ ! -f "$LOGFILE" ]; then
#     touch "$LOGFILE"
#     chmod 600 "$LOGFILE"
#   else
#     chmod 600 "$LOGFILE"
#   fi
# }

# # --- Main ---
# if [ "$#" -ne 1 ]; then
#   echo "Usage: sudo $0 users_input_file"
#   exit 2
# fi

# INPUT_FILE="$1"

# # Must be run as root for user/group creation and password setting
# if [ "$(id -u)" -ne 0 ]; then
#   echo "ERROR: This script must be run as root (use sudo)."
#   exit 3
# fi

# if [ ! -f "$INPUT_FILE" ]; then
#   echo "ERROR: Input file '$INPUT_FILE' not found."
#   exit 4
# fi

# ensure_files_and_perms

# log "INFO" "Starting user management from '$INPUT_FILE'."

# # Read input file line by line
# while IFS= read -r rawline || [ -n "$rawline" ]; do
#   # Trim whitespace
#   line="$(trim "$rawline")"

#   # Skip empty lines and comments
#   if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
#     log "INFO" "Skipped line (empty or comment)."
#     continue
#   fi

#   # Expect format: username;group1,group2
#   # Split on the first ';'
#   if [[ "$line" != *";"* ]]; then
#     log "ERROR" "Invalid line format (missing ';'): $line"
#     continue
#   fi

#   username="$(trim "${line%%;*}")"
#   grouplist_raw="$(trim "${line#*;}")"

#   if [ -z "$username" ]; then
#     log "ERROR" "Empty username in line: $line"
#     continue
#   fi

#   # Normalize group list: remove spaces around commas, ignore empty groups
#   # Replace spaces with nothing around commas and then split
#   grouplist_raw="${grouplist_raw// /}"   # remove ALL spaces (requirement: ignore whitespace)
#   IFS=',' read -r -a groups_arr <<< "$grouplist_raw"

#   # Remove empty entries
#   groups=()
#   for g in "${groups_arr[@]}"; do
#     g_trim="$(trim "$g")"
#     if [ -n "$g_trim" ]; then
#       groups+=( "$g_trim" )
#     fi
#   done

#   # Create groups if they don't exist
#   for grp in "${groups[@]}"; do
#     if getent group "$grp" >/dev/null 2>&1; then
#       log "INFO" "Group exists: $grp"
#     else
#       if groupadd "$grp" >/dev/null 2>&1; then
#         log "INFO" "Created group: $grp"
#       else
#         log "ERROR" "Failed to create group: $grp"
#       fi
#     fi
#   done

#   # Check if user exists
#   if id "$username" >/dev/null 2>&1; then
#     # User exists — handle gracefully
#     log "WARN" "User already exists: $username. Will NOT change password. Ensuring groups/home are set."

#     # Add to supplementary groups (usermod -a -G) if groups provided
#     if [ "${#groups[@]}" -gt 0 ]; then
#       # Build comma-separated group string
#       IFS=','; groupstr="${groups[*]}"; IFS=' '
#       if usermod -a -G "$groupstr" "$username" >/dev/null 2>&1; then
#         log "INFO" "Updated groups for existing user $username: $groupstr"
#       else
#         log "ERROR" "Failed to update groups for existing user $username: $groupstr"
#       fi
#     fi

#     # Ensure home directory exists and permissions
#     USER_HOME="/home/$username"
#     if [ ! -d "$USER_HOME" ]; then
#       if mkdir -p "$USER_HOME" >/dev/null 2>&1; then
#         chown "$username":"$username" "$USER_HOME"
#         chmod 700 "$USER_HOME"
#         log "INFO" "Created missing home directory for existing user $username: $USER_HOME"
#       else
#         log "ERROR" "Failed to create home directory for $username: $USER_HOME"
#       fi
#     else
#       chown "$username":"$username" "$USER_HOME" >/dev/null 2>&1 || true
#       chmod 700 "$USER_HOME" >/dev/null 2>&1 || true
#       log "INFO" "Ensured ownership/perms on home directory for $username: $USER_HOME"
#     fi

#     continue
#   fi

#   # If we reach here, user does not exist -> create user
#   # Build supplementary groups string (comma-separated), if any
#   supp_groups=""
#   if [ "${#groups[@]}" -gt 0 ]; then
#     IFS=','; supp_groups="${groups[*]}"; IFS=' '
#   fi

#   # Create the user with home and bash shell; add to supplementary groups if provided
#   if [ -n "$supp_groups" ]; then
#     if useradd -m -s /bin/bash -G "$supp_groups" "$username" >/dev/null 2>&1; then
#       log "INFO" "Created user $username with groups: $supp_groups"
#     else
#       log "ERROR" "Failed to create user $username with groups: $supp_groups"
#       continue
#     fi
#   else
#     if useradd -m -s /bin/bash "$username" >/dev/null 2>&1; then
#       log "INFO" "Created user $username (no extra groups)."
#     else
#       log "ERROR" "Failed to create user $username."
#       continue
#     fi
#   fi

#   # Ensure home dir ownership & permissions
#   USER_HOME="/home/$username"
#   if [ -d "$USER_HOME" ]; then
#     chown "$username":"$username" "$USER_HOME" || true
#     chmod 700 "$USER_HOME" || true
#     log "INFO" "Set ownership and permissions for $USER_HOME"
#   else
#     log "WARN" "Expected home directory $USER_HOME not found after useradd."
#   fi

#   # Generate random password and set it
#   newpass="$(generate_password)"
#   if echo "${username}:${newpass}" | chpasswd >/dev/null 2>&1; then
#     # Save to password file
#     printf '%s:%s\n' "$username" "$newpass" >> "$PASSWORD_FILE"
#     chmod 600 "$PASSWORD_FILE"
#     log "INFO" "Set password for $username and saved to $PASSWORD_FILE"
#   else
#     log "ERROR" "Failed to set password for $username"
#   fi

# done < "$INPUT_FILE"

# log "INFO" "User management script completed."

# exit 0




#=================================================

#!/usr/bin/env bash
# create_users.sh
#
# Beginner-friendly script to create/manage users from a simple input file.
# Input file format:
#   username; group1,group2,group3
# Lines beginning with # or empty lines are ignored.
#
# Requirements implemented:
#  - Create user if not exists (with home directory).
#  - Create / ensure groups exist.
#  - Add additional groups for the user.
#  - Create home directory if missing and set ownership and perms.
#  - Generate random 12-char password for NEW users; set it; save to /var/secure/user_passwords.txt.
#  - Log all actions to /var/log/user_management.log (permissions 600).
#  - Save passwords to /var/secure/user_passwords.txt (permissions 600).
#  - Provide clear messages and handle existing users/groups gracefully.
#
# Usage: sudo ./create_users.sh users.txt

set -o errexit
set -o nounset
#set -o pipefail

# --- Configurable paths ---
PASSWORD_DIR="C:/Users/pooja/OneDrive/Desktop/users management automation"
PASSWORD_FILE="${PASSWORD_DIR}/user_passwords.txt"
LOGFILE="C:/Users/pooja/OneDrive/Desktop/users management automation/user_management.log"

# --- Helpers ---
log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp
  timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "${timestamp} [${level}] ${msg}" | tee -a "$LOGFILE"
}

trim() {
  # remove leading/trailing whitespace
  local var="$*"
  # shell-safe trimming
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

generate_password() {
  # generate a reasonably strong 12-character password with letters, digits and symbols
  # Uses /dev/urandom and tr. If unavailable, falls back to openssl if installed.
  local pass
  if command -v tr >/dev/null 2>&1; then
    pass=$(tr -dc 'A-Za-z0-9!@#$%&*()-_=+?{}[]' </dev/urandom 2>/dev/null | head -c 12 || true)
  fi
  if [ -z "$pass" ] && command -v openssl >/dev/null 2>&1; then
    # openssl base64 will produce longer string; trim to 12
    pass=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9!@#$%&*()-_=+?{}[]' | head -c 12 || true)
  fi
  # last-resort simple generator (should rarely be used)
  if [ -z "$pass" ]; then
    pass=$(date +%s%N | sha256sum | base64 | head -c 12)
  fi
  printf '%s' "$pass"
}

ensure_files_and_perms() {
  # Ensure log and password directories/files exist with correct perms
  if [ ! -d "$PASSWORD_DIR" ]; then
    mkdir -p "$PASSWORD_DIR"
    chmod 700 "$PASSWORD_DIR"
  fi

  if [ ! -f "$PASSWORD_FILE" ]; then
    touch "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
  else
    chmod 600 "$PASSWORD_FILE"
  fi

  if [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE"
    chmod 600 "$LOGFILE"
  else
    chmod 600 "$LOGFILE"
  fi
}

# --- Main ---
if [ "$#" -ne 1 ]; then
  echo "Usage: sudo $0 users_input_file"
  exit 2
fi

INPUT_FILE="$1"

# Must be run as root for user/group creation and password setting
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root (use sudo)."
  exit 3
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: Input file '$INPUT_FILE' not found."
  exit 4
fi

ensure_files_and_perms

log "INFO" "Starting user management from '$INPUT_FILE'."

# Read input file line by line
while IFS= read -r rawline || [ -n "$rawline" ]; do
  # Trim whitespace
  line="$(trim "$rawline")"

  # Skip empty lines and comments
  if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
    log "INFO" "Skipped line (empty or comment)."
    continue
  fi

  # Expect format: username;group1,group2
  # Split on the first ';'
  if [[ "$line" != *";"* ]]; then
    log "ERROR" "Invalid line format (missing ';'): $line"
    continue
  fi

  username="$(trim "${line%%;*}")"
  grouplist_raw="$(trim "${line#*;}")"

  if [ -z "$username" ]; then
    log "ERROR" "Empty username in line: $line"
    continue
  fi

  # Normalize group list: remove spaces around commas, ignore empty groups
  # Replace spaces with nothing around commas and then split
  grouplist_raw="${grouplist_raw// /}"   # remove ALL spaces (requirement: ignore whitespace)
  IFS=',' read -r -a groups_arr <<< "$grouplist_raw"

  # Remove empty entries
  groups=()
  for g in "${groups_arr[@]}"; do
    g_trim="$(trim "$g")"
    if [ -n "$g_trim" ]; then
      groups+=( "$g_trim" )
    fi
  done

  # Create groups if they don't exist
  for grp in "${groups[@]}"; do
    if getent group "$grp" >/dev/null 2>&1; then
      log "INFO" "Group exists: $grp"
    else
      if groupadd "$grp" >/dev/null 2>&1; then
        log "INFO" "Created group: $grp"
      else
        log "ERROR" "Failed to create group: $grp"
      fi
    fi
  done

  # Check if user exists
  if id "$username" >/dev/null 2>&1; then
    # User exists — handle gracefully
    log "WARN" "User already exists: $username. Will NOT change password. Ensuring groups/home are set."

    # Add to supplementary groups (usermod -a -G) if groups provided
    if [ "${#groups[@]}" -gt 0 ]; then
      # Build comma-separated group string
      IFS=','; groupstr="${groups[*]}"; IFS=' '
      if usermod -a -G "$groupstr" "$username" >/dev/null 2>&1; then
        log "INFO" "Updated groups for existing user $username: $groupstr"
      else
        log "ERROR" "Failed to update groups for existing user $username: $groupstr"
      fi
    fi

    # Ensure home directory exists and permissions
    USER_HOME="/home/$username"
    if [ ! -d "$USER_HOME" ]; then
      if mkdir -p "$USER_HOME" >/dev/null 2>&1; then
        chown "$username":"$username" "$USER_HOME"
        chmod 700 "$USER_HOME"
        log "INFO" "Created missing home directory for existing user $username: $USER_HOME"
      else
        log "ERROR" "Failed to create home directory for $username: $USER_HOME"
      fi
    else
      chown "$username":"$username" "$USER_HOME" >/dev/null 2>&1 || true
      chmod 700 "$USER_HOME" >/dev/null 2>&1 || true
      log "INFO" "Ensured ownership/perms on home directory for $username: $USER_HOME"
    fi

    continue
  fi

  # If we reach here, user does not exist -> create user
  # Build supplementary groups string (comma-separated), if any
  supp_groups=""
  if [ "${#groups[@]}" -gt 0 ]; then
    IFS=','; supp_groups="${groups[*]}"; IFS=' '
  fi

  # Create the user with home and bash shell; add to supplementary groups if provided
  if [ -n "$supp_groups" ]; then
    if useradd -m -s /bin/bash -G "$supp_groups" "$username" >/dev/null 2>&1; then
      log "INFO" "Created user $username with groups: $supp_groups"
    else
      log "ERROR" "Failed to create user $username with groups: $supp_groups"
      continue
    fi
  else
    if useradd -m -s /bin/bash "$username" >/dev/null 2>&1; then
      log "INFO" "Created user $username (no extra groups)."
    else
      log "ERROR" "Failed to create user $username."
      continue
    fi
  fi

  # Ensure home dir ownership & permissions
  USER_HOME="/home/$username"
  if [ -d "$USER_HOME" ]; then
    chown "$username":"$username" "$USER_HOME" || true
    chmod 700 "$USER_HOME" || true
    log "INFO" "Set ownership and permissions for $USER_HOME"
  else
    log "WARN" "Expected home directory $USER_HOME not found after useradd."
  fi

  # Generate random password and set it
  newpass="$(generate_password)"
  if echo "${username}:${newpass}" | chpasswd >/dev/null 2>&1; then
    # Save to password file
    printf '%s:%s\n' "$username" "$newpass" >> "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    log "INFO" "Set password for $username and saved to $PASSWORD_FILE"
  else
    log "ERROR" "Failed to set password for $username"
  fi

done < "$INPUT_FILE"

log "INFO" "User management script completed."

exit 0

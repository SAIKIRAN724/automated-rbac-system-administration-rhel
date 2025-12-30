#!/bin/bash
# ==========================================================
# Project : Role-Based Sudo, User, Group & LVM Manager
# Platform: RHEL / CentOS / Linux
# Author  : Sai Kiran Panda
# ==========================================================

# ---------------- ROOT CHECK ----------------
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
  fi
}

# ---------------- MENU ----------------
display_menu() {
  echo "========================================"
  echo "        SYSTEM ADMINISTRATION MENU"
  echo "========================================"
  echo "1.  Cat all users"
  echo "2.  Cat last 3 users"
  echo "3.  Cat all groups"
  echo "4.  Cat last 3 groups"
  echo "5.  Create and format a partition"
  echo "6.  Create a logical volume"
  echo "7.  Delete a logical volume and its volume group"
  echo "8.  Create a user"
  echo "9.  Create a group"
  echo "10. Add a user to a group"
  echo "11. Modify a user's group"
  echo "12. Delete a user"
  echo "13. Delete a group"
  echo "========================================"
  read -p "Enter your choice (1-13): " choice
}

# ---------------- USER FUNCTIONS ----------------
create_user() {
  read -p "Enter the username: " username
  useradd -m -s /bin/bash "$username"
  passwd "$username"
  echo "User $username created successfully."
}

delete_user() {
  read -p "Enter the username to delete: " username
  userdel -r "$username"
  echo "User $username deleted successfully."
}

# ---------------- GROUP FUNCTIONS ----------------
create_group() {
  read -p "Enter the group name: " groupname
  groupadd "$groupname"
  echo "Group $groupname created successfully."
}

delete_group() {
  read -p "Enter the group name to delete: " groupname
  groupdel "$groupname"
  echo "Group $groupname deleted successfully."
}

add_user_to_group() {
  read -p "Enter the username: " username
  read -p "Enter the group name: " groupname
  usermod -aG "$groupname" "$username"
  echo "User $username added to group $groupname."
}

modify_user_group() {
  read -p "Enter the username: " username
  read -p "Enter the new group name: " newgroup
  usermod -g "$newgroup" "$username"
  echo "User $username is now part of group $newgroup."
}

# ---------------- PARTITION FUNCTIONS ----------------
create_partition() {
  local DISK=$1
  local PARTITION_SIZE=$2
  local MOUNT_POINT=$3

  echo "Creating partition on $DISK..."
  {
    echo n
    echo p
    echo
    echo
    echo "$PARTITION_SIZE"
    echo w
  } | fdisk "$DISK"

  mkfs.ext4 "${DISK}1"

  if [ -n "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
    mount "${DISK}1" "$MOUNT_POINT"
    UUID=$(blkid -s UUID -o value "${DISK}1")
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab
    echo "Partition created and mounted successfully."
  else
    echo "Partition created and formatted successfully."
  fi
}

# ---------------- LVM FUNCTIONS ----------------
create_logical_volume() {
  local PV_NAME=$1
  local VG_NAME=$2
  local LV_NAME=$3
  local LV_SIZE=$4
  local MOUNT_POINT=$5

  pvcreate "$PV_NAME"
  vgcreate "$VG_NAME" "$PV_NAME"
  lvcreate -n "$LV_NAME" -L "$LV_SIZE" "$VG_NAME"
  mkfs.ext4 "/dev/$VG_NAME/$LV_NAME"

  mkdir -p "$MOUNT_POINT"
  mount "/dev/$VG_NAME/$LV_NAME" "$MOUNT_POINT"
  echo "/dev/$VG_NAME/$LV_NAME $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab

  echo "Logical Volume created and mounted successfully."
}

delete_logical_volume() {
  local VG_NAME=$1
  local LV_NAME=$2
  local PV_NAME=$3
  local CONFIRM=$4

  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Operation cancelled."
    return
  fi

  umount "/dev/$VG_NAME/$LV_NAME"
  lvremove -y "/dev/$VG_NAME/$LV_NAME"
  vgremove -y "$VG_NAME"
  pvremove -y "$PV_NAME"

  echo "LVM deletion completed successfully."
}

# ---------------- MAIN EXECUTION ----------------
check_root

while true; do
  display_menu
  case $choice in
    1) cat /etc/passwd ;;
    2) tail -3 /etc/passwd ;;
    3) cat /etc/group ;;
    4) tail -3 /etc/group ;;
    5)
      read -p "Disk (e.g., /dev/sda): " DISK
      read -p "Partition size (e.g., +10G): " PARTITION_SIZE
      read -p "Mount point (optional): " MOUNT_POINT
      create_partition "$DISK" "$PARTITION_SIZE" "$MOUNT_POINT"
      ;;
    6)
      read -p "Physical volume (e.g., /dev/sdb): " PV_NAME
      read -p "Volume group name: " VG_NAME
      read -p "Logical volume name: " LV_NAME
      read -p "Logical volume size (e.g., 10G): " LV_SIZE
      read -p "Mount point: " MOUNT_POINT
      create_logical_volume "$PV_NAME" "$VG_NAME" "$LV_NAME" "$LV_SIZE" "$MOUNT_POINT"
      ;;
    7)
      read -p "Volume group name: " VG_NAME
      read -p "Logical volume name: " LV_NAME
      read -p "Physical volume: " PV_NAME
      read -p "Type yes to confirm: " CONFIRM
      delete_logical_volume "$VG_NAME" "$LV_NAME" "$PV_NAME" "$CONFIRM"
      ;;
    8) create_user ;;
    9) create_group ;;
    10) add_user_to_group ;;
    11) modify_user_group ;;
    12) delete_user ;;
    13) delete_group ;;
    *) echo "Invalid choice." ;;
  esac

  read -p "Do you want to continue? (yes/no): " ANS
  [[ "$ANS" != "yes" && "$ANS" != "y" ]] && break
done

echo "Script execution completed."

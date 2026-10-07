#!/bin/sh
SCRIPT="${0##*/}"

# Fill each partition's freespace with zeroes
# NB: This will allow 'qemu-img' to compact/compress the image to its minimum size
for mountpoint in $(awk '{if($3 ~ "^ext") print $2}' /etc/fstab); do
  echo "INFO[${SCRIPT}]: Zero-ing '${mountpoint}' partition freespace ..."
  dd if=/dev/zero of="${mountpoint%%/}/ZERO" bs=1M
  rm "${mountpoint%%/}/ZERO"
done

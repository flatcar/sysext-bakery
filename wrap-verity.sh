#!/bin/bash

set -e 

data=$1

verity_hdr=$(veritysetup format $data ${data}.verity)
root_hash=$(echo $(awk -F: '/Root hash:/ { print $2 }' <<<$verity_hdr))

data_size=$(stat -c %s $data)
hash_size=$(stat -c %s ${data}.verity)
root_hash_front=${root_hash:0:32}
root_hash_back=${root_hash:32:32}

# 512-byte sectors
data_sectors=$(( $data_size >> 9 ))
hash_sectors=$(( $hash_size >> 9 ))
data_type=4f68bce3-e8cd-4db1-96e7-fbcaf984b709
hash_type=2c7357ed-ebd2-46d9-aec1-23d437ec2bf5

openssl req -batch -new -x509 -sha256 -newkey rsa:2048 -nodes -out root_key.crt -keyout root_key.pem -days 3650
echo -n "$root_hash" >${data}.roothash
openssl smime -sign -nocerts -noattr -binary -in "${data}.roothash" -inkey "root_key.pem" -signer "root_key.crt" -outform der -out "${data}.roothash.p7s"

cat <<EOF | tr -d '\n' >${data}.verity.sig 
{"rootHash":"$root_hash","signature":"$(base64 -w 0 <${data}.roothash.p7s)"}
EOF
sig_size=$(stat -c %s ${data}.verity.sig)
# rounded up to 4096 bytes
sig_size=$(( ( $sig_size + 4095 ) / 4096 * 4096 ))
sig_sectors=$(( $sig_size >> 9 ))
sig_type=41092b05-9fc8-4523-994f-2def0408b176

# signature + GPT header + PMBR (?)
disk_size=$(( $data_size + $hash_size + 4096 + 2048 * 512 + 33 * 512))
rm -f disk.img
fallocate -l $disk_size disk.img

as_hex() {
  str=$1
  printf "%.8s-%.4s-%.4s-%.4s-%.12s" \
    "${str:0:8}" "${str:8:4}" "${str:12:4}" \
    "${str:16:4}" "${str:20:12}"
}
data_uuid=$(as_hex $root_hash_front)
hash_uuid=$(as_hex $root_hash_back)

cat <<EOF >sda.sfdisk
label: gpt
unit: sectors
sector-size: 512

/dev/sda1 : start=2048,                                          size=      ${data_sectors}, type=${data_type}, uuid=${data_uuid}
/dev/sda2 : start=$(( $data_sectors + 2048 )),                   size=      ${hash_sectors}, type=${hash_type}, uuid=${hash_uuid}
/dev/sda3 : start=$(( ${hash_sectors} + $data_sectors + 2048 )), size=       ${sig_sectors}, type=${sig_type}
EOF

sfdisk disk.img <sda.sfdisk

loop=$(sudo losetup --find --show disk.img)
sudo partx -u $loop
sudo dd bs=512 if=$data of=${loop}p1
sudo dd bs=512 if=${data}.verity of=${loop}p2
sudo dd bs=512 if=${data}.verity.sig of=${loop}p3
sudo losetup -d $loop

echo
echo "Finished!"
echo "Copy disk.img to /etc/extensions/$(basename $data)"
echo "Copy root_key.crt to /etc/verity.d/root_key.crt"

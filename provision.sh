#!/bin/bash

set +e
declare -a ips

version=0.7.7
cli_version=0.0.4
kv_addr=138.68.188.68:8500
tag=vol-test
region=lon1
image=24232340  # Docker on Ubuntu 16.04 64-bit
size=2gb
sshkey=b6:8a:f7:fe:8f:9c:b4:61:b3:f2:3c:d7:65:8a:70:1d
name_template=${tag}-${size}-${region}

if [ -f user_provision.sh ]; then
    echo "Loading user settings overrides from user_provision.sh"
    . ./user_provision.sh
fi

cli_binary=storageos_linux_amd64-${cli_version}
if [ ! -f $cli_binary ]; then
  curl -sSL https://github.com/storageos/go-cli/releases/download/v${cli_version}/storageos_linux_amd64 > $cli_binary
  chmod +x $cli_binary
fi

droplets=$(doctl compute droplet list --tag-name ${tag} --format ID --no-header)

if [ -z "${droplets}" ]; then
  echo "Creating new droplets"
  doctl compute tag create $tag
  for name in ${name_template}01 ${name_template}02 ${name_template}03; do
    id=$(doctl compute droplet create \
      --image $image \
      --region $region \
      --size $size \
      --ssh-keys $sshkey \
      --tag-name $tag \
      --format ID \
      --no-header $name)
    droplets+=" ${id}"
  done
else
  for droplet in $droplets; do
    echo "Rebuilding existing droplet ${droplet}"
    doctl compute droplet-action rebuild "$droplet" --image $image
  done
fi

for droplet in $droplets; do

  while [ "$status" != "active" ]; do
    sleep 2
    status=$(doctl compute droplet get "$droplet" --format Status --no-header)
  done

  ip=$(doctl compute droplet get "$droplet" --format PublicIPv4 --no-header)
  ips+=($ip)

  echo "Waiting for SSH on $ip"
  until nc -zw 1 "$ip" 22; do
    sleep 2
  done
  sleep 5

  ssh-keyscan -H "$ip" >> ~/.ssh/known_hosts
  echo "Disabling firewall"
  until ssh "root@${ip}" "/usr/sbin/ufw disable"; do
    sleep 2
  done

  echo "Copying ~/.docker/config.json (auth needed for private beta)"
  ssh "root@${ip}" "mkdir /root/.docker 2>/dev/null"
  scp ~/.docker/config.json "root@${ip}:/root/.docker/"

  echo "Enabling core dumps"
  ssh "root@${ip}" "echo ulimit -c unlimited >/etc/profile.d/core_ulimit.sh"
  ssh "root@${ip}" "env DEBIAN_FRONTEND=noninteractive apt-get -qqqy install systemd-coredump"

  echo "Copying StorageOS CLI"
  scp -p $cli_binary root@${ip}:/usr/local/bin/storageos
  ssh root@${ip} "echo export STORAGEOS_USERNAME=storageos >>/root/.bashrc"
  ssh root@${ip} "echo export STORAGEOS_PASSWORD=storageos >>/root/.bashrc"

  echo "Setting up for core dumps"
  ssh root@${ip} "echo ulimit -c unlimited >/etc/profile.d/core_ulimit.sh"
  ssh root@${ip} "env DEBIAN_FRONTEND=noninteractive apt-get -qqy install systemd-coredump"

  echo "Enable NBD"
  ssh root@${ip} "modprobe nbd nbds_max=1024"
done

echo "Clearing KV state"
[ -n "$kv_addr" ] && http delete ${kv_addr}/v1/kv/storageos?recurse

cat << EOF > test.env
export VOLDRIVER="storageos/plugin:${version}"
export PLUGINOPTS="KV_ADDR=${kv_addr}"
export CLIOPTS="-u storageos -p storageos"
export KV_ADDR="${kv_addr}"
export PREFIX="ssh root@${ips[0]}"
export PREFIX2="ssh root@${ips[1]}"
export PREFIX3="ssh root@${ips[2]}"
EOF

echo
echo "SUCCESS!  Ready to run tests:"
echo "  source test.env"
echo "  bats singlenode.bats"
echo "  bats secondnode.bats"
echo
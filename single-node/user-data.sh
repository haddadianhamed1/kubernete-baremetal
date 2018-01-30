#!/bin/bash
set -e

# List of etcd servers (http://ip:port), comma separated
export ETCD_ENDPOINTS="http://127.0.0.1:2379"

# Specify the version (vX.Y.Z) of Kubernetes assets to deploy
export K8S_VER=v1.7.3_coreos.0

# Hyperkube image repository to use.
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube

# The CIDR network to use for pod IPs.
# Each pod launched in the cluster will be assigned an IP out of this range.
# Each node will be configured such that these IPs will be routable using the flannel overlay network.
export POD_NETWORK=10.2.0.0/16

# The CIDR network to use for service cluster IPs.
# Each service will be assigned a cluster IP out of this range.
# This must not overlap with any IP ranges assigned to the POD_NETWORK, or other existing network infrastructure.
# Routing to these IPs is handled by a proxy service local to each node, and are not required to be routable between nodes.
export SERVICE_IP_RANGE=10.3.0.0/24

# The IP address of the Kubernetes API Service
# If the SERVICE_IP_RANGE is changed above, this must be set to the first IP in that range.
export K8S_SERVICE_IP=10.3.0.1

# The IP address of the cluster DNS service.
# This IP must be in the range of the SERVICE_IP_RANGE and cannot be the first IP in the range.
# This same IP must be configured on all worker nodes to enable DNS service discovery.
export DNS_SERVICE_IP=10.3.0.10

# Whether to use Calico for Kubernetes network policy.
export USE_CALICO=true

# Determines the container runtime for kubernetes to use. Accepts 'docker' or 'rkt'.
export CONTAINER_RUNTIME=docker

# We need to overwrite this for a hosted Calico install
if [ "${USE_CALICO}" = "true" ]; then
    export CALICO_OPTS="--volume cni-bin,kind=host,source=/opt/cni/bin \
                        --mount volume=cni-bin,target=/opt/cni/bin"
else
    export CALICO_OPTS=""
fi

# -------------

function init_config {
    local REQUIRED=('ADVERTISE_IP' 'POD_NETWORK' 'ETCD_ENDPOINTS' 'SERVICE_IP_RANGE' 'K8S_SERVICE_IP' 'DNS_SERVICE_IP' 'K8S_VER' 'USE_CALICO')

    if [ -z $ADVERTISE_IP ]; then
        export ADVERTISE_IP=$(awk -F= '/COREOS_PUBLIC_IPV4/ {print $2}' /etc/environment)
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done
}

function init_flannel {
    echo "Waiting for etcd..."
    while true
    do
        IFS=',' read -ra ES <<< "$ETCD_ENDPOINTS"
        for ETCD in "${ES[@]}"; do
            echo "Trying: $ETCD"
            if [ -n "$(curl --silent "$ETCD/v2/machines")" ]; then
                local ACTIVE_ETCD=$ETCD
                break
            fi
            sleep 1
        done
        if [ -n "$ACTIVE_ETCD" ]; then
            break
        fi
    done
    RES=$(curl --silent -X PUT -d "value={\"Network\":\"$POD_NETWORK\",\"Backend\":{\"Type\":\"vxlan\"}}" "$ACTIVE_ETCD/v2/keys/coreos.com/network/config?prevExist=false")
    if [ -z "$(echo $RES | grep '"action":"create"')" ] && [ -z "$(echo $RES | grep 'Key already exists')" ]; then
        echo "Unexpected error configuring flannel pod network: $RES"
    fi
}

function init_templates {
    local TEMPLATE=/etc/systemd/system/kubelet.service
    local uuid_file="/var/run/kubelet-pod.uuid"
    if [ ! -f $TEMPLATE ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /opt/cni/bin
Environment=KUBELET_IMAGE_TAG=${K8S_VER}
Environment=KUBELET_IMAGE_URL=${HYPERKUBE_IMAGE_REPO}
Environment="RKT_RUN_ARGS=--uuid-file-save=${uuid_file} \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf \
  --volume rkt,kind=host,source=/opt/bin/host-rkt \
  --mount volume=rkt,target=/usr/bin/rkt \
  --volume var-lib-rkt,kind=host,source=/var/lib/rkt \
  --mount volume=var-lib-rkt,target=/var/lib/rkt \
  --volume stage,kind=host,source=/tmp \
  --mount volume=stage,target=/tmp \
  --volume var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log \
  --volume modprobe,kind=host,source=/usr/sbin/modprobe \
  --mount volume=modprobe,target=/usr/sbin/modprobe \
  --volume lib-modules,kind=host,source=/lib/modules \
  --mount volume=lib-modules,target=/lib/modules \
  ${CALICO_OPTS}"
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers
ExecStartPre=-/usr/bin/rkt rm --uuid-file=${uuid_file}
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --api-servers=http://127.0.0.1:8080 \
  --cni-conf-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=cni \
  --container-runtime=${CONTAINER_RUNTIME} \
  --rkt-path=/usr/bin/rkt \
  --rkt-stage1-image=coreos.com/rkt/stage1-coreos \
  --register-node=true \
  --allow-privileged=true \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster_dns=${DNS_SERVICE_IP} \
  --cluster_domain=cluster.local \
  --volume-plugin-dir=/etc/kubernetes/volumeplugins
ExecStop=-/usr/bin/rkt stop --uuid-file=${uuid_file}
Restart=always
RestartSec=10
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
    fi

    local TEMPLATE=/opt/bin/host-rkt
    if [ ! -f $TEMPLATE ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
#!/bin/sh
# This is bind mounted into the kubelet rootfs and all rkt shell-outs go
# through this rkt wrapper. It essentially enters the host mount namespace
# (which it is already in) only for the purpose of breaking out of the chroot
# before calling rkt. It makes things like rkt gc work and avoids bind mounting
# in certain rkt filesystem dependancies into the kubelet rootfs. This can
# eventually be obviated when the write-api stuff gets upstream and rkt gc is
# through the api-server. Related issue:
# https://github.com/coreos/rkt/issues/2878
exec nsenter -m -u -i -n -p -t 1 -- /usr/bin/rkt "\$@"
EOF
    fi

    local TEMPLATE=/etc/systemd/system/load-rkt-stage1.service
    if [ ${CONTAINER_RUNTIME} = "rkt" ] && [ ! -f $TEMPLATE ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Requires=network-online.target
After=network-online.target
Before=rkt-api.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/rkt fetch /usr/lib/rkt/stage1-images/stage1-coreos.aci /usr/lib/rkt/stage1-images/stage1-fly.aci  --insecure-options=image
[Install]
RequiredBy=rkt-api.service
EOF
    fi

    local TEMPLATE=/etc/systemd/system/rkt-api.service
    if [ ${CONTAINER_RUNTIME} = "rkt" ] && [ ! -f $TEMPLATE ]; then
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Before=kubelet.service
[Service]
ExecStart=/usr/bin/rkt api-service
Restart=always
RestartSec=10
[Install]
RequiredBy=kubelet.service
EOF
    fi

FROM registry.opensuse.org/home/kwk/elemental/images/sle_15_sp3/rancher/rancher-node-image/5.2 as base

# this target builds the ros-installer binary.
FROM opensuse/leap:15.3 AS ros-installer
RUN zypper in -y openssl-devel gcc go1.16
WORKDIR /src
COPY go.mod go.sum /src/
RUN go mod download
COPY cmd /src/cmd
COPY pkg /src/pkg
RUN go build -o /usr/sbin/ros-installer ./cmd/ros-installer

# Make OS image
FROM base as os

# Framework files
COPY framework/cos/ /
COPY framework/files/ /

# Copy in some local OS customizations
COPY opensuse/files /

COPY --from=ros-installer /usr/sbin/ros-installer /usr/sbin/

ARG IMAGE_TAG=latest
RUN cat /etc/os-release.tmpl | env \
    "VERSION=${IMAGE_TAG}" \
    "VERSION_ID=$(echo ${IMAGE_TAG} | sed s/^v//)" \
    "PRETTY_NAME=RancherOS ${IMAGE_TAG}" \
    envsubst > /etc/os-release && \
    rm /etc/os-release.tmpl

# Starting from here are the lines needed for RancherOS to work

# IMPORTANT: Setup rancheros-release used for versioning/upgrade. The
# values here should reflect the tag of the image being built
ARG IMAGE_REPO=norepo
RUN echo "IMAGE_REPO=${IMAGE_REPO}"          > /usr/lib/rancheros-release && \
    echo "IMAGE_TAG=${IMAGE_TAG}"           >> /usr/lib/rancheros-release && \
    echo "IMAGE=${IMAGE_REPO}:${IMAGE_TAG}" >> /usr/lib/rancheros-release

# Copy in framework runtime
COPY --from=framework / /

# Rebuild initrd to setup dracut with the boot configurations
RUN mkinitrd && \
    # aarch64 has an uncompressed kernel so we need to link it to vmlinuz
    kernel=$(ls /boot/Image-* | head -n1) && \
    if [ -e "$kernel" ]; then ln -sf "${kernel#/boot/}" /boot/vmlinuz; fi

# Save some space
RUN rm -rf /var/log/update* && \
    >/var/log/lastlog && \
    rm -rf /boot/vmlinux*

FROM scratch as default
COPY --from=os / /

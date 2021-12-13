# https://developers.redhat.com/blog/2019/05/31/working-with-red-hat-enterprise-linux-universal-base-images-ubi#downloading_a_ubi_container_image
# https://ostreedev.github.io/ostree/buildsystem-and-repos/
# https://ostreedev.github.io/ostree/repository-management/
#
# BUILDTAGS ?= containers_image_ostree_stub \
# 			 $(shell hack/apparmor_tag.sh) \
# 			 $(shell hack/btrfs_installed_tag.sh) \
# 			 $(shell hack/btrfs_tag.sh) \
# 			 $(shell hack/libdm_installed.sh) \
# 			 $(shell hack/libdm_no_deferred_remove_tag.sh) \
# 			 $(shell hack/openpgp_tag.sh) \
# 			 $(shell hack/seccomp_tag.sh) \
# 			 $(shell hack/selinux_tag.sh) \
# 			 $(shell hack/libsubid_tag.sh)
# FROM registry.ci.openshift.org/rhcos/machine-os-content:4.9 AS machine-os
# FROM registry.svc.ci.openshift.org/rhcos/machine-os-content:4.9 AS machine-os

# Using pull-secret information for login into quay.io retrieved from: https://console.redhat.com/openshift/install/pull-secret
ARG MACHINE_OS_SHA=quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:e8254844edda38dc750335c396363ec3200272dbb2d3dee0421aa690b0e0f1ef
ARG ARCH=x86_64
FROM $MACHINE_OS_SHA AS machine-os

FROM registry.redhat.io/ubi8/ubi AS build

# https://www.cyberciti.biz/faq/install-epel-repo-on-an-rhel-8-x/
RUN dnf --disableplugin=subscription-manager -y install \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf --disableplugin=subscription-manager install -y \
        golang \
        make \
        gpgme-devel \
        glibc-static \
        libseccomp-devel \
        shadow-utils \
        ncurses \
        device-mapper-devel \
        git \
    && dnf --disableplugin=subscription-manager clean all

ARG GIT_REPO=https://github.com/avisiedo/cri-o
ARG GIT_BRANCH=main
RUN git clone -b $GIT_BRANCH $GIT_REPO /src

WORKDIR /src
RUN make binaries



FROM registry.redhat.io/ubi8/ubi AS packer

RUN dnf --disableplugin=subscription-manager install -y \
        rpm-build \
        autoconf \
        automake \
        glib2-devel \
        libtool \
        xz-devel \
    && dnf --disableplugin=subscription-manager clean all

COPY --from=machine-os /srv/ /srv/

RUN git clone https://github.com/ostreedev/ostree.git /ostree \
    && mkdir /external \
    && ( cd /external \
         && curl -O wget http://ftp.gnu.org/gnu/bison/bison-2.3.tar.gz \
         && tar xzf bison-2.3.tar.gz \
         && ./configure --prefix=/usr/local --with-libiconv-prefix=/usr/local/libiconv/ \
         && make all \
         && make install ) \


RUN dnf install -y \
        "https://rpmfind.net/linux/centos/8.5.2111/BaseOS/$ARCH/os/Packages/e2fsprogs-libs-1.45.6-2.el8.$ARCH.rpm" \
        "https://rpmfind.net/linux/centos/8.5.2111/BaseOS/$ARCH/os/Packages/e2fsprogs-devel-1.45.6-2.el8.$ARCH.rpm" \
        fuse \
        fuse-libs \
        fuse-overlayfs

WORKDIR /ostree
RUN git submodule update --init \
    && env NOCONFIGURE=1 ./autogen.sh \
    && echo ./configure --prefix=/usr/local \
    && echo make \
    && echo make install DESTDIR=/usr/local/bin


# COPY --from=registry.ci.openshift.org/rhcos/machine-os-content:4.9 /srv/ /srv/
# RUN dnf --disableplugin=subscription-manager install -y \
#         ostreee \
#         rpm-ostree \
#     && dnf --disableplugin=subscription-manager clean all
# RUN dnf --disableplugin=subscription-manager module enable cri-o:nightly
#     dnfdownloader --disableplugin=subscription-manager cri-o

# RUN set -x && yum install -y ostree yum-utils selinux-policy-targeted && \
#     commit=$( find /srv -name *.commit | sed -Ee 's|.*objects/(.+)/(.+)\.commit|\1\2|' | head -1 ) && \
#     mkdir /tmp/working && cd /tmp/working && \
#     yumdownloader -y --disablerepo=* --enablerepo=built --destdir=/tmp/rpms cri-o && \
#     ls /tmp/rpms/ && (cd /tmp/rpms/ && ls cri-o*) && \
#     for i in $(find /tmp/rpms/ -name cri-o* -iname *.rpm); do echo "Extracting $i ..."; rpm2cpio $i | cpio -div; done && \
#     if [[ -d etc ]]; then mv etc usr/; fi && \
#     mkdir -p /tmp/tmprootfs/etc && \
#     ostree --repo=/srv/repo checkout -U $commit --subpath /usr/etc/selinux /tmp/tmprootfs/etc/selinux && \
#     ostree --repo=/srv/repo commit --parent=$commit --tree=ref=$commit --tree=dir=. \
#         --selinux-policy /tmp/tmprootfs \
#         -s "cri-o-ci-dev overlay RPMs" --branch=cri-o-ci-dev

# FROM scratch
# COPY --from=build /srv/ /srv/
# LABEL io.openshift.build.version-display-names="machine-os=rhcos image for testing CRI-O only" \
#       io.openshift.build.versions="machine-os=1.2.3-testing"

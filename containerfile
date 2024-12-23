# This stage is responsible for holding onto
# your config without copying it directly into
# the final image
FROM scratch AS stage-files
COPY ./files /files

# Copy modules
# The default modules are inside blue-build/modules
# Custom modules overwrite defaults
FROM scratch AS stage-modules
COPY --from=ghcr.io/blue-build/modules:latest /modules /modules
COPY ./modules /modules

# Bins to install
# These are basic tools that are added to all images.
# Generally used for the build process. We use a multi
# stage process so that adding the bins into the image
# can be added to the ostree commits.
FROM scratch AS stage-bins
COPY --from=gcr.io/projectsigstore/cosign /ko-app/cosign /bins/cosign
COPY --from=ghcr.io/blue-build/cli:latest-installer /out/bluebuild /bins/bluebuild

# Keys for pre-verified images
# Used to copy the keys into the final image
# and perform an ostree commit.
#
# Currently only holds the current image's
# public key.
FROM scratch AS stage-keys
COPY cosign.pub /keys/aozora.pub


# Main image
FROM quay.io/fedora-ostree-desktops/base-atomic@sha256:51aaf9f01c0e929e35465163a13caee01d1807e617bbad42834e5a5f7a0c0ea7 AS aozora
ARG RECIPE=recipes/recipe.yml
ARG IMAGE_REGISTRY=localhost
ARG CONFIG_DIRECTORY="/tmp/files"
ARG MODULE_DIRECTORY="/tmp/modules"
ARG IMAGE_NAME="aozora"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/base-atomic"
ARG FORCE_COLOR=1
ARG CLICOLOR_FORCE=1
ARG RUST_LOG_STYLE=always
# Key RUN
RUN --mount=type=bind,from=stage-keys,src=/keys,dst=/tmp/keys \
  mkdir -p /etc/pki/containers/ \
  mkdir -p /usr/etc/pki/containers/ \
  && cp /tmp/keys/* /etc/pki/containers/ \
  && cp /tmp/keys/* /usr/etc/pki/containers/ \
  && ostree container commit

# Bin RUN
RUN --mount=type=bind,from=stage-bins,src=/bins,dst=/tmp/bins \
  mkdir -p /usr/bin/ \
  && cp /tmp/bins/* /usr/bin/ \
  && ostree container commit

RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/scripts/ \
  /scripts/pre_build.sh

# Module RUNs
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'files' '{"type":"files","files":[{"source":"system","destination":"/"}]}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'script' '{"type":"script","scripts":["installrpmfusion.sh","installproprietarypackages.sh"]}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'rpm-ostree' '{"type":"rpm-ostree","install":["heif-pixbuf-loader","ffmpeg","ffmpeg-libs","ffmpegthumbnailer","pipewire-libs-extra","libfdk-aac","gstreamer1-plugins-bad","gstreamer1-plugins-ugly"],"remove":["gstreamer1-plugins-bad-free","gstreamer1-plugins-bad-free-libs","gstreamer1-plugins-ugly-free","fdk-aac-free","ffmpeg-free","libavcodec-free","libavdevice-free","libavfilter-free","libavformat-free","libavutil-free","libpostproc-free","libswresample-free","libswscale-free"]}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'rpm-ostree' '{"type":"rpm-ostree","install":["sddm","sddm-themes","hyprland","waybar","xdg-desktop-portal-hyprland","hyprpaper","hyprlock","hypridle","pavucontrol","xdg-user-dirs","xfce-polkit","slurp","grim","wlr-randr","wlsunset","brightnessctl","ddccontrol","dunst","fontawesome-fonts-all","network-manager-applet","pipewire","wireplumber","thunar","thunar-archive-plugin","thunar-volman","xarchiver","imv","p7zip","gvfs-mtp","gvfs-gphoto2","gvfs-smb","gvfs-nfs","gvfs-fuse","gvfs-archive","android-tools","git","distrobox","neovim","virt-manager"],"remove":["firefox","firefox-langpacks","toolbox"]}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'systemd' '{"type":"systemd","system":{"enabled":["sddm-boot.service","libvirtd"]}}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'default-flatpaks' '{"type":"default-flatpaks","notify":true,"system":{"install":["org.mozilla.firefox"]},"user":{}}' \
  && ostree container commit
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=stage-modules,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-aozora-41,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-aozora-41,sharing=locked \
  /tmp/scripts/run_module.sh 'signing' '{"type":"signing"}' \
  && ostree container commit

RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:a8cac2adc90fa842e4565bc1825e588df4f5bcbd,src=/scripts/,dst=/scripts/ \
  /scripts/post_build.sh

# Labels are added last since they cause cache misses with buildah
LABEL org.blue-build.build-id="88016eb6-1f4b-4b5d-9663-e0e2fcecc14d"
LABEL org.opencontainers.image.title="aozora"
LABEL org.opencontainers.image.description="Custom Fedora Atomic based OS image"
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.base.digest="sha256:51aaf9f01c0e929e35465163a13caee01d1807e617bbad42834e5a5f7a0c0ea7"
LABEL org.opencontainers.image.base.name="quay.io/fedora-ostree-desktops/base-atomic:41"
LABEL org.opencontainers.image.created="2024-12-23T13:26:26.611928283+00:00"
LABEL io.artifacthub.package.readme-url=https://raw.githubusercontent.com/blue-build/cli/main/README.md
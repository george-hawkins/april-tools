FROM ubuntu:hirsute

ARG uid
ARG workspace

COPY build-apriltag /var/tmp
COPY build-apriltools /var/tmp

# Required to stop things like `tzdata` asking for your timezone.
ARG DEBIAN_FRONTEND=noninteractive

RUN useradd --uid $uid worker \
    && mkdir $workspace \
    && chown $uid $workspace \
    && apt-get update \
    && apt-get dist-upgrade --yes \
    && apt-get install --yes curl g++ cmake git libopencv-dev python3-dev python3-numpy \
    && /var/tmp/build-apriltag \
    && /var/tmp/build-apriltools

WORKDIR $workspace

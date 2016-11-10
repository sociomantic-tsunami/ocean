#!/bin/sh
set -xe

# Make sure debconf is in noninteractive mode
export DEBIAN_FRONTEND=noninteractive

# Hold grub-pc because it can't be upgraded in headless mode
echo grub-pc hold | dpkg --set-selections

# Make sure our packages list is updated
apt-get update

# We install an up to date git version because we might be using commands only
# present in modern versions. For this we need python-software-properties /
# software-properties-common packages that provide add-apt-repository (for
# easily installing PPAs).
apt-get -y install apt-transport-https build-essential bzip2 devscripts \
    sudo debhelper less lsb-release vim wget curl adduser \
    python3 python-docutils python-software-properties \
    software-properties-common

# Get the Ubuntu codename
release=`lsb_release -cs`

# Install packages that depends on the distro
ruby=ruby1.9.1-dev
test $release = xenial &&
    ruby=ruby2.3-dev
apt-get -y install $ruby

# Add PPAs and custom deb repositories
# Install git from the PPA
add-apt-repository -y ppa:git-core/ppa

# Update and install PPAs
apt-get update
apt-get -y install git

# Update the whole system
apt-get -y dist-upgrade

# fpm installation is release-dependant
apt-get -y install rubygems-integration
gem install fpm

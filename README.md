# Archlinux Custom Image builder for Digitalocean

This tool will allow you to easily make an Archlinux custom image for use with DigitalOcean.

## Why:
A few years ago DigitalOcean supported Archlinux as a standard image.
When they dropped official support, people started using [a conversion script](https://github.com/gh2o/digitalocean-debian-to-arch) that could convert a Debian system to an Archlinux system.
As of late 2018 DigitalOcean now [supports custom images](https://blog.digitalocean.com/custom-images/), making a custom image is a process that takes time to get right.

## What's in the image:
This is a very limited image, you can add packages at the top of the script.
- `haveged` is installed and enabled by default.
- `sshd` is installed and enabled by default.
- `base-devel` is installed, you may not need this.
- `git` is installed, this is needed for the digitalocean synchronize AUR package
- `wget`, I am not sure this is strictly needed.
- `gptfdisk`, used for the disk resize magic.
- `parted`, used for disk resize magic.
- `digitalocean-synchronize` AUR package to automatically setup network
- DNS is setup for google's DNS on 8.8.8.8
- All pacman mirrors are enabled by default.

## At first boot a few things happen:
* A resize the image to take up the full size of the disk.
* Unique SSH host keys
* Unique machine-id

## How to use:
Run the script as root and give it a file name for your image.

```
# curl -O https://raw.githubusercontent.com/robsonde/digitalocean_builder/master/make_image.sh
# chmod u+x make_image.sh
# ./make_image.sh foo.img
```
This will create a foo.img and a compressed foo.img.gz

Or just get the latest image from [https://www.asinine.nz/files/arch_image.img.gz](https://www.asinine.nz/files/arch_image.img.gz)

Then in the DigitalOcean console upload a custom image, you can even import via URL and have DigitalOcean pull directly from [https://www.asinine.nz/files/arch_image.img.gz](https://www.asinine.nz/files/arch_image.img.gz)

NOTE: The image created from this tool needs you to use SSH keys to access the server for the first time.

## Bugs:
Yes, lots I expect.
This has had limited testing, feel free to report bugs or feature requests to < robsonde at gmail >



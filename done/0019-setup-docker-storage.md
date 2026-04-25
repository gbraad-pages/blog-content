---
Title: Setup Docker storage to use LVM thin pool
Date: 2016-09-28
Category: containers
Tags: docker, containers, atomic, storage
---

If you install Docker on a new Fedora or CentOS system, it is very likely that
you use devicemapper. Especially in the case of Fedora cloud images, no special
configuration is done to the image. While Atomic images come pre-configured with
a dedicated pool. Using devicemapper with loopback can lead to unpredictable
behaviour, and while OverlayFS is a nice replacement, you will not be able to
use SELinux at the moment. In this short article I will show how to setup a pool
for storing the Docker images.

## Preparation
For this article I will be using a Fedora 24 installation on an OpenStack cloud
provider[*](http://citycloud.com). It is a standard Cloud image, which means the
root is configured as 'ext4'. I will be attaching a storage volume to the
instance. Just like using Virtual Manager, the disk will be identified as
`/dev/vdb`.

First you need to stop the Docker process and remove the existing location. This
means you will loose the images, but if they are important, you can either
export or push them somewhere else.

```
$ systemctl stop docker
$ rm -rf /var/lib/docker
```

After this we will create a basic LVM setup which will use the whole storage
volume.

```
$ pvcreate /dev/vdb
$ vgcreate docker_vol /dev/vdb
```

We know have a `volumegroup` named `docker_vol`.


## Setup Docker storage
Fedora comes with a tool that makes it easy to setup the storage for Docker,
called `docker-storage-setup`. The configuration is done with a file, and in
our case it needs to contain the identification of the volume group to use:

```
$ vi /etc/sysconfig/docker-storage-setup 
```

    VG="docker_vol"

Now you can run:

```
$ docker-storage-setup
```

This will create the filesystem and configures Docker to use the storage pool.
After this successfully finishes, it has configured the pool to use the xfs
filesystem.


## Verify
To verify these changes, we will start Docker and run a basic image.

```
$ systemctl start docker
$ docker info
```

    Storage Driver: devicemapper
     Pool Name: docker_vol-docker--pool
     Pool Blocksize: 524.3 kB
     Base Device Size: 10.74 GB
     Backing Filesystem: xfs
     Data file: 
     Metadata file: 
     Data Space Used: 37.75 MB
     Data Space Total: 21.45 GB
     Data Space Available: 21.41 GB
     Metadata Space Used: 53.25 kB
     Metadata Space Total: 54.53 MB
     Metadata Space Available: 54.47 MB
     Udev Sync Supported: true
     Deferred Removal Enabled: true
     Deferred Deletion Enabled: true
     Deferred Deleted Device Count: 0
     Library Version: 1.02.122 (2016-04-09)


```
$ docker pull busybox
$ docker run -it --rm busybox
/ # 
```

## Conclusion
Configuration of storage has been really simplified and shouldn't be a reason
not to do this. However, still to many people are not aware of the issues with
devicemapper and loopback. Having to assign additional software to use Docker
can also be a reason why people do not consider doing this, but even OverlayFS
is not perfect. Using overlay with SELinux will be possible in the future, and
hopefully soon these steps will also not be needed. In any case, the steps
involved are simple and if you use Docker on Fedora, needed!


## More information

  * [Friends Don't Let Friends Run Docker on Loopback in Production](http://www.projectatomic.io/blog/2015/06/notes-on-fedora-centos-and-docker-storage-drivers/)
  * [Setting up storage](http://www.projectatomic.io/docs/docker-storage-recommendation/) for Project Atomic

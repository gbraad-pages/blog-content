---
Title: Highly Available storage using GlusterFS
Date: 2016-9-12
Category: High Availability
Tags: gluster, high availability, web, storage
---

In this article I will describe how you can setup a webserver environment with
Highly Available (HA) storage, provided by GlusterFS. We will be setting up a
simple environment in which storage between two webservers needs to be replicated.

GlusterFS is a scalable network filesystem suitable for data-intensive tasks. It
is free and open source software and can utilize common off-the-shelf hardware.
To learn more, please see the Gluster project [home page](http://www.gluster.org/).


## Prerequisites
You will need two servers available, each with a dedicated disk for storage,
such as `/dev/vdb` or `/dev/sdb`. I will be using Fedora 24, which of writing
is the latest version.

The following needs to be installed on both servers:

```
$ dnf install -y glusterfs-server xfsprogs
```

This includes the server component for the distributed filesystem, and the tools
needed to format the disk we will use to store the files. Gluster recommends to
use XFS as the filesystem.

We will assume for this article, that the machines will be running Apache. If
this is not installed already, you can do the following:

```
$ dnf install -y httpd
```


## Hostnames
Make sure the hostnames and IP addresses of the servers are known to each other.
For this, check the content of `/etc/hosts`

`/etc/hosts`
```
37.153.173.244 server01-public
37.153.173.245 server01-public
10.3.0.44 server01-private
10.3.0.45 server02-private
```

Note: these servers have two interfaces, Although this is not necessary, it is
strongly recommended to separate the traffic from the web and what you use for
the storage network. In our case, the web-facing IP addresses have not been
load-balanced yet. This is a topic for future articles.


## Prepare disks
Since Gluster relies on extended file attributes (xattr), we will need to increase
the inode size when formatting the disks.

Perform on the following on both the servers
```
$ mkfs.xfs -i size=512 /dev/vdb
```

	meta-data=/dev/vdb               isize=512    agcount=4, agsize=3276800 blks
	         =                       sectsz=512   attr=2, projid32bit=1
	         =                       crc=1        finobt=1, sparse=0
	data     =                       bsize=4096   blocks=13107200, imaxpct=25
	         =                       sunit=0      swidth=0 blks
	naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
	log      =internal log           bsize=4096   blocks=6400, version=2
	         =                       sectsz=512   sunit=0 blks, lazy-count=1
	realtime =none                   extsz=4096   blocks=0, rtextents=0


Now we need to create a mountpoint for the filesystem. We will use
`/data/var-www/brick01` on `server01`:

```
$ mkdir -p /data/var-www/brick01
$ echo '/dev/vdb /data/var-www/brick01 xfs defaults 1 2' >> /etc/fstab
$ mount -a 
```

and `/data/var-www/brick02` on `server02`:

```
$ mkdir -p /data/var-www/brick02
$ echo '/dev/vdb /data/var-www/brick02 xfs defaults 1 2' >> /etc/fstab
$ mount -a 
```


## Setup Gluster
You will now create a cluster of Gluster servers, which means that we will create
a trust between the two nodes. But before we can do this, we need to make sure
the Gluster daemon is running on the nodes. Perform the following commands on
both of the nodes:

```
$ systemctl enable glusterd
$ systemctl start glusterd
$ systemctl status glusterd
```

Now we need to create the trusted connection. The following commands will only
need to be used on one of the nodes. In my case, this will be `server01`:

```
$ gluster peer probe server02-private
```

    peer probe: success.

Note: the hostname here refers to the private IP address. This is not the same
range as the public network. For security purposes you will likely separate the
traffic.

You can verify is the trust exists by running:

```
$ gluster peer status
```

	Number of Peers: 1

	Hostname: server02-private
	Uuid: af523e9b-4257-485d-aa45-ebd24f115c42
	State: Peer in Cluster (Connected)


If you would run this command also on `server02`, you would get a similar result:

	Number of Peers: 1

	Hostname: server01-private
	Uuid: 74c77082-b62c-4cc4-b33f-02de36083990
	State: Peer in Cluster (Connected)


## Create Gluster volume
In case of a failure, we do not want our data to be unavailable. Therefore we
need to have two copies of our data, and we do this by creating a replicated
volume.

This command will only need to be run on one node, as Gluster will take care of
the related nodes.

```
$ gluster volume create var-www replica 2 \
          server01-private:/data/var-www/brick01/volume \
          server02-private:/data/var-www/brick02/volume
```

	volume create: var-www: success: please start the volume to access data

```
$ gluster volume start var-www
```

	volume start: var-www: success

```
$ gluster volume info
```

	Volume Name: var-www
	Type: Replicate
	Volume ID: e91014ca-f98c-42e5-8e75-de4d2e65f569
	Status: Started
	Number of Bricks: 1 x 2 = 2
	Transport-type: tcp
	Bricks:
	Brick1: server01-private:/data/var-www/brick01/volume
	Brick2: server02-private:/data/var-www/brick02/volume
	Options Reconfigured:
	transport.address-family: inet
	performance.readdir-ahead: on
	nfs.disable: on


## Mount Gluster volume
Before you can mount the volume on `/var/www` to share the webpages, we need to
move the original `/var/www` out of the way and create a new directory to mount.
Perform the following commands on both the servers:

```
$ systemctl stop httpd
$ mv /var/www{,.orig}
$ mkdir /var/www
```

Now that we have the mountpoint, we can add an entry to `fstab` to deal with
mounting of our volume. On `server01` you need to do the following:

```
$ echo 'server01-private:/var-www /var/www glusterfs defaults,_netdev,fetch-attempts=3 0 0' >> /etc/fstab
$ mount -a
```

And on `server02`:
```
$ echo 'server02-private:/var-www /var/www glusterfs defaults,_netdev,fetch-attempts=3 0 0' >> /etc/fstab
$ mount -a
```

Now the volume has been mounted and replication is available. We use `_netdev`
because network needs to be up before we can use this filesystem, and `fetch_attempts`
will deal with the volume information in case of a failure. Since we have multiple
IP address, this is a suggested setting.


## Test replication 
On `server01` you can do the following:

```
$ mkdir -p /var/www/html
$ echo 'Hello, World!' > /var/www/html/index.html
$ systemctl start httpd
```

If you would now open the web facing IP address, you should see the message:
`Hello, World!`.

Note: if you have issues opening the page, or the default Fedora test page gets
returned, you might have SELinux enabled. In this case, you need to turn on the
following boolean:

```
$ setsebool -P httpd_use_fusefs 1
```

which will allow Apache to use the FUSE filesystem mount as used by GlusterFS.

Now, on `server02` you can check the content of the folder:

```
$ ls /var/www/html
```

and you would see an `index.html` file. Now start Apache and you will see that
the content is also served from this server.

```
$ systemctl start httpd
```


## Conclusion
Using GlusterFS it is easy to setup an environment that can handle issues with
storage availability. You now have a replicate volume that is available on two
servers. Actions we take on each of these servers, will be replicated to the
other server.

In this case we have setup the servers to handle both the storage and act as a
client to read these files. More advanced are available and are described in the
[documentation](http://gluster.readthedocs.io/en/latest/).


## Next step
Now that we have implemented replicated storage for our webservers, we need to
provide a HA solution to deal with the traffic on the webfacing IP addresses.
In an OpenStack environment you could use Neutron to setup a loadbalancer and 
health monitor for the two servers. How to set this up in described in the
[following article](./building-a-multi-tier-application-using-openstack-packstack.html).
However, you can also do so with HAProxy and a failover mechanism, which will be
the topic of a future article.

If you have questions please let me know on Twitter at [@gbraad](http://twitter.com/gbraad) or by email.

---
Title: Deployment of Ceph using custom Atomic images
Date: 9-7-2016
Category: Containers
Tags: centos, ceph, atomic, ansible, ostree, storage
---

As part of providing a scalable infrastructure, many components in the datacenter are now moving towards software-based solutions, such as SDN (for networking) and SDS (for storage). Ceph one of these projects to provide a scalable, software-based software solution. It is often used in conjuction with OpenStack for storing disk images and block access for volumes. Setting up an environment usually involves installing a base operating system and configuring the machine to join a storage cluster. In this article I will setup a Atomic based image that allows for fast deployment of Ceph cluster. This is not a recommended solution, but an exercise that shows how to cutomize Atomic Host and using Ansible to standup a Ceph cluster.

## Components
[Atomic](http://www.projectatomic.io/)[*](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/atomic.md) Host is a new generation of Operating Systems that used to create an immutable infrastructure to deploy and scale containerized applications. For this, it uses a technology called [OSTree](https://ostree.readthedocs.io/en/latest/)[*](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/ostree.md) which is a git-like model for dealing with filesystem trees. It allows different filesystems to exist alongside of each other. If a filesystem is not booting properly, it is possible to move back to the previous state.

[Ceph](http://ceph.com/)[*](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/ceph.md) is a distributed storage solution which provides Object Storage, Block Storage and FIlesystem access. Ceph comes with several software components which provides a role in the cluster, such as a monitor or storage daemon.

[Ansible](https://www.ansible.com/)[*](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/ansible.md) is a configuration and system management tool which for example can do multi-node deployment of software or execution of commands

Although Atomic Hosts are primarily used to deploy Docker and Kubernetes environments, or even containerized versions of the Ceph daemons, I will show how it is possible to use ostree to deploy the Ceph software on nodes, with minimal effort. Ansible is used to send commands to these nodes and finalize the configuration.


## Preparation
For this setup we will use about 7 machines. To simplify testing, I have performed these actions on an OpenStack environment, such as [DreamCompute](https://www.dreamhost.com/cloud/computing/).

  * 1 controller and compose node, running Fedora 24 with IP address 10.3.0.2
  * 3 Ceph monitors, running CentOS Atomic with IP addresses 10.3.0.3-5
  * 3 Ceph storage nodes, running CentOS Atomic with IP addresses 10.3.0.6-8 and attached storage volume at `/dev/vdb`.

To deploy you can start with setting up the Fedora node.

### Install controller
To deploy our environment we setup a controller node which can access the other nodes in the network using SSH. In our case we will use Fedora 24.  After installing the operating system, perform the following commands:

```
$ dnf update -y
$ dnf install -y  ansible rpm-ostree git python
$ ssh-keygen
$ cat ~/.ssh/id_rsa.pub
```

The last two commands generate an SSH authentication key and will show the result on the command line.


### Atomic nodes
The installation media for Atomic can be found at the main project page. It comes in two different distribution types, CentOS or Fedora. For this article I used CentOS, and downloaded it from the following location:

```
$ wget http://http://cloud.centos.org/centos/7/atomic/images/CentOS-Atomic-Host-7-GenericCloud.qcow2
```

and uploaded it to my OpenStack environment with:

```
$ openstack image create "CentOS7 Atomic" --progress --file CentOS-Atomic-Host-7-GenericCloud.qcow2 --disk-format qcow2 --container-format bare --property os_distro=centos
```

After this, I created six identical machines, with provisioning a predefined SSH key with cloud-init which we made on the controller node. If you are not using OpenStack, you have to use a cloud-init configdrive to configure the node with the SSH key. This process is described [here](http://www.projectatomic.io/docs/quickstart/).

The storage nodes need to have to configured with a dedicated volume for use with the `osd` storage daemon of Ceph. By creating a volume and attaching them to the node, these will be identified as `/dev/vdb`. There is no need to prepapre a filesystem on them. This will be handles by the deployment scripts.

Note: if you want to upload disk images to DreamCompute or other Ceph-backed OpenStack image services, you have to convert the disk image to raw format first. An example of this can be found in [an example](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/openstack/client.md#examples) for use of the OpenStack client.


## Compose tree
On the controller node we will create an ostree that will be used to setup the Ceph software on the Atomic host nodes. This process involves creating a definition for a filesystem tree that uses the base defintion of CentOS Atomic with the additional packages from the CentOS-specific Ceph packages.

### Atomic definition
We will clone the git repositiory containing the base definition:

```
$ mkdir -p /workspace
$ cd /workspace
$ git clone https://github.com/CentOS/sig-atomic-buildscripts.git \
    -b downstream \
    --depth 1 \
    ceph-atomic
```

Inside this folder you can add a RPM repository file where the Ceph packages are located:

`ceph-atomic/centos-ceph-jewel.repo`
```
[centos-ceph-jewel]
name=CentOS-7 - Ceph Jewel
baseurl=http://buildlogs.centos.org/centos/7/storage/x86_64/ceph-jewel/
gpgcheck=0
```

And then we will define an Atomic host for Ceph-Jewel and specify which additional repositories and packages are used:

`ceph-atomic/ceph-atomic-host.json`
```
{
    "include": "centos-atomic-host.json",
    "ref": "centos-atomic-host/7/x86_64/ceph-jewel",
    "automatic_version_prefix": "2016.0",
    "repos": ["centos-ceph-jewel", "epel"],
    "packages": [
        "ceph",
        "ntp",
        "ntpdate",
        "hdparm",
        "autogen-libopts"
    ]
}
```

Note: with `include` we base our image off an existing definition. In our case this will simplify the process, but it also means we will end up with an image with unneeded components. For our test this is not an issue.

After this, the defintion for the Ceph-specific Atomic host is finished. Before we can compose the ostree, we have to create and initialize the repository directory:

```
$ mkdir -p /srv/repo
$ ostree --repo=/srv/repo init --mode=archive-z2
```

When you perform the following command:

```
$ rpm-ostree compose tree \
    --repo=/srv/repo \
    ./ceph-atomic/ceph-atomic-host.json
```

packages will be fetched and committed to an ostree in `/srv/repo`. After this, you will have a filesystem tree which can be served from a webserver, to be used by Atomic hosts.

```
$ cd /srv/repo
$ python -m SimpleHTTPServer
```

This will serve the content from `/srv/repo` on the endpoint `http://10.3.0.2:8000/`.


## Deployment
To get the Atomic hosts to use the tree, the following commands will have to be used to provision the Ceph-based filesystem tree:

```
$ sudo su -
$ setenforce 0
$ ostree remote add --set=gpg-verify=false atomic-ceph http://10.3.0.2:8000/
$ rpm-ostree rebase atomic-ceph:centos-atomic-host/7/x86_64/ceph-jewel
$ systemctl reboot
```

This is however very cumbersome as we have to do this on six nodes. To optimize this process, we will use Ansible.

Note: `setenforce 0` is used to prevent issue with SELinux label during the rebase action.


### OSTree provisioning using Ansible
Create a file called `hosts` in your home directory with the following content:

`~/hosts`
```
[mons]
atomic-01 ansible_ssh_host=10.3.0.3
atomic-02 ansible_ssh_host=10.3.0.4
atomic-03 ansible_ssh_host=10.3.0.5

[osds]
atomic-04 ansible_ssh_host=10.3.0.6
atomic-05 ansible_ssh_host=10.3.0.7
atomic-06 ansible_ssh_host=10.3.0.8
```

To test if the nodes are reachable, use the following command:

```
$ ansible -i hosts all -u centos -s -m ping
```

If no error occurs, you are all set.

Using Ansible and the hosts file we can perform these commands on all the nodes.
```
$ ansible -i hosts all -u centos -s -m shell -a "setenforce 0"
$ ansible -i hosts all -u centos -s -m shell -a "ostree remote add --set=gpg-verify=false atomic-ceph http://10.3.0.2:8000/"
$ ansible -i hosts all -u centos -s -m shell -a "rpm-ostree rebase atomic-ceph:centos-atomic-host/7/x86_64/ceph-jewel"
$ ansible -i hosts all -u centos -s -m shell -a "systemctl disable docker"
$ ansible -i hosts all -u centos -s -m shell -a "systemctl reboot"
```

The last command will throw errors, but this is expected as the connection to the node is dropped. To check if the nodes are up again, you can perform the previous ping test again.

Note: since we based on the original CentOS Atomic host image, it will have Docker installed. For this article we do not use it, so it is best to disable it.


## Deployment using `ceph-ansible`
If the previous step succeeded you would have six atomic hosts that are ready to be configured to form a small Ceph cluster; 3 nodes will serve the role of monitor, while the other nodes will be storage nodes with an attached volume at `/dev/vdb`. For the deployment we will use `ceph-ansible`. This is a collection of playbooks to help with common scenarios for a Ceph storage cluster.

From your home folder perform the following command:
```
$ git clone https://github.com/ceph/ceph-ansible.git --depth 1
```

This will clone the latest version of the playbooks. But before we can use them, we will need to configure it for our setup. But before we do, we initialize it with the base configuration. Take note that we will re-use our previosuly used `~/hosts` file for Ansible.

```
$ cd ceph-ansible
$ cp site.yml.sample site.yml
$ cp group_vars/all.sample group_vars/all
$ cp group_vars/mons.sample group_vars/mons
$ cp group_vars/osds.sample group_vars/osds
$ ln -s ~/hosts hosts
```

We will now customize the configuration by changing the following files and add the shows content to the top of the file:

`group_vars/all`
```
cluster_network: 10.3.0.0/24
generate_fsid: 'true'
ceph_origin: distro
monitor_interface: eth0
public_network: 10.3.0.0/24
journal_size: 5120
group_vars/mons
cephx: false
```

`group_vars/mons`
```
cephx: false
```

`group_vars/osds`
```
journal_collocation: true
cephx: false
devices:
   - /dev/vdb
```

After these changes are made, you have setup to use Ceph packages as provided by the distribution, and to deploy as a storage cluster on 10.3.0.0/24.

To deploy the storage cluster, all we need to do now is to run the playbook named `site.yml` and skipping the tags named `with_pkg` and `package-install`.
```
$ ansible-playbook -i hosts site.yml --skip-tags with_pkg,package-install
```

After this finishes a storage cluster should be available.

## Conclusion
This article showed how it is possible to customize an Atomic host image for a specific use-case and use this for deployment of a simple Ceph cluster. Using ostree it is possible to move between different trees, allowing a collection of packages to be upgraded in an atomic fashion. And when there is a failure for some reason, it is possible to rollback to the previous tree and allow the node to function in the former state.

This is part of the setup I usefor automated builds of Ceph packages and deployment tests. If you have questions about specific parts, please let me know on Twitter at [@gbraad](https://twitter.com/gbraad) or by email. Input is appreciated as this can help with writing of future articles.


## Links
Some information that can help with customizing your own images:

  * [Build your own Atomic](https://github.com/jasonbrooks/byo-atomic), and my [automated build](http://gitlab.com/gbraad/byo-atomic)
  * [Tree definition](https://gitlab.com/gbraad/ceph-atomic/)
  * [Remote location](https://gbraad.gitlab.io/byo-atomic-ceph/)
  * [Automated build](https://gitlab.com/gbraad/byo-atomic-ceph/builds)


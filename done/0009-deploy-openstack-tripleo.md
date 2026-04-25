---
Title: Deploying OpenStack using TripleO
Date: 2016-5-18
Modified: 2016-9-10
Category: OpenStack
Tags: openstack, tripleo, rdo
---


In this article we will deploy an OpenStack environment using TripleO using
the `tripleo-quickstart` scripts. It will create a virtualized environment
which consists of 1 Undercloud node and in total 9 nodes in the Overcloud;
3 controller nodes (High Availability), 3 compute nodes and 3 Ceph storage
nodes.


## What is TripleO, _undercloud_ and _overcloud_?
[TripleO](https://wiki.openstack.org/wiki/TripleO) is a deployment method in
which a dedicated OpenStack management environment is used to deploy another
OpenStack environment which is used for the workload. The management environment
is contained in a single machine, called the _undercloud_. This OpenStack
environment takes care of the monitoring and management of what is known as the
_overcloud_. The _overcloud_ is the actual OpenStack environment that will run
the workload.


## Prerequisites
It is preferred to use a dedicated server for the following instructions.
Consider using 32G of memory and have enough diskspace available in `/home`.
This target node has to be using CentOS 7 (or RHEL7).


## Prepare for deployment
The deployment can be done from a workstation targeting a server, or from the
server itself. Whatever your preferred method is, you will need the 
[tripleo-quickstart](https://github.com/openstack/tripleo-quickstart) scripts.

```
$ curl -O https://raw.githubusercontent.com/openstack/tripleo-quickstart/master/quickstart.sh
$ chmod u+x quickstart.sh
$ ./quickstart.sh --install-deps
```

This will install the dependencies used by the `quickstart.sh` script. Now you
need to prepare the target node. Make sure you can login to this server without
a password.

```
$ export VIRTHOST=[target]
$ ssh-copy-id root@$VIRTHOST
$ ssh root@$VIRTHOST uname -a
```

This article witll not describe the setup of passwordless or key-based
authentication with SSH. If issues occur, please verify you have a generated
keyset. If not, generate one with `ssh-keygen`. For further information please
consult the `man` page or verify online.


## Cache deployment images locally
Although this step is not necessary, you can pre-download the images and cache
them locally. This can be helpful if you want to perform the deployment using
different images and/or suffer from bad connectivity.

The location if the images is currently at `http://artifacts.ci.centos.org/rdo/images/{{release}}/delorean/stable/undercloud.qcow2`.

To download the _mitaka_ image, you can do this with

```
$ mkdir /var/lib/oooq-images
$ curl http://artifacts.ci.centos.org/rdo/images/mitaka/delorean/stable/undercloud.qcow2 -o /var/lib/oooq-images/undercloud-mitaka.qcow2
```


## Deployment configuration file
We will create a virtual environment for out TripleO deployment. This will
provide you with the knowledge you need to perform a bare-metal installation.

You can define the node deployment inside a configuration file, eg. called 
`deploy-config.yml`. This will contain the following:

```
overcloud_nodes:
  - name: control_0
    flavor: control
  - name: control_1
    flavor: control
  - name: control_2
    flavor: control

  - name: compute_0
    flavor: compute
  - name: compute_1
    flavor: compute
  - name: compute_2
    flavor: compute

  - name: storage_0
    flavor: ceph
  - name: storage_1
    flavor: ceph
  - name: storage_2
    flavor: ceph

extra_args: "--control-scale 3 --ceph-storage-scale 3 -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml --ntp-server pool.ntp.org"

```

Nodes can be assigned a role by setting the flavor:

  * `control` sets up a controller node, which also handles the network.
  * `compute` sets up a Nova compute node.
  * `ceph` sets up a node for Ceph storage.


The extra arguments allow you to modify the deployment that is performed.

  * `--control-scale 3` instructs the deployment to assign 3 nodes with the
      controller role.
  * `--ceph-storage-scale 3` instructs the deployment to assign 3 nodes to
      be used for the Ceph storage backend.
  * `-e puppet-pacemaker.yaml` will setup pacemaker HA for the controller
      nodes
  * `--ntp-server pool.ntp.org` will sync time on the nodes using NTP.

Note: if you want to use all compute nodes at once, include `--compute-scale 3`. But in this article I am using these additional nodes for scale out.


## Perform deployment
Now you can perform the _undercloud_ deployment using:

```
$ ./quickstart.sh --config deploy-config.yml --undercloud-image-url file:///var/lib/oooq-images/undercloud-mitaka.qcow2 $VIRTHOST
```

But before you do, please continue reading about the `Deployment scripts`.

The previous command will target the node as specified with the `$VIRTHOST` 
environment variable, and according to the `deploy-config.yml` which we defined
earlier.

It will login to this node and create a `stack` user which will be running the
virtual machines. Later we will inspect this. After creating the virtual
machines it will prepare the `undercloud` machine. After this, you still need to
start the actual deployment. 


## Deployment scripts
To login to the undercloud:

```
$ ssh -F $OPT_WORKDIR/ssh.config.ansible undercloud
```

The undercloud is not fully prepared, you would have to do so with the following
scripts.

Undercloud (management)

  * `undercloud-install.sh` will run the undercloud install and execute
    diskimage elements.
  * `undercloud-post-install.sh` will perform all pre-deploy steps, such as
    uploading the images to _glance_

Overcloud (workload)

  * `overcloud-deploy.sh` will deploy the overcloud, creating a _heat_ stack
    and will use the nodes as defined in `instack-env.json` and the extra
    arguments given in the deployment configuration.
  * `overcloud-deploy-post.sh` will do any post-deploy configuration
    such as writing a local `/etc/hosts` file.
  * `overcloud-validate.sh` will run post-deploy validation, like a
    _pingtest_ and possible _tempest_


You can run these scripts one by one... or install the whole _undercloud_ and
_overcloud_ using the command:

```
$ ./quickstart.sh --tags all --config deploy-config.yml --undercloud-image-url file:///var/lib/oooq-images/undercloud-mitaka.qcow2 $VIRTHOST
```

Using `--tags all` will instruct ansible to perform all the steps and scripts
as previously described. I suggest you to run the steps first each one by one
and look into the scripts itself to understand how they interact with
`python-tripleoclient` (eg. `openstack undercloud` and `openstack overcloud`).


```
[stack@undercloud ~]$ ./undercloud-install.sh
[stack@undercloud ~]$ ./undercloud-post-install.sh
[stack@undercloud ~]$ ./overcloud-deploy.sh
[stack@undercloud ~]$ ./overcloud-deploy-post.sh
[stack@undercloud ~]$ ./overcloud-validate.sh
```


## Undercloud node
After running these commands, you will have a fully deployed environment.
You can verify this from the _undercloud_ node.

```
[stack@undercloud ~]$ . stackrc
[stack@undercloud ~]$ ironic node-list
```

    +--------------------------------------+-----------+--------------------------------------+-------------+--------------------+-------------+
    | UUID                                 | Name      | Instance UUID                        | Power State | Provisioning State | Maintenance |
    +--------------------------------------+-----------+--------------------------------------+-------------+--------------------+-------------+
    | 5c4f1ad5-3cea-41c2-8fa8-f3468e660447 | control-0 | aea0add0-f638-4a41-97ca-a2a64ac083a5 | None        | active             | True        |
    | 0a0bf5e8-e903-4f77-be35-0a49f4da5109 | control-1 | 75778a5e-5e65-48bc-9934-d4cb203fad86 | None        | active             | True        |
    | 12aa12d2-0023-48ac-89d2-4e138f6eef08 | control-2 | f74b2b00-0c01-44a5-917e-45fff058f2fa | None        | active             | True        |
    | 6a0533a2-d91f-4f45-acbb-5f5f231c8986 | compute-0 | None                                 | None        | available          | True        |
    | e8663954-4da8-4027-9226-f9f053f269d9 | compute-1 | 113afdbd-0afa-481c-a744-90276907b8e2 | None        | active             | True        |
    | 06679c73-97a2-4de0-b676-193a3e182fcf | compute-2 | None                                 | None        | available          | True        |
    | a6ef4bce-941c-407d-966e-85df2af3f6e1 | storage-0 | bbba571f-f2a9-46f3-a270-f154e045c5a8 | None        | active             | True        |
    | 6174dbb7-28e7-425e-b675-f1653f0b731c | storage-1 | d3afc0e8-70a0-43c4-b35a-693a7e4e5fa5 | None        | active             | True        |
    | 32e8122b-3a5f-45fb-8a5a-60dc4f82325f | storage-2 | 53ea0799-1bcd-4f55-8671-e6a7f7f46054 | None        | active             | True        |
    +--------------------------------------+-----------+--------------------------------------+-------------+--------------------+-------------+


This will show a list of nodes that are available in the environment. This information 


## Login to the overcloud
From the undercloud node you can source the stack resource file and use the
_openstack clients_ as usual.

```
[stack@undercloud ~]$ . overcloudrc
[stack@undercloud ~]$ cat overcloudrc
[stack@undercloud ~]$ nova list
```

In the previous output you also see the `OS_AUTH_URL` and the credentials
needed to login from the Horizon dashboard.

Either using ssh portforwaring, or the dynamic proxy option, you can open the
dashboard.
 
```
$ ssh -F ~/.quickstart/ssh.config.ansible undercloud -D 8080
```

Either using Firefox (with the FoxyProxy extension) or Chrome/Vivaldi (with the
SwitchySharp extension) you can set a SOCKS proxy at `127.0.0.1` and port
`8080`.


## Login to overcloud nodes
If you need to inspect a node in the overcloud (workload), you can login to these nodes from the undercloud using the following command:

```
[stack@undercloud ~]$ ssh [hostname/nodeip]
```

Note: you can find the hostnames and IP addresses on the _undercloud_ in the
`/etc/hosts` file. It will use 'heat-admin' as user to login.
 

## Scale out
After deployment, you might have noticed that `ironic node-list` returned a
list of baremetal nodes that are in _Provisioning state_ 'available' and do not
have an _Instance UUID_. These nodes have not been deployed to, as
`--compute-scale` had not been set.

To scale out to these nodes, you first need to change the `Maintenance` status
to false. You can do this for all available at once with:

```
[stack@undercloud ~]$ for i in $(ironic node-list | grep available | grep -v UUID | awk ' { print $2 } '); do
> ironic node-set-maintenance $i false;
> done
```

You can verify the status with `ironic node-list`.

After this you can scale out using
```
[stack@undercloud ~]$ openstack overcloud deploy --templates --libvirt-type qemu --control-flavor oooq_control --compute-flavor oooq_compute --ceph-storage-flavor oooq_ceph --timeout 60 --ntp-server pool.ntp.org --compute-scale 3
```

This will change the current _overcloud_ heat deployment and provision the
remaining nodes.

Eventually the command will return with:

    ...
    Stack overcloud UPDATE_COMPLETE
    Overcloud Endpoint: http://192.0.2.6:5000/v2.0
    Overcloud Deployed
    

after which the new nodes have been added to the _overcloud_. To update the
hosts entries in `/etc/hosts` you can rerun:

```
[stack@undercloud ~]$ ./overcloud-deploy-post.sh
```


## Diskimage building
The _undercloud_ images can be created using [ansible-role-tripleo-image-build](https://github.com/redhat-openstack/ansible-role-tripleo-image-build).
Using the following commands it will generate the images:

```
$ git clone https://github.com/redhat-openstack/ansible-role-tripleo-image-build.git
$ cd ansible-role-tripleo-image-build/tests/pip
$ sudo ./build.sh -i
$ ./build.sh $VIRTHOST
```

After the command finishes succesfully, the images can be found in
`/var/lib/oooq-images`.

Note: The content of `/var/lib/oooq-images` will be cleaned on run. After this
it will download a base image from
`http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2` of
about 800M. You can download this image and specify the location in a
configuration file to prevent it from having to be downloaded each time.

A create a file called: `override.yml`
```
artib_minimal_base_image_url: file:///var/lib/oooq-base-images/CentOS-7-x86_64-GenericCloud.qcow2
```

And pass this to the build command:
```
$ ./build.sh -e override.yml $VIRTHOST 
```


## Conclusion
Since the introduction of TripleO Quickstart, standing up a multi-node OpenStack
environment is very easy. In my knowledge-base article I describe also how you
can do a baremetal deployment using the Quickstart.

If you have any suggestion, please discuss below or send me an email.

Note: the original publication can be found at: [OpenStack hands-on-labs](https://gitlab.com/gbraad/openstack-handsonlabs)


## More information

  * Deployment [configuration options](https://github.com/openstack/tripleo-quickstart/blob/master/docs/configuring.md)
  * Knowledge-Base for [development/architecture notes](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/openstack/tripleo.md) on TripleO  
  * Openstack deployment [using RDO-Manager](https://remote-lab.net/rdo-manager-ha-openstack-deployment)

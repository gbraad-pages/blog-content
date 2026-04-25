---
Title: Deploying Kubernetes using Ansible
Date: 2016-09-26
Category: Containers
Tags: kubernetes, atomic, ansible, docker, centos, containers
---

Recently I did a lot of tests with Atomic, such as a [creating custom images](./deployment-of-ceph-using-custom-atomic-images.html) for [Ceph](./tag/ceph.html), and ways to provide an immutable infrastructure. However, Atomic is meant to be a host platform for a container platform using Kubernetes. Their [Getting Started guide](http://www.projectatomic.io/docs/gettingstarted/) describes how to setup a basic environment to host containerized applications. However, this is a manual approach and with the help of Vincent[*](https://blog.vanderkussen.org/deploy-kubernetes-with-ansible-on-atomic.html) I create a way to deploy this Kubernetes environment on Atomic and a standard CentOS installation using Ansible. In this article I will describe the components and provide instructions on how to deploy this basic environment yourself.


## Requirements
To deploy the Kubernetes environment you will need either [Atomic Host](http://www.projectatomic.io/download/) or a standard [CentOS](https://www.centos.org/download/) installation. If you are using this for testing purposes, a cloud image on an OpenStack provider will do. The described Ansible scripts will work properly on both Atomic Host and CentOS cloud images. Although it has not been tested on Fedora, it should be able to make this work with minimal changes. If you do, please contribute these changes back.

You will need at least 2 (virtual) machines. One will be configured as the Kubernetes master and the remaining node(s) can be configured as minions or deployment nodes. I have used at least 4 nodes; a general controller node to perform the deployment from (also configured to install the Kubernetes client), a master node and at least two deployment nodes. Take note that this deployment does not handle `docker-storage-setup` and High Availability.


## Setup for deployment
Almost all the deployments I perform are initiated from a short-lived controller node. This is a machine that allows
incoming and outgoing traffic, and mostly gets configured with an external Floating IP. This host can be seen as a jumphost. I will configure it with a dedicated set of SSH keys for communication with the other machines. You do not have to do this, and if you have limited resources, consider this host to be the same as the Kubernetes master node.

On this machine do the following:
```
$ yum install -y ansible git
$ git clone https://gitlab.com/gbraad/ansible-playbook-kubernetes.git
$ cd ansible-playbook-kubernetes
$ ansible-galaxy install -r roles.txt
```

This will install the Ansible playbook and the required roles:

    gbraad.docker
    gbraad.docker-registry
    gbraad.kubernetes-master
    gbraad.kubernetes-node
    gbraad.kubernetes-client

Each of the roles take care of the installation and/or configuration of the environment. Do take note that the Docker and Kubernetes roles do not install packages on the Atomic hosts as these already come with the needed software.


## Configure the deployment
If you look at the files `deploy-kubernetes.yml` you will see three tasks for a different group of hosts. As mentioned before, they will each take care of the installation when needed.

```
- name: Deploy kubernetes Master
  hosts: k8s-master
  remote_user: centos
  become: true
  roles:
  - gbraad.docker
  - gbraad.kubernetes-master

- name: Deploy kubernetes Nodes
  hosts: k8s-nodes
  remote_user: centos
  become: true
  roles:
  - gbraad.docker
  - gbraad.kubernetes-node

- name: Install kubernetes client
  hosts: k8s-client
  remote_user: centos
  become: true
  roles:
  - gbraad.kubernetes-client
```

Take notice of the setting of `remote_user`. On an Atomic host this is a passwordless sudo user, which can also login with SSH using a passwordless key-based authentication. If you use CentOS, please configure a user and allow add an entry with `echo "username ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/username`.

### Change the inventory
Ansible targets a playbook against a single or group of nodes that you specify in an inventory file. This file is named `hosts` in this playbook repository. When you open it you will see the same set of names as specified above in the `hosts` entry in the `deploy-kubernetes.yml` playbook. For our purposes you will always have to deploy a master and a node. If you do not specify the master node, the installation will fail as some of the deployment variables will be used for configuration of the nodes.

```
$ vi hosts
```

    [k8s-master]
    atomic-01 ansible_ssh_host=10.5.0.11

    [k8s-nodes]
    atomic-02 ansible_ssh_host=10.5.0.14
    atomic-03 ansible_ssh_host=10.5.0.13
    atomic-04 ansible_ssh_host=10.5.0.12


### Group variables
At the moment the roles are not very configurable as they are mainly targeting a simple test environment. Inside the folder `group_vars` you will find the configration for the Kubernetes nodes. These are as follows

```
skydns_enable: true
dns_server: 10.254.0.10
dns_domain: kubernetes.local
```


## Perform the deployment
After changing the variables in the `hosts` inventory file and the group variables, you are actually all set to perform the deployment. We will start with the following.

```
$ ansible-playbook -i hosts deploy-docker-registry.yml
```

This first step will install Docker on the master node and pull the Docker Registry container. This is needed to provide a local cache of container images that you have pulled.

After this we can install the Kubernetes environment with:
```
$ ansible-playbook -i hosts deploy-kubernetes.yml
```

Below I will describe what each part of the playbook does and some information about the functionality.


## Playbook and role description
Below I will give a short description of what each part of the playbook and role does.

### Role `gbraad.docker`
Each node in the playbook will be targeted with the following role: `gbraad.docker`. This role determines if the node is an Atomic Host or not. This check is performed in the `tasks/main.yml` file. It the node is not an Atomic Host, it will include `install.yml` to perform additional installation tasks. At the moment this is a simple package installation for `docker`. After this step, the role will set state `started` and `enabled` for the services; `docker`.

[Source](https://github.com/gbraad/ansible-role-docker)


### Role: `gbraad.kubernetes-master`
As part of the playbook, first we will configure the master node. For this, the role `gbraad.kubernetes-master` is used. Just like in the previous role, file `tasks/main.yml` will perform a simple check to determine if an Atomic Host is used or not. If not, some packages will be installed:

  * `kubernetes-master`
  * `flannel`
  * `etcd`

[Source](https://github.com/gbraad/ansible-role-kubernetes-master)


#### Configure Kubernetes
After this step Kubernetes will be configured on this hosts. Tasks are described in the file `tasks/configure_k8s.yml`, [source](https://github.com/gbraad/ansible-role-kubernetes-master/blob/master/tasks/configure_k8s.yml).


[Role](https://galaxy.ansible.com/gbraad/kubernetes-master)


##### Congfigure Kubernetes: etcd
This role will create a single 'etcd' server on the master. For simplicty all IP address will be allowed by using `0.0.0.0` as the endpoint. The port used for etcd clients is 2379, but since 4001 is also widely used we will also configure to use this.

Tasks:

  * Configure etcd LISTEN CLIENTS
  * Configure etcd ADVERTISE CLIENTS

##### Configure Kubernetes: common services
After this the role will set an entry in the file `/etc/kubernetes/config`. This is a general configuration file used by all the services. It sets the local IP address, identified as `default_ipv4_address` as etcd server and the kubernetes master nodes.

Tasks:

  * Configure k8s common services


##### Configure Kubernetes: apiserver
For the apiserer the file `/etc/kubernetes/apiserver` is used. We will configure it to listen on all IP address. An admission control plug-in is a piece of code that intercepts requests to the Kubernetes API server prior to persistence of the object. For this role we removed `ServiceAccount` which is normally used to limit the creation requests of Pods based on the service account.


##### Restart services
After this the services of the master node are `started` and `enabled`. These are:

  * `etcd`
  * `kube-apiserver`
  * `kube-controller-manager`
  * `kube-scheduler`


#### Configure flannel
For this environment we will use flannel to provide an overlay network. An overlay network exists on top of another network to provide a virtual path between nodes who use this overlay network. The steps for this are specified in `tasks/configure_flannel.yml` [source](https://github.com/gbraad/ansible-role-kubernetes-master/blob/master/tasks/configure_flannel.yml).

The configuration of flannel is controller by etcd. We will copy a file to the master node containing:

```
{
  "Network": "172.16.0.0/12",
  "SubnetLen": 24,
  "Backend": {
    "Type": "vxlan"
  }
}
```

This file is located in the role as `files/flanneld-conf.json`. Using `curl` we will post this file to etcd on the master.

Tasks:

  * Copy json with network config
  * Configure subnet


After these steps the Kubernetes master is configured.


### Role: `gbraad.kubernetes-node`
For the configuration of a Kubernetes node we use the role `gbraad.kubernetes-node`. Just like in the previous roles we determine in `tasks/main.yml` to install packages or not. For all the nodes we will configure:

  * SELinux
  * flannel
  * kubernetes specific settings

[Source](https://github.com/gbraad/ansible-role-kubernetes-node), [Role](https://galaxy.ansible.com/gbraad/kubernetes-node/)


#### Configure SELinux
Because I use persistent storage using NFS with Docker, I configure SELinux to set the boolean `virt_use_nfs`.


#### Configure flannel
In the tasks:

  * Overlay | configure etcd url
  * Overlay | configure etcd config key
  * Flannel systemd | create service.d
  * Flannel systemd | deploy unit file

We configure all the nodes to use the etcd instance on `k8s-master` as the endpoint for flannel configuration. These tasks configure the networking to use the flanneld provided bridge IP and MTU settings. Using the last two tasks we configure systemd to start the service.

After this change we will restart the `flanneld` service.


#### Configure Kubernetes
In the file `tasks/configure_k8s.yml` we do final configuration of the Kubernetes node to point it to the master node.

In the tasks:

  * k8s client configuration
  * k8s client configuration | KUBELET_HOSTNAME
  * k8s client configuration | KUBELET_ARGS

we configure how the node is identified.

In the tasks:

  * k8s client configuration | KUBELET_API_SERVER
  * Configure k8s master on client | KUBE_MASTER

we set the location of the API server and the master node. Both of these will point to the IP address of the `k8s-master`.

After this change we will restart the `kubelet` and `kube-proxy` service.


### After deployment
If all these tasks succeeded, you should have a working Kubernetes deployment. In the next steps we will perform some simple commands to verify if the environment works.


## Deploy client and verify environment
As you have noticed from the `hosts` inventory file, there is a possibility to specify a client host:

    [k8s-client]
    controller ansible_ssh_host=10.5.0.3

You do not have to deploy a kubernetes client using this playbook. It will install a single package, but you could also just use the statically compiled Go binary that is provided from the Kubernetes releases:

```
$ wget http://storage.googleapis.com/kubernetes-release/release/v1.3.4/bin/linux/amd64/kubectl
$ chmod +x kubectl
```

### Verify nodes
Oncae all the nodes have been deployed using the playbook, you canb verify communication. From a client node you can perform the following command:

```
$ kubectl --server=10.5.0.11:8080 get node`
```

    NAME             LABELS    STATUS
    10.5.0.12        <none>    Ready
    10.5.0.13        <none>    Ready
    10.5.0.14        <none>    Ready


### Schedule workload
If all looks good, you can schedule a workload on the environment. The following commands will create a simple `nginx` instance.


```
$ vi kube-nginx.yml
```

    apiVersion: v1
    kind: Pod
    metadata:
      name: www
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
              hostPort: 8080

This file described a Pod with a container called `nginx` using the 'nginx' image. To schedule it, do:

```
$ kubectl --server=10.5.0.11:8080 create -f kube-nginx.yml
```

    pods/www

Using the following command you can check the status:

```
$ kubectl --server=192.168.124.40:8080 get pods
```

    POD       IP            CONTAINER(S)   IMAGE(S)   HOST                            LABELS    STATUS    CREATED      MESSAGE
    www       172.16.59.2                             10.5.0.12/10.5.0.12             <none>    Running   52 seconds
                            nginx          nginx                                                Running   24 seconds

If you now open a browser pointing to the node Kubernetes used to create it ([http://10.5.0.12:8080/](http://10.5.0.12:8080/)), you will see an nginx welcome page.


## Conclusion
Setting up Kubernetes can be a daunting task as there are many different components involved. Kelsey Hightower has a very good guide, called [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) that will teach you how to deploy kubernetes manually on different cloud providers, such as AWS and the Google Compute Engine. After gaining some experience, it is advised to look at automation to deploy an environment, such as the the Ansible scripts that can be found in the [contrib](https://github.com/kubernetes/contrib) repository of Kubernetes. this allows you to stand up an environment with High Availability. The scripts described in this article should only serve as an introduction to gain understanding what is needed for a Kubernetes environment.

If you want a production-ready environment, please have a look at OpenShift. OpenShift deals with setting up a cluster of kubernetes nodes, scheduling workload and most important, how to set up images for deployment. This is done using what is called 'source to image'. This and OpenShift itself will be the topic of future articles.


## More information

  * Knowledge-base article about [Kubernetes on Atomic](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/atomic.md#kubernetes-on-atomic)
  * Knowledge-base article about [Kubernestes](https://gitlab.com/gbraad/knowledge-base/tree/master/technology/kubernetes)
  * Hands-on-Lab: [Kubernetes on OpenStack](http://gbraad.gitlab.io/kubernetes-handsonlabs/deploying-Kubernetes-on-OpenStack.html) (Not all material published yet)
  * Deploying Kubernetes [on Atomic hosts](https://blog.vanderkussen.org/deploy-kubernetes-with-ansible-on-atomic.html)

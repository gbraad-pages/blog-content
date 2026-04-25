---
Title: Deploy an OpenShift test cluster
Date: 2016-09-27
Category: Containers
Tags: openshift, kubernetes, containers, docker
---

In my previous article I described how I used an Ansible playbook and a few roles
to stand-up a Kubernetes test environment. In that article I mentioned that to
deploy a production-ready environment some work more was required. Luckily, it
is now very easy to stand up a production and enterprise-ready container
platform for hosting applications, called [OpenShift](https://www.openshift.com).
Through the years OpenShift has undergone a lot of changes, and the latest
version Origin v1.3 is very different from the original version. OpenShift sets
up a complete Kubernetes environment and with a set of tools it can take care of
the whole application lifecycle, from source to deployment. In this article I
will give an introduction to setting up a test environment for a developer.


## Setup machine
I will setup the environment on a standard Fedora 24 installation. You can use a
cloud image as all the needed packages will be specified. After installing the
machine, you login as a standard user, which can do a password-less sudo.

```
$ ssh fedora@89.42.141.96
$ sudo su -
#
```

### Install docker and client

From here all the commands will be run as root, unless otherwise specified.

```
$ dnf install -y docker curl
```

This will install the basic packages we need to setup the test cluster. Now from
a browser you open the following page: [https://github.com/openshift/origin/releases/tag/v1.3.0](https://github.com/openshift/origin/releases/tag/v1.3.0).
This shows the current deliverables for the OpenShift Origin v1.3 release. You
need to download the file called like `openshift-origin-client-tools-v1.3.0-[...]-linux-64bit.tar.gz`


```
$ curl -sSL https://github.com/openshift/origin/releases/download/v1.3.0/openshift-origin-client-tools-v1.3.0-3ab7af3d097b57f933eccef684a714f2368804e7-linux-64bit.tar.gz -o oc-client.tar.gz
$ tar -zxvf oc-client.tar.gz
$ mkdir -p /opt/openshift/client
$ cp ./openshift-origin-client-tools-v1.3.0-3ab7af3d097b57f933eccef684a714f2368804e7-linux-64bit/oc /opt/openshift/client/oc

```

Note: I do not install the binary in `/usr/bin` or `/usr/sbin` to prevent a
conflict with a packaged version, but also because this makes it easier for me
to work on a different version of the application. E.g. the current packaged
version is v1.2 and does not provide the command we will be using in the next
step.


### Configure docker
To allow OpenShift to pull and locally cache images, it will deploy a local
docker registry. But before docker would be able to use this, we need to
specify an insecure registry in the configuration. For this you need to add
`--insecure-registry 172.30.0.0/16` to `/etc/sysconfig/docker`.

```
$ vi /etc/sysconfig/docker
```

    OPTIONS='--selinux-enabled --log-driver=journald --insecure-registry 172.30.0.0/16'

After this we will setup to allow the standard user to communicate with the
docker daemon over the docker socket. This is not a necessary step, and does not
make the system more secure. It does make it easier not having to move between
user and using sudo all the time.


```
$ groupadd docker
$ usermod -a -G docker fedora
$ chgrp docker /var/run/docker.sock
```

Edit: I recently created an [Ansible playbook](https://github.com/gbraad/ansible-playbooks/blob/master/playbooks/enable-ansible-user-for-docker.yml)
to perform these steps, as I had to do this on several Atomic hosts. I uses the
current Ansible user and adds it to a group, and changes the socket permissions.

After this you can start docker and move on the actual installation of OpenShift.

```
$ systemctl enable docker
$ systemctl start docker
```

Note: we will be running this environment with devicemapper as Storage Driver.
This is not an ideal situation. If you do further tests, consider changing the
storage with `docker-storage-setup` to use a dedicated volume.


## Running OpenShift
Since version 1.3 of OpenShift, the client provides a `cluster up` commands
which stands up a very simple all-in-one cluster, with a configured registry,
router, image streams, and default templates.

As the fedora user, you can check if you can access docker
```
$ docker ps
```

    CONTAINER ID    IMAGE   COMMAND     CREATED     STATUS      PORTS   NAMES

No containers should be returned. This mean you can communicate with the docker
daemon. Now you are ready to start the test cluster. 


### `cluster up`

```
$ export PATH=$PATH:/opt/openshift/client/
$ ./oc cluster up
-- Checking OpenShift client ... OK
-- Checking Docker client ... OK
-- Checking Docker version ... OK
-- Checking for existing OpenShift container ... OK
-- Checking for openshift/origin:v1.3.0 image ... OK
-- Checking Docker daemon configuration ... OK
-- Checking for available ports ... OK
-- Checking type of volume mount ... 
   Using nsenter mounter for OpenShift volumes
-- Creating host directories ... OK
-- Finding server IP ... 
   Using 10.5.0.27 as the server IP
-- Starting OpenShift container ... 
   Creating initial OpenShift configuration
   Starting OpenShift using container 'origin'
   Waiting for API server to start listening
   OpenShift server started
-- Installing registry ... OK
-- Installing router ... OK
-- Importing image streams ... OK
-- Importing templates ... OK
-- Login to server ... OK
-- Creating initial project "myproject" ... OK
-- Server Information ... 
   OpenShift server started.
   The server is accessible via web console at:
       https://10.5.0.27:8443

   You are logged in as:
       User:     developer
       Password: developer

   To login as administrator:
       oc login -u system:admin
```

And that was it! Now you are running an OpenShift environment. You can check
this as follows:

```
$ docker ps
```

    CONTAINER ID        IMAGE                                     COMMAND                  CREATED             STATUS              PORTS               NAMES
    cebba70022a6        openshift/origin-haproxy-router:v1.3.0    "/usr/bin/openshift-r"   16 seconds ago      Up 15 seconds                           k8s_router.9426645a_router-1-o3454_default_ba2e0814-8483-11e6-924a-fa163e29da46_e9a13a8d
    32aa5e84a04d        openshift/origin-docker-registry:v1.3.0   "/bin/sh -c 'DOCKER_R"   17 seconds ago      Up 15 seconds                           k8s_registry.f0a205a4_docker-registry-1-v57os_default_b9fc0130-8483-11e6-924a-fa163e29da46_24863324
    03ee38d125cb        openshift/origin-pod:v1.3.0               "/pod"                   18 seconds ago      Up 16 seconds                           k8s_POD.4a82dc9f_router-1-o3454_default_ba2e0814-8483-11e6-924a-fa163e29da46_ea6d1d08
    44d6f8d2d9d6        openshift/origin-pod:v1.3.0               "/pod"                   18 seconds ago      Up 16 seconds                           k8s_POD.9fa2fe82_docker-registry-1-v57os_default_b9fc0130-8483-11e6-924a-fa163e29da46_76754271
    60e7cc5f4e5d        openshift/origin-deployer:v1.3.0          "/usr/bin/openshift-d"   21 seconds ago      Up 19 seconds                           k8s_deployment.59c7ba3f_router-1-deploy_default_b3660c7b-8483-11e6-924a-fa163e29da46_8e02f47a
    f1fe993ddcac        openshift/origin-pod:v1.3.0               "/pod"                   22 seconds ago      Up 20 seconds                           k8s_POD.4a82dc9f_router-1-deploy_default_b3660c7b-8483-11e6-924a-fa163e29da46_9a38fe5e
    72068a244ac8        openshift/origin:v1.3.0                   "/usr/bin/openshift s"   49 seconds ago      Up 48 seconds                           origin


### Client connection
After running the command `oc cluster up` you will be automatically logged in.
For this it writes the login configuration in `~/.kube/`. If you want to change
you can login using:

```
$ oc login
```

The standard user provided is `developer`.


### Verify
Now we need to verify if we can deploy a simple application. However, without
changes, OpenShift will not run containers with a root-user process. For example
an nginx container would fail with a `permission denied` error.

Instead, we will for now run a simple Hello container:
```
$ oc run hello-openshift --image=docker.io/openshift/hello-openshift:latest --port=8080 --expose
```

    service "hello-openshift" created
    deploymentconfig "hello-openshift" created

This would create the container and schedule it. You can check the progress with:
```
$ oc get pod
```

    NAME                        READY     STATUS    RESTARTS   AGE
    hello-openshift-1-xi7f0     1/1       Running   0          9m

You will also see a `-deploy` container. This is not needed for our verification.

To check the application, we need to get the IP address that has been assigned
to the Pod. You can do this as follows:

```
$ oc get pod hello-openshift-1-xi7f0 -o yaml | grep podIP
```

      podIP: 172.17.0.7

All you have to do now is open the endpoint:

```
$ curl 172.17.0.7:8080
```

    Hello OpenShift!

And that is it, you have a working OpenShift test cluster.


### Teardown 
If you are down with this, you simply do a:
```
$ oc cluster down
```

and all the containers used in the deployment will be torn down.


## Conclusion
Using OpenShift's `cluster up` command you can easily setup an environment for
developers to run and test their applications. The current of OpenShift
provided with Fedora 24 does not offer this command, as the packaged version is
v1.2. However, this change is in Rawhide and is therefore expected to be
released as part of Fedora 25.

In future articles I will detail more about how to create applications for the
OpenShift container platform, and how to check and maintain the life cycle of
the deployed application. For now, take a look at the other source of
information below.


## More information

  * OpenShift [Homepage](https://www.openshift.com/)
  * [OpenShift Origin](https://github.com/openshift/origin) at GitHub
  * Knowledge-base article about [OpenShift](https://gitlab.com/gbraad/knowledge-base/blob/master/technology/openshift.md)

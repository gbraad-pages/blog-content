---
Title: Run an example application on OpenShift
Date: 2016-09-29
Category: Containers
Tags: containers, openshift, example, ruby, docker, devops
---

In a [previous article][article deployment] I have written
on how easy it is to stand up a test environment of OpenShift. In this article
I will describe an example application from the sourcecode to the created image
and how this gets deployed. The steps are explained using manual steps, and how
OpenShift does it all automated. You will notice, at no point do you have to
write a `Dockerfile`.


## Preparation
For this article it is not necessary to have a working test environment, however
it does make things clearer. I would suggest you to use OpenShift Origin v1.3 on
CentOS 7. Although my previous article showed how to get it up and running on
Fedora 24, I experienced an issue with deployment not succeeding[*][external issue].
The steps in the deployment article can be performed by replacing `dnf` with
`yum`. 


## Description of the example
The OpenShift project publishes several test applications on GitHub, of which
one is a very simple Ruby applica8080. Please, have a look at: [http://github.com/openshift/ruby-ex][external example]

You will see it consists of four files:

  * `Gemfile`
  * `Gemfile.local`
  * `config.ru`
  * `README.md`

The application itself is only described in `config.ru` and the needed dependencies
are in `Gemfile`.


### Dependencies

To make the application work, we first need:

```
$ gem install bundler
```

This will install `bundler` that can install dependencies as described in the
`Gemfile`. This file describes:

    source 'https://rubygems.org'
    gem 'rack'
    gem 'puma'

The first line says `source` which points to a gem repository, and each line
starting wih `gem` are bundled packages containing libraries for use in your
project. To install all of the required gems (dependencies) from the specified
sources:

```
$ bundle install
```

The file `Gemfile.lock` is a snapshot of the Gemfile and is used internally.


### config.ru
The application is specified in the file called `config.ru`. If you open the
file you will see it contains route mappings, lines starting  with `map`, for
three urls:

  * `/health`
  * `/lobster`
  * `/`

#### `/health`
This is a commonly used to provide a simple health-check for applications that
are automatically deployed. It allows to quickly test if the application got
deployed. In projects I worked on, we also did quick dependency checks, such as
a configuration file exists, or another needed endpoint is available. In this
application it will respond with a HTTP status code 200 and returns `1` as
value.

#### `/lobster`
This is a test provided by rack. It shows an ASCII-art lobster. By adding a
variable to the URL querystring `?flip=left` the direction can be changed.

#### `/`
This is the mapping to a bare route. It shows a greeting message on how to use
the application using OpenShift to trigger automated builds.


### Rackup
Rack is an interface for using Ruby and Ruby frameworks with webservers. It
provides an application called `rackup` to start the application:

```
$ bundle exec rackup -p 8080 config.ru
```

Using this command the webserver will bind to port 8080, according to the
description in the `config.ru` file. To see what the mappings do, open:

  * [http://localhost:8080/health][example health]
  * [http://localhost:8080/lobster][example lobster]
  * [http://localhost:8080/][example bare]


## Use the example with OpenShift
Deploying an application on OpenShift from source is very simple. A single
command can do this. First have a look

```
$ oc new-app openshift/ruby-20-centos7~https://github.com/[username]/ruby-ex
```

But before we do, I will explain what this command does. Oversimplified
OpenShift does two things:

  1. Build
  2. Deploy


Note: If you want to perform the command, go ahead. Please fork the repository
and change the `[username]` in this command.


### Build: source to image
OpenShift runs container images which are in the Docker format. It will run
the `CMD` instruction for this. So, how does OpenShift know what to run?
Convention. Most frameworks have a standard way of doing things, and this is
as you noticed also the case with the Ruby example. The creation of the image
happens with a tool called source-to-image (S2I).

[Source-to-Image (S2I)][external s2i] is a toolkit and workflow for building
reproducible Docker images from source code. It uses a base image, and will
layer the application on top, configures the runn command, which then results in
a containter image for use.

```
$ s2i build https://github.com/[username]/ruby-ex openshift/ruby-20-centos7 ruby-ex
```

#### base image
The base image here is [openshift/ruby-20-centos7][external baseimage]. The source
of this image can be found at the following GitHub repository: [s2i-ruby-container][external basesource]

If you look at the `Dockerfile` [source][external basedockerfile], you will see
[Software Collections][external scl] is used to install a specific Ruby version.
In this case version 2.0. Software collections solves one of the biggest
complaints of using CentOS (or RHEL) as a basis as part of your delivery. It
allows you to use multiple versions of software on the same system, without
affecting system-wide installed packages.

The image also describes a label `io.openshift.expose-services="8080:http"`
which inidcate that the application on port 8080 will be exposed as HTTP
traffic. This also means the container does not need root privileges as the port
assignment is above 1024. The application itself will be installed into the
folder: `/opt/app-root/src`.

Running this container can be done with:

```
$ docker run -p 8080:8080 ruby-ex
```

    [1] Puma starting in cluster mode...
    [1] * Version 3.4.0 (ruby 2.0.0-p645), codename: Owl Bowl Brawl
    [1] * Min threads: 0, max threads: 16
    [1] * Environment: production
    [1] * Process workers: 1
    [1] * Phased restart available
    [1] * Listening on tcp://0.0.0.0:8080
    [1] Use Ctrl-C to stop
    [1] - Worker 0 (pid: 32) booted, phase: 0

Open the links as previously stated will yield the same results.

```
$ curl http://localhost:8080/health
```

The build process can be as simple as a copy for static content, to compiling
Java or C/C++ code.  For the purpose of this article I will not explain more
about the S2I process, but this will certainly be explained in future articles.


## New application
If we now look at the previous command again:

```
$ oc new-app openshift/ruby-20-centos7~https://github.com/[username]/ruby-ex
```

you can clear see the structure. The first element `openshift/ruby-20-centos7`
describes the S2I container image for Ruby as hosted at the Docker hub. The
second part is the source code path pointing to a git repository.

Please try the command now... OpenShift will create containers for each of the
stages used: `build`, `deploy` and the final running container. You can check
the containers using the command:

```
$ oc get pod
```

    NAME               READY     STATUS         RESTARTS   AGE
    ruby-ex-1-build    0/1       Completed      0          1m


### Build stage
If you create this new application, a new container named `ruby-ex-1-build`.
What happened is that the Source-to-image container got pulled which uses the 
base image and layers the source code on top.

To see what happened, as with the previous command, you can see the build
configuration:

```
$ oc logs bc/ruby-ex
```

    Cloning "https://github.com/gbraad/ruby-ex" ...
            Commit: f63d076b602441ebd65fd0749c5c58ea4bafaf90 (Merge pull request #2 from mfojtik/add-puma)
            Author: Michal Fojtik <mi@mifo.sk>
            Date:   Thu Jun 30 10:47:53 2016 +0200
    ---> Installing application source ...
    ---> Building your Ruby application from source ...
    ---> Running 'bundle install --deployment' ...
    Fetching gem metadata from https://rubygems.org/...............
    Installing puma (3.4.0)
    Installing rack (1.6.4)
    Using bundler (1.3.5)
    Cannot write a changed lockfile while frozen.
    Your bundle is complete!
    It was installed into ./bundle
    ---> Cleaning up unused ruby gems ...
    Pushing image 172.30.108.129:5000/myproject/ruby-ex:latest ...
    Pushed 0/10 layers, 10% complete
    Pushed 1/10 layers, 34% complete
    Pushed 2/10 layers, 49% complete
    Pushed 3/10 layers, 50% complete
    Pushed 4/10 layers, 50% complete
    Pushed 5/10 layers, 50% complete
    Pushed 6/10 layers, 61% complete
    Pushed 7/10 layers, 71% complete
    Pushed 8/10 layers, 88% complete
    Pushed 9/10 layers, 99% complete
    Pushed 10/10 layers, 100% complete
    Push successful


The difference is that the resulting image will be placed in the `myproject`
namespace, and pushed to the local repository.

### Deployment stage
After the image has been composed, OpenShift will run the container image on the
scheduled node. What happens here can be checked with:

```
$ oc get pod                                                                                                                                                          
```

    NAME              READY     STATUS      RESTARTS   AGE
    ruby-ex-1-an801   1/1       Running     0          26s
    ruby-ex-1-build   0/1       Completed   0          1m

This means that the build succeeded, the image got deployed and now runs in the
a container identified with `ruby-ex-1-an801`. Note: The container
`ruby-ex-1-deploy` is not shown here as only the logs are of importance.

The deployment configuration logs can be shown with:

```
$ oc logs dc/ruby-ex
```

    [1] Puma starting in cluster mode...
    [1] * Version 3.4.0 (ruby 2.0.0-p645), codename: Owl Bowl Brawl
    [1] * Min threads: 0, max threads: 16
    [1] * Environment: production
    [1] * Process workers: 2
    [1] * Phased restart available
    [1] * Listening on tcp://0.0.0.0:8080
    [1] Use Ctrl-C to stop
    [1] - Worker 0 (pid: 32) booted, phase: 0
    [1] - Worker 1 (pid: 35) booted, phase: 0

### Events
To see the flow of execution, you can have a look at:

```
$ oc get events
```

This can be helpful if an error occured.


### Verify
Now that the application has been deployed on OpenShift, we need to look up the 
IP address that has been assigned. For this we use:

```
$ oc get svc
```

    NAME      CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
    ruby-ex   172.30.91.160   <none>        8080/TCP   21h

Now we can open the application as `http://172.30.91.160:8080/`


## Conclusion
OpenShift allows you to run prebuilt images or applications based on source.
The Source-to-image tooling makes it possible to create reproducible images for
deployment of applications based on source. This tool itself is very helpful
and is certainly something I will be using, even outside the use of OpenShift.
There is no need to create or modify a `Dockerfile`, which means that the
developer can focus on the development process.

If you want to know more about the automated builds, please have a look at the
README of the [Ruby example][external example]. In future articles more 
detailed descriptions about these topics will certainly be given. I hope this
has been helpful. Please consider leaving feedback or tweet this article.


[article deployment]: ./deploy-an-openshift-test-cluster.html "Deploy an OpenShift test cluster"

[external issue]: https://lists.openshift.redhat.com/openshift-archives/users/2016-September/msg00198.html "Deployment of ruby-ex times out"
[external example]: https://github.com/openshift/ruby-ex "Ruby example"
[external s2i]: https://github.com/openshift/source-to-image/ "Source-to-image"
[external baseimage]: https://hub.docker.com/r/openshift/ruby-20-centos7 "Ruby base image"
[external basesource]: https://github.com/sclorg/s2i-ruby-container/ "Ruby base image source"
[external basedockerfile]: https://github.com/sclorg/s2i-ruby-container/blob/master/2.0/Dockerfile "Ruby base Dockerfile"
[external scl]: https://www.softwarecollections.org/en/ "Software Collections"

[example health]: http://localhost:8080/health "Example health-check"
[example lobster]: http://localhost:8080/lobster "Example lobster"
[example bare]: http://localhost:8080/ "Example bare"

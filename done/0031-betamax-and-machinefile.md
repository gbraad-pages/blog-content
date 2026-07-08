---
Title: Betamax, Machinefile and a roll of Ducttape
Date: 2026-07-08
Category: Infrastructure
Tags: virtual machines, containers, infrastructure, development
---


# Betamax, Machinefile and a roll of ducttape
### Choosing Convenience over the "Best" Standard

![](https://avatars.githubusercontent.com/u/296723703?s=140&v=4)

In infrastructure-as-code, the best technical solution does not always win.

Take machine provisioning. Fedora CoreOS's Ignition is engineered better than cloud-init. Ignition runs early in the initramfs before the root filesystem even mounts. It parses strict JSON and fails instantly if a configuration error occurs. It is predictable.

### Introduction
Yet, cloud-init won the format war. Like VHS beating Betamax, `cloud-init` became the de facto industry standard because it was everywhere, used simple YAML, and was easy to adopt. It won on convenience, not engineering perfection. When you build machine setups or developer environments, you face this exact trade-off.

In this article I will show you my solution to a container and virtual machine setup, how I automated this and how this led to the development of Machinefile, and eventually [Ducttape](https://github.com/ducttape-infra/ducttape).

### Containers and virtual machines
To understand why modern development environment workflows look the way they do, you have to trace how we isolate and deploy software. We went from heavy, emulated hardware to ultra-lightweight application layers, and finally to a hybrid reality where operating systems are managed exactly like containers.

Understanding this evolution is the key to seeing why tools like bootc and Machinefile exist

#### Virtual Machines: The Foundation of Isolation
For decades, the standard way to isolate environments was the Virtual Machine (VM). A VM emulates an entire physical computer. It bundles an application, its dependencies, and a complete guest operating system—including its own dedicated kernel—running on top of a hypervisor.

Virtual Machines provide isoltation and platform independence as it runs its own kernel, or evcen a different Operating System, likle FreeBSD or Windows. This however feels heavy due to the use of memory.

#### Containers
Containers solved the weight problerm by shifting the isolation boundary. Instead of emulating the hardware and running a kernel, a container shares the host machine's Linux kernel. It uses kernel features like namespaces and cgroups to isolate the application process and it's files.

This makes it possible to start these environments in seconds as there is less overhead. The standardized configuration format, like `Dockerfile` (or `Containerfile`) eased with consistent creation.

#### Bootable Containers
This brings us to the modern solution: bootc (bootable containers). Instead of using a `Containerfile` merely to build an app that runs inside an operating system, bootc applies the container model to the entire host operating system itself.

You start a virtual machine from a container image and it provides immutability and an atomic update process.

### The issue and the why
While bootc is an excellent deployment standard, forcing a developer into full image builds during early-stage development introduces unnecessary friction. This is why I created an intermediate solution; `Machinefile`. 

The goal isn't to exclude bootc, but to choose a pragmatic tool built for developer speed that augments it, and allow you to use a single solution for containers, virtual machines and allow eventually to even use Bootc. 

In the age of AI agents I found the isolation very beneficial, and with tooling I improved the deployment and ease to experiment.


### Machinefile
To see how this works, you can look at how I created my developer environment. In projects like [`gbraad-devenv/fedora`](https://github.com/gbraad-devenv/fedora), base images are built automatically via CI/CD pipelines. The pipeline generates multiple formats from the same source at the same time: standard containers, immutable bootc disk images, and cloud disk images.

When a developer needs a localized workspace, local orchestration tools like macadam, KVM, or Lima take over. They boot that pre-baked cloud image and apply configurations using cloud-init.

This provides convenience and speed without sacrificing the end goal. It gives the developer two things:

 * Consistency: The local VM matches the production container or bootc target.
 * Isolation: The developer gets a dedicated kernel and a secure sandbox.

This led me to create this as part of my [`dotfiles`](https://github.com/gbraad-dotfiles), and tools to start a containerized image with `devenv`, or a virtual machine with `machine`.


### How Machinefile Works
While tools like Packer and vagrant already deel with customize dlocal developmenrt environments, I wanted to use a familiar configuration; the `Containerfile`.  The [machinefile](https://github.com/ducttape-infra/machinefile) CLI is a lightweight executor written in Go.

You start a cloud image using a tool like Lima, packer or macadam, and execute the statements inside the Machinefile against this. It acts as a direct translator between container syntax and your system via simple shell run commands.

The end result is a disk image according to what the container would be.


### Ducttape VM
Since this was normnally coordinated from a `machine.zsh` script in my dotfiles, I create a new tool called `ducttape` that uses `machinefile` as a library, uses Lima to boot the VM with cloud-init, and creates a completely self-contained binary to handle the build process, running and sharing.

`Machinefile`
```Dockerfile
Machinefile
FROM fedora-cloud:44

RUN dnf install -y httpd && \
    dnf clean all && \
    systemctl enable httpM
```

#### Build
```sh 
$ ductttape build -t my-httpd -f Machinefile
```

#### Run
```sh
$ ducttape run my-httpd --publish 8080:80
```

#### Share
```sh
$ ducttape push my-httpd ghcr.io/ducttape-infra/fedora-httpd
```
```sh
$ ducttape run ghcr.io/ducttape-infra/fedora-httpd -n http-server
```

### Expanding to Non-Linux
Crucially, this simple translation also breaks down operating system barriers. Container images and `bootc` are strictly bound to Linux kernels. But because `Machinefile` strips away the container engine requirements, you can reuse the exact same syntax on environments where containers cannot natively run.

Look at [`gbraad-dotfiles/freebsd`](https://github.com/gbraad-dotfiles/freebsd) as an example. In this setup, a standard Containerfile format is repurposed to provision a FreeBSD virtual machine.

This decouples your configuration layout from a single operating system type. You get a single, unified mental model for setting up environments across entirely different kernels.


### Conclusion
This simplicity gives you a fast shortcut. During the early, messy stages of development, you do not want to wait on a pipeline or re-provision a VM. You just want to change a config line and see if it works instantly.

The solution here does not exclude containers or bootc. Instead, Machinefile and Ducttape augments it by providing consistency. Because Machinefile uses near-identical file syntax to your final bootc target, you do not create technical debt. You use one familiar syntax for local hacking, local VM provisioning, and final production builds.

Machinefile is a choice based on context. It does not replace immutable systems; it accelerates them. It proves that reuse, familiarity, and removing human friction matter more than chasing the perfect standard.

### Example Forgejo
To demonstrate that this process can be applied to containers, virtual machines and eventually upgrade to bootable containers, you can have a look at the [Forgejo example](https://github.com/ducttape-lab/forgejo).

Moving from a running cloud image to `bootc` can be done with
```sh
$ dnf -y install system-reinstall-bootc
$ system-reinstall-bootc ghcr.io/ducttape-lab/forgejo-bootc:latest
$ reboot
```

This makes immutability a choice, instead of a requirement. When dealing wth an AI agent, you want to allow installing development tools, but also easy recreation, treating them as ephemeral. For this see [`debian-claude`](github.com/ducttape-infra/examples/tree/main/debian-claude) as an example.

### What's next
I will work more on this tool in future, expecially as one of the arguments is the speed of starting and overhead it has; you are still starting a full virtual machine. And in this age of AI agents and GPU acceleration needs, a leaner approach is needed.

I will be working on a MicroVM apprach, so instead of full host emulation, instead `virtio-mmio` will be used. Solutions like cloud-hypervisor and krun already utilize this. Machinefile can already be utilized as a CLI tool for them, but ideally I want this to be part of Ducttape to prepare images, share and convert, and eventually run them on targets in a supported workflow.

Even if you do not want to use Lima, ducttape and machinefile are still ideal tools for your automation; this can be seen from the [`Packer-machinefile` example](https://github.com/ducttape-infra/packer-machinefile/), the goal of ducttape is to augment your process, to stick them together but allow to be replaced or improved when needed.

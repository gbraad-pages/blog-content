---
Title: "Replace scripts with Ansible: package installation"
Date: 2016-10-03
Category: DevOps
Tags: deployment, configuration, ansible, devops
---

Installing and configuring software on one machine, for instance your own
developer's environment, is an 'easy' task. But how about your team? Or
production? Everything is documented and you only probably install some of the
components manually, or better, you automate this using a set of shell scripts.
The environment is now reproducible. Everything is fine.

Running a set of scripts is not a bad idea, but often what lacks is the
maintenance on them or just the magic contained in them. I do not
have to make the case for general configuration management,
'configuration as code' or even #DevOps I hope? In this article I will show why
I use Ansible for almost all my scripts. Even small one of.

## Environment
Although I have a preference for the operating system and distribution I use, I
have to deal with many different versions and variants. On my workstation I
prefer to use Fedora, but at work we deploy on CentOS. Some of my colleagues
tend to prefer Ubuntu (latest), and customers are stuck on LTS releases. A very
common situation. In one week, I had to deal with: Alpine, CentOS, Fedora,
Ubuntu, (Open)SUSE, Debian, Windows, etc. This is of course an extreme case.

You would prefer to use a single environment for both development and
production. When the production environment is fixed, the solution is easier.
You will likely use a tool like Vagrant to stand up an environment, or some
other virtualization soltuion. But what if you develop for an environment where
both Ubuntu and CentOS are an option? In my case this happens a lot because of
work for OpenStack, or just general Linux tool development.


## Example
Below I will discuss a small example of dealing with package installation. Let's
consider you have to use Ubuntu and Fedora. This means that you already have to
deal with two different package managers, oh wait, three; `apt` on Ubuntu and
`yum` or `dnf` on Fedora.


### Bash script
As a crude solution, you could do the following:

```bash
#!/bin/sh
APTPKGS="git tmux zsh mc stow python-psutil"
RPMPKGS="git tmux zsh mc stow python-psutil"

# Crude multi-os installation option
if [ -x "/usr/bin/apt-get" ]
then
   sudo apt-get install -y $APTPKGS
elif [ -x "/usr/bin/dnf" ]
then
   sudo dnf install -y $RPMPKGS
elif [ -x "/usr/bin/yum" ]
then
   sudo yum install -y $RPMPKGS
fi
```

This basically checks if a certain executable is available, and will use that
with a defined list of packages to install. If both `yum` and `dnf ` is
installed, it will in this case use `dnf` as it resolves first. This is likely
what you want, but it is hidden logic. But what if you have installed `yum` on
Ubuntu? Also, because of this case, `apt-get` will resolve first. But again,
this is undocumented in this script. But this knowledge should not be needed.

Note: in this case, the packages are the same for both platforms, but this is
not a guarantee. Therefore I use a variable for this.

### Ansible playbook
Ansible solves this problem by offering a general `package` module. You can use
`yum` and `apt` specific options, but I prefer to use `package` instead. Below 
is a playbook that has the same behaviour as the above mentioned script:

```yaml
  tasks:
  - name: Install list of required packages
    package: name={{ item }} state=installed
    become: yes
    become_method: sudo
    with_items:
    - git
    - tmux
    - zsh
    - stow
    - python-psutil
    - mc
```

Because of the task name, it becomes clear what the intention is of the commands
that follow. In this case, this will use the package manager based on the OS
Family that Ansible will find. This means we do not need to have the knowledge
of what to pick first. There is however a problem. What if the packages have
different names?

### Conditionals
For this Ansible offers conditionals which you can use with `when`. Below is
an example that will install the development tools on Ubuntu or Fedora, based
on the `ansible_distribution`:

```yaml
#!/usr/bin/env ansible-playbook
---
- hosts: localhost
  #remote_user: root
  become_method: sudo

  tasks:
  - name: Install Git
    package: name=git state=installed
    become: yes

  - name: install the 'Development tools' package group
    package: name="@Development tools" state=present
    when:  ansible_distribution == 'CentOS' or
           ansible_distribution == 'Red Hat Enterprise Linux' or
           ansible_distribution == 'Fedora'
    become: yes
    
  - name: Install the 'build-essential' meta package
    package: name="build-essential" state=present
    when: ansible_distribution == 'Debian' or
          ansible_distribution == 'Ubuntu'
    become: yes
```

You can also use `ansible_os_family == "RedHat"` to be less specific about the
distribution you are on.

### Include
You can combine conditionals with almost anything in Ansible, for instance to
include or not another playbook. Below is a simple solution of this when you
want to split the install instructions into separate files.

```
- include: install-centos.yml
  when: ansible_distribution == "CentOS"

- include: install-ubuntu.yml
  when: ansible_distribution == "Ubuntu"
```

### Conclusion
With Ansible it is possible to create complex instructions that can be more
maintainable than when using just scripts. Of course, just using Ansible will
not act as a silver bullet. But because a playbook is more readable, the process
of refactoring is easier.

In future articles I will talk about other aspects where the move to Ansible
helped me. However, the bootstrap process remains... I wish there was a way to
[Automate everything](https://github.com/gbraad/automate-everything) ;-)

Hope this article has been helpful to you. If so, please consider tweeting about
it. Or leave a comment if you have suggestions...

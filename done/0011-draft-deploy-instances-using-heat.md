---
Title: Deployment using OpenStack Heat
Date: 2016-9-11
Status: draft
Category: OpenStack
Tags: heat, openstack
---


## Prerequisites
If installing with PackStack, you can install OpenStack Heat by specifying
`--os-heat-install=y` on the command-line as parameter, or setting
`CONFIG_HEAT_INSTALL=y` in your answers file.

On the client node, you need the following tools:

```
$ yum install -y python-virtualenv
$ virtualenv venv
$ source venv/bin/activate
(venv) $ pip install python-heatclient
```


## Example deployment
Use the file `create-instance.yml`

```
heat_template_version: 2016-04-08

description: A simple template to deploy Cirros as a single compute instance

parameters:
  image:
    type: string
    label: Image name or ID
    description: Image to be used for compute instance
    default: cirros
  flavor:
    type: string
    label: Flavor
    description: Type of instance (flavor) to be used
    default: m1.small
  key:
    type: string
    label: Key name
    description: Name of key-pair to be used for compute instance
    default: my_key
  private_network:
    type: string
    label: Private network name or ID
    description: Network to attach instance to.
    default: private

resources:
  my_instance:
    type: OS::Nova::Server
    properties:
      image: { get_param: image }
      flavor: { get_param: flavor }
      key_name: { get_param: key }
      networks:
        - network: { get_param: private_network }

outputs:
  instance_ip:
    description: IP address of the instance
    value: { get_attr: [my_instance, first_address] }
```

and create the stack:

```
(venv) $ heat stack-create my_stack -f create-instance.yaml -P "key=gbraad;image=Fedora-23"
```

To see the output of the heat stack:

```
(venv) $ heat stack-show my_stack
```


## Resource Group

```
(venv) $ heat stack-create my_group -f create-instance-group.yaml -e environment-create-instance.yaml
```


## Templates
The templates used in this hands-on-labs are available at:

  * https://github.com/gbraad/openstack-heat-templates

## References

  * http://docs.openstack.org/developer/heat/template_guide/index.html
  * https://review.openstack.org/#/c/119015/2
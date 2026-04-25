---
Title: Setup OpenStack Keystone for testing purposes
Date: 2016-10-27
Category: OpenStack
Tags: openstack, keystone, docker, containers, authentication
---

OpenStack can be seen as a set of projects which combined into a configuration
can deliver a management solution for different use-cases. However, several of
these projects can also exist on their own to provide a certain functionality,
such as Keystone, Ironic, etc. Some of these I will describe in articles on this
blog, but let's start with one of the most important one's that deal with
Authenticatioin, namely Keystone.


## Keystone
Keystone is one of the core projects of OpenStack and is responsible for
providing Identity. It offersauthentication, authorization and service
discovery mechanisms via HTTP. Especially this last property, offering the API
to be accessed by HTTP as a ReSTful interface offers a lot of opportunities for
re-use. More about the Keystone project can be found on the
[project homepage](http://docs.openstack.org/developer/keystone/).


## Containerized
To simplify the deployment process, I have containerized Keystone. The image can
be found at [GitLab](https://gitlab.com/gbraad/openstack-keystone) and the
[Docker Registry](https://hub.docker.com/r/gbraad/openstack-keystone/).


### `Dockerfile`
The image is based on a standard CentOS 7 cloud image. To install Keystone, I
used the packaged version from the [RDO project](//www.rdoproject.org). After
an update, it install the repository information pointing to mitaka, and then
it install the Keystone service, some useful utils to use with OpenStack and
the SELinux configuration files.

```
RUN yum update -y && \
    yum install -y centos-release-openstack-mitaka && \
    yum install -y openstack-keystone openstack-utils openstack-selinux && \
    yum clean all
```

After this we expose the ports that Keystone uses for interaction.

```
EXPOSE 5000
EXPOSE 35357
```

As the `CMD` it will run a simple initialization script. It takes care to setup
an admin token and use a MySQL connection. It then starts `keystone-manage` to
provision the database with the schemas. And finally, it will use `keystone-all`
to run the services on the exposed ports.

```
#!/bin/sh
ADMIN_TOKEN=${ADMIN_TOKEN-`openssl rand -hex 10`}
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf DEFAULT use_stderr True
openstack-config --set /etc/keystone/keystone.conf database connection ${CONNECTION-mysql://keystone:password@dbhost/keystone}
su keystone -s /bin/sh -c "keystone-manage db_sync"

/usr/bin/keystone-all
```

In the rest of the article I will describe how to use this image to setup the
test environment. The first component you will need to use Keystone is the
database to store the credentials and other relevant information.


### Setup database
As you saw in the `Dockerfile`, we specified a MySQL connection. To make it
easy to deploy, we will also be using a container for this database server. I
prefer to use MariaDB, as this is also what normally would come with CentOS. For
this article I will be using MariaDB version 10.1.

To start the container perform the following command:
```
$ docker run -d --name keystone-database -e MYSQL_ROOT_PASSWORD=secrete mariadb:10.1
```

This will pull the container and start a named instance as `keystone-database`.
The `root` password to configure the database is set using the environment
variable to `secrete`.

Using this password and container name, we will create a database for Keystone
and grant priviliges:

```
$ docker exec keystone-database mysql -psecrete -e "create database keystone;"
$ docker exec keystone-database mysql -psecrete -e "GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'password';"
$ docker exec keystone-database mysql -psecrete -e "GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'password';"
$ docker exec keystone-database mysql -psecrete -e "flush privileges;"
```

After this, all the setting for the database are done and we can just leave it
running without further configuration.


### Generate token for API usage
Just like MariaDB, Keystone can use a token to perform the initial configuration.
It is preferred to make this admin token something that is random and not easily
guessable. A random token can be generated for instance with:

```
$ export TOKEN=$(openssl rand -hex 10)
```

In the rest of the article, this token will be used.


### Start container
After the database has been setup, and a token has been decided, we can start
the Keystone services. 

```
$ docker run -d --link keystone-database:dbhost -e ADMIN_TOKEN=$TOKEN -p 5000:5000 --name keystone-server gbraad/openstack-keystone:mitaka
```

This will link the keystone container to the database container. If all goes
well, the service will now be available on the exposed ports. The container
instance will be identified by the name `keystone-server`.

As mentioned earlier, when the container gets started, it will provision the
database with the schemas that are needed.

In the following segment we will configure Keystone. 

### Create service entry
To finalize the Keystone configuration, we will insert the service and endpoints
for the Identity service.

```
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ service-create --name=keystone --type=identity --description="Keystone Identity Service"
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ endpoint-create --service keystone --publicurl 'http://localhost:5000/v2.0' --adminurl 'http://localhost:35357/v2.0' --internalurl 'http://localhost:5000/v2.0'
```

Note that these command are performed inside the keystone container.


### Create admin user
To allow access to keystone without using the admin token, we will need to
create a user. The following commands will create a user named `admin` with
the password `password` and add this to a tenant called `admin`.

```
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ user-create --name admin --pass password
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ role-create --name admin
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ tenant-create --name admin
$ docker exec keystone-server keystone --os-token $TOKEN --os-endpoint http://localhost:35357/v2.0/ user-role-add --user admin --role admin --tenant admin
```

More detailed setups are possible, and for this I will refer you to the Keystone
documentation.


### Getting a user token
To verify Keystone works, we will retrieve a token. First you need to know the
IP address that has been assigned to your container.
```
$ docker inspect --format="{{.NetworkSettings.IPAddress}}" keystone-server
172.17.0.6
```

This can be helpful to communicate between different containers on the same
Docker network. You could create a new container, or pull my
[OpenStack client](https://gitlab.com/gbraad/openstack-client) container.


#### Using the OpenStack client
Using the OpenStack client you can retrieve a token using the following
configuration:

`keystonerc`
```
OS_IDENTITY_API_VERSION=3
OS_AUTH_URL=http://172.17.0.6:5000/v3
OS_USERNAME=admin
OS_PASSWORD=password
OS_PROJECT_NAME=admin
OS_USER_DOMAIN_NAME=Default
OS_PROJECT_DOMAIN_NAME=Default
```

When you use the following commands you will be given a token:
```
$ source keystonerc
$ openstack token issue
```


#### Using cURL
Since Keystone uses a HTTP interface, you can also retrieve the token using the
cURL command. When using the `-i` parameter, cURL will return all the headers
from the response. This will include the `X-SUBJECT-TOKEN` we want.

```
$ curl -i -H "Content-Type: application/json" -d '
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "name": "Default" },
          "password": "password"
        }
      }
    },
    "scope": {
      "project": {
        "name": "admin",
        "domain": { "name": "Default" }
      }
    }
  }
}' http://172.17.0.6:5000/v3/auth/tokens
```

A response will follow. You need to set the value of `X-Subject-Token` to
`OS_TOKEN`, or use in cURL as the `X-AUTH-TOKEN` header. More about this can
be found in the Keystone documentation: [API Examples using cURL](http://docs.openstack.org/developer/keystone/api_curl_examples.html).


### How this was used for development
For the [Commissaire project](https://github.com/projectatomic/commissaire) I
added Keystone functionality using two methods; using
[password](https://github.com/projectatomic/commissaire-http/issues/21) and
[token](https://github.com/projectatomic/commissaire-http/issues/28). The above
described container was used to allow easy deployment and testing.

As I decided not to introduce unnecessary libraries as dependencies, the
communication from Commissaire happens over the HTTP ReST interface. To
authenticate using a basic authorization, using the password method, we only
need to construct a simple JSON object:

```
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "name": "Default" },
          "password": "password"
        }
      }
    },
    "scope": {
      "project": {
        "name": "admin",
        "domain": { "name": "Default" }
      }
    }
  }
}
```

In code we described this with:

```
        headers = {'Content-Type': 'application/json'}
        body = {'auth': {'identity': {}}}
        ident = body['auth']['identity']

        ident['methods'] = ['password']
        ident['password'] = {'user': {
            'name': user,
            'password': passwd,
            'domain': {'name': self.domain}}}
```

To perform the authentication, we send a request:
```
        response = requests.post(
            self.url,
            data=json.dumps(body),
            headers=headers)
```

to the endpoint exposed at: `http://172.17.0.6:5000/v3/auth/tokens`. When the
response includes the header `X-Subject-Token` the authentication succeeded,
else we failed and send a 403 as status code.

```
        if 'X-Subject-Token' in response.headers:
            return True

        # Forbid by default
        return False
```

The Implementation for authentication using a token is quite similar, instead
we will take the `X-Auth-Token` from the request we received  and verify this
against Keystone using the following request:

```
{
    "auth": {
        "identity": {
            "methods": [
                "token"
            ],
            "token": {
                "id": "faa166abf235430e81c9fa12ad248533"
            }
        }
    }
}
```

Just like in the previous example, the endpoint is:
`http://172.17.0.6:5000/v3/auth/tokens`. If the authentication is succesful
the response will contain the `X-Subject-Token` header.


## Conclusion
Keystone is powerful service to provide authentication for your infrastructure.
As you can see from this example, using a containerized (composed) environment,
it is easy to get a basic setup running. And using the ReST API it is also 
very simple to handle authentication outside of your own application. In future
articles more advanced scenarios will be given.

At the moment, password authentication using Keystone and Commissaire is
possible and hopefully soon we will also have integrated the token based
authentication.

If you have comments or suggestions, please leave them below or consider sending
a message to me on [Twitter](http://twitter.com/gbraad): @gbraad.

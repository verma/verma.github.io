---
layout: post
title: Setting up Digital Ocean provider for Vagrant
summary: Use Digital Ocean as a platform to provision your Vagrant instances.
comments: true
categories: [devops]
date: 2014-08-25
---

I recently tried provisioning a [Digital Ocean](https://www.digitalocean.com) instance using [Vagrant](https://www.vagrantup.com) and failed.  All references on the Interwebs seem to be quiet old (from 2013) and seem to use V1 of the Digital Ocean API.

In this post I'll detail the steps I followed to get one up and running.

### Environment
These steps were tried on `Mac OS X 10.9.4`, I would hope that they apply to other *nix family of operating systems as well.  I am running `Vagrant v1.3.5` which I realize is not the most recent version.

### Get the right Plugin
There seem to be two plugins out there `digital_ocean` and `vagrant-digital_ocean`.  The latter worked for me.

    vagrant plugin install vagrant-digital_ocean

The other plugin still sets up things right (I could see it listed in `~/.vagrant.d/plugins.json` but could never use it).

### OpenSSL and Certificates
I installed `OpenSSL` using `brew`.

    brew install openssl

which setup some paths for me under `/usr/local/etc/openssl`(homebrew specific).  

Now I needed a certificate file which OpenSSL could use to connect to Digital Ocean.  Apparently, this file used to be provided as part of `curl-ca-bundle` homebrew bundle, but I couldn't install it (Not found).  Instead I used [this URL](http://sourceforge.net/projects/machomebrew/files/mirror/curl-ca-bundle-1.87.tar.bz2/download) to get it and un-tarred it into `/usr/local/etc/openssl/certs`. This gave me `/usr/local/etc/openssl/certs/ca-bundle.crt` file.

### Configure Environment

After the certificate file was setup, I modified my `~/.profile` to include:

    export SSL_CERT_FILE=/usr/local/etc/openssl/certs/ca-bundle.crt


### Digital Ocean Access Token
I then went to the _Apps & API_ section on my Digital Ocean Web Interface and created a new _Personal Access Token_.  Digital Ocean gave me a long hex string which I exported as an environment variable in my `~/.profile` file:

    export DIGITAL_OCEAN_ACCESS_TOKEN="..."

I then re-sourced my `~/.profile`:

    . ~/.profile


### Digital Ocean Provider configuration in Vagrantfile

Finally, I setup Digital Ocean configuration in my `Vagrantfile`:

{{<  highlight ruby  >}}
config.vm.provider :digital_ocean do |provider|
    raise RuntimeError, "No Digital Ocean access token has been set. Set the DIGITAL_OCEAN_ACCESS_TOKEN environment variable." unless ENV["DIGITAL_OCEAN_ACCESS_TOKEN"]

    provider.token = ENV["DIGITAL_OCEAN_ACCESS_TOKEN"]
    provider.image = "Ubuntu 14.04 x64"
    provider.region = "nyc2"
    provider.ca_path = "/usr/local/etc/openssl/certs/ca-bundle.crt"
    provider.size = "512MB";
end
{{< /highlight >}}

### Bringing up Vagrant
I was then able to provision a Vagrant instance on Digital Ocean using:

    vagrant up --provider=digital_ocean

Things seemed to work fine thereafter.  Hope this helps.

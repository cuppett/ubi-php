# ubi-php

Container images based on the [SCL PHP image](https://github.com/sclorg/s2i-php-container).
Built to include additional or updated packages like redis, delivered or compiled
outside the default & official repositories available within the distribution.

## Installing on your OpenShift cluster

You can easily enable these image builds on your cluster with the following command:

```
$ oc apply -k build/openshift
```

## Images Available:

A set of images are available here (for x86_64):

* quay.io/cuppett/ubi-php:83-ubi10
* quay.io/cuppett/ubi-php:83-ubi9
* quay.io/cuppett/ubi-php:82-ubi8

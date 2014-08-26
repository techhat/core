# Adding Provisionable Operating Systems

This process ensures that the Admin node can deploy operating systems to slaves.

When deploying an admin node in production mode, you will want to be able to install operating systems on slave nodes.  By default, the `provisioner-base-images` role will look for OS install ISO images in `/tftpboot/isos`.  Currently, the provisioner knows how to install the following operating systems from the following ISO images:

 * `ubuntu-12.04`: `ubuntu-12.04.4-server-amd64.iso`
 * `centos-6.5`: `CentOS-6.5-x86_64-bin-DVD1.iso`

To enable the provisioner to install from those images, place them in `$HOME/.cache/opencrowbar/tftpboot/isos`, either directly or via a hard link.  These images will then be available inside the Docker container at `/tftpboot/isos`, and the provisioner will be able to use them to install operating systems on slave nodes.

## Add a new OS after initial annealing

If you add a new OS after the initial annealing, Crowbar must be told to rediscover available operating systems.  You must reapply (retry) the `provisioner-base-images` role (aka _Available O/S_) on the Admin server in the  System deployment.

> you can generally navigate directly to this NodeRole using `/nodes/1/node_roles/provisioner-base-images` or using the name of your admin server instead of the #1.

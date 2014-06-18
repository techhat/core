## OpenCrowbar Troubleshooting Tips

### Installing an OS, the TFTP Process

TFTP provides the boot images for the operating system install.

You can inspect the TFTP information the admin node provides by looking in the `/tftpboot` directories.

These directories contain the sledgehammer discovery, base OS install images and specific instructions for each node in the `/tftpboot/nodes` directory.

If Crowbar is not providing the right boot image, this is a good place to start. 

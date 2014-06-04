# Configuration of Proxy Cache

Because Dev Mode uses online access for packages, we _strongly_ recommend using a caching proxy such as Squid or Polipo.

If you are behind a firewall, you should have the cache access CNTLM or similar.

## Squid Proxy (on Ubuntu)

1. Configure your CNTLM proxy on :3128
1. Install: `sudo apt-get install squid3`
1. Update your configuration: `sudo vi /etc/squid3/squid.conf`
  1. make sure that you allow containers to use the proxy
  1. example https://gist.github.com/cloudedge/9666058
1. Create your cache directory: `sudo mkdir /var/cache/squid`
1. Allow Squid to write to the cache: `sudo chown proxy:proxy /var/cache/squid`
1. Restart the service: `sudo service squid3 restart`
1. Access the proxy
  1. `export http_proxy="http://127.0.0.1:8123"`
  1. `export https_proxy="http://127.0.0.1:8123"`
1. Test the proxy: `wget google.com`

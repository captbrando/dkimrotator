![Open Issues](https://img.shields.io/github/issues/captbrando/dkimrotator) ![Pull Requests](https://img.shields.io/github/issues-pr/captbrando/dkimrotator)

# DKIM Rotator README

The DKIM Rotator script will rotate all generated DKIM keys in a given key directory using the date as the selector and update GoDaddy with new TXT records. Only the Year and Month fields (YYYYMM) will be leveraged for the selector. This script can easily be modified if you wanted to add an additional serial number at the end.

## Prerequisites
In order for this script to successfully run, there are a few prereqs and assumptions to consider:

* The `opendkim-genkey`, `mv`, `cp`, `sed`, `cat`, and `awk` binaries must be in the path of the script. Instead of pre-declaring all these, I just call them for maximum portability. Just keep in mind, you need to account for this.
* You have already installed `opendkim` and it's working swimmingly.
* You define your working directory where your keys and key table files are. Right now its set as `/etc/dkimkeys`.
* All keys that will be rotated are defined in your key table. Technically you don't need to have pre-existing keys, but it may bark an error on you when it tries to move the old key out of the way.
* You are good with 2048-bit RSA keys and SHA256 for hashing (those are hard coded right now).
* This now is integrated with GoDaddy's API to auto add the new TXT records to each domain.


### Setting up DKIM
Getting DKIM going on your server is outside the scope of this document, but you can refer to [this guide](https://github.com/linode/docs/blob/master/docs/email/postfix/configure-spf-and-dkim-in-postfix-on-debian-8.md "DKIM with Postfix on Debian 8") for a Debian/Postfix/DKIM setup. One quick note, there is still a mistake in this guide document. When generating keys, the proper `-h` flag is `sha256`, NOT `rsa-sha256`. You can also check out Debian's [OpenDKIM](https://wiki.debian.org/opendkim "Debian's OpenDKIM") guide.

## Usage
Pretty simple. Just run the script and be sure you have met the prerequisites above.

## Bugs & Contact
This script is provided to you free of charge with no expressed or implied warranty. USE AT YOUR OWN RISK. To file a bug, suggest a patch, or contact me, [visit GitHub](https://github.com/captbrando/dkimrotator/).

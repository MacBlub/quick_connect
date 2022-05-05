# quick connect
quick_connect is a short script for the sole purpose to not always type ssh username@server_ip -i somefile

Note: The code is extremly ugly.


# Usage
```
quick_connect<br>
   usage: quick_connect [--list] [--profile]<br>
   --list : list all registered connections<br>
   --profile : connect to device under profile<br>
   --register : register profile for future connection<br>
   --help : Print this message\n
   -------------------------------------------<br>
   Profiles are stored under the location of this script, and are folders, which contain files with id_rsa (private-key), info.conf\n<br>
   Example info.conf:<br>
      username=user_a<br>
      address=255.255.255.255<br>
      keyfile=identity_filename<br>
```

# license
This code for quick_connect is public domain!

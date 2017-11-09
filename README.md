# sshmaster
Using bash and tmux to provide a nice interface for SSH on the command-line

# Requirements

* SSH
* tmux

# Installation and Usage

First, ensure that your [~/.ssh/config file](http://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/) is set up properly!

Usage is from the terminal of your choice:

```
ssh_master USERNAME HOST DESCRIPTIVENAME
```

It will create a tmux session named *SSHes* if none exists, or if one 
exists, it will add a window to it. It will name the appropriate window 
with the descriptive name you provide, then open a SSH connection. If 
tmux (and the session) is open already on your desktop, it will NOT 
attach, otherwise it will attach to the tmux session.
